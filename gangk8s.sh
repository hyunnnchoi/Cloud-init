#!/bin/bash
STARTTIME=`date "+%H:%M:%S.%N"`
STARTEPOCH=`date +%s`  # 스크립트 시작 시간 (epoch 초)
STARTLOGTIME=$(($(date +%s%N)/1000000000))
TFPATH="/home/tensorspot/Cloud-init"
SAVEPATH="/home/tensorspot/tfjob"


PEM_KEY="/home/ubuntu/tethys-v/tethys.pem"


sudo rm -rf ${SAVEPATH}/*
echo "$STARTTIME" > ${SAVEPATH}/start_makespan.txt




# Lambda Labs - 동적으로 노드 IP 가져와서 GPU 스크립트 실행
NODE_IPS=$(kubectl get nodes -o wide --no-headers | awk '{print $6}')
for node_ip in $NODE_IPS; do
    ssh -i ${PEM_KEY} -o StrictHostKeyChecking=no ubuntu@$node_ip "sudo sh /home/tensorspot/Cloud-init/gpu.sh &" &
done



# 사용 가능한 총 GPU 수 체크하는 함수
total_gpu_num=$(kubectl get nodes "-o=custom-columns=NAME:.metadata.name,GPU:.status.allocatable.nvidia\\.com/gpu" | grep -v NAME | awk '{if ($2 ~ /^[0-9]+$/) sum += $2} END {print sum}')
configured_gpu_num=32
if [ "$total_gpu_num" -ne "$configured_gpu_num" ]; then
    echo "ERROR: GPU count mismatch!"
    echo "  Configured in environment: $configured_gpu_num"
    echo "  Detected from k8s cluster: $total_gpu_num"
    echo "Please check your environment configuration or cluster setup."
    exit 1
else
    echo "GPU count verification passed: $total_gpu_num"
fi

# 사용 가능한 총 GPU 수 체크하는 함수
get_available_gpus() {
    # 워커와 치프 파드 수 계산 (각각 1개 GPU 사용)
    USED_GPUS=$(kubectl get pods | grep -E "(-worker-|-chief-)" | wc -l)
    # 사용 가능한 GPU 수 계산
    AVAILABLE_GPUS=$((total_gpu_num - USED_GPUS))
    
    echo $AVAILABLE_GPUS
}

# 노드에 작업이 스케줄링될 때까지 대기하는 함수
wait_for_pod_scheduling() {
    JOB_NAME=$1
    WORKER_COUNT=$2
    JOB_NAME_DASH=$(echo $JOB_NAME | tr '_' '-')

    echo "Waiting for job $JOB_NAME to be scheduled to nodes..."

    # 모든 워커/치프 포드가 노드에 할당될 때까지 대기
    SCHEDULED_PODS=0
    TIMEOUT=259200  # 72시간 타임아웃
    START_TIME=$(date +%s)

    while [ $SCHEDULED_PODS -lt $WORKER_COUNT ]
    do
        # 현재 이 작업의 Running 상태이거나 ContainerCreating 상태인 포드 수 계산
        SCHEDULED_PODS=$(kubectl get pods | grep $JOB_NAME_DASH | grep -E "(Running|ContainerCreating|Completed)" | wc -l)

        # 현재 시간 체크
        CURRENT_TIME=$(date +%s)
        ELAPSED_TIME=$((CURRENT_TIME - START_TIME))

        # 타임아웃 체크
        if [ $ELAPSED_TIME -gt $TIMEOUT ]; then
            echo "WARNING: Timeout waiting for pods to be scheduled. Continuing anyway."
            kubectl get pods | grep $JOB_NAME_DASH
            break
        fi

        if [ $SCHEDULED_PODS -lt $WORKER_COUNT ]; then
            sleep 1
            echo "Waiting for $JOB_NAME pods to be scheduled ($SCHEDULED_PODS/$WORKER_COUNT scheduled)"
        else
            echo "All pods for $JOB_NAME have been scheduled to nodes"
            kubectl get pods -o wide | grep $JOB_NAME_DASH
            echo "Node allocation for $JOB_NAME:" > ${SAVEPATH}/${JOB_NAME}_node_allocation.txt
            kubectl get pods -o wide | grep $JOB_NAME_DASH | awk '{print $1 "\t" $7}' >> ${SAVEPATH}/${JOB_NAME}_node_allocation.txt
            # TODO(hhlee): node_allocation.txt 제대로 찍히는지 확인필요

            # 각 포드의 생성 시간 기록
            for pod in $(kubectl get pods | grep $JOB_NAME_DASH | awk '{print $1}'); do
                echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/${pod}_create.txt
            done
            
            break
        fi
    done
}

# 완료된 작업 정리 함수
cleanup_completed_jobs() {
    SCHEDULER="$1"
    
    COMPLETED_CONTROLLERS=$(kubectl get pod -o wide | grep -e "controller-" -e "chief-" | grep Completed | awk '{print $1}')
    if [ -n "${COMPLETED_CONTROLLERS}" ]; then
        for completed_pod in ${COMPLETED_CONTROLLERS}; do
            # 작업 이름 추출
            COMPLETED_JOB=$(echo ${completed_pod} | awk -F '-' '{
                jobname = $1
                for (i = 2; i <= NF - 2; i++) {
                    jobname = jobname "_" $i
                }
                print jobname
            }')

            # 작업 포드 이름 추출
            COMPLETED_JOB_POD=$(echo ${completed_pod} | awk -F '-' '{
                jobname = $1
                for (i = 2; i <= NF - 2; i++) {
                    jobname = jobname "-" $i
                }
                print jobname
            }')

            echo "Job ${COMPLETED_JOB} completed, freeing resources"

            # 노드 정보 저장
            kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt
            # 작업 완료 시간 기록
            echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/${COMPLETED_JOB}_job_completed.txt

            # 작업 삭제
            kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_${SCHEDULER}.yaml
        done
        return 0
    fi
    return 1
}

# 자원과 arrival_time을 고려하여 대기하는 함수 (스케줄러에 따라 다른 로직 적용)
wait_for_resources_or_arrival() {
    ARRIVAL_TIME=$1
    JOB_NAME=$2
    WORKER_NUM=$3
    SCHEDULER="$4"

    echo "Checking resources for job ${JOB_NAME} (arrival time: ${ARRIVAL_TIME}s, workers: $WORKER_NUM)"
    echo $ARRIVAL_TIME > ${SAVEPATH}/${JOB_NAME}_arrival_timestamp.txt

    while true; do
        # arrival time 체크
        CURRENT_EPOCH=$(date +%s)
        TIME_PASSED=$((CURRENT_EPOCH - STARTEPOCH))

        # arrival time이 되지 않았으면 계속 대기
        if [ $TIME_PASSED -lt $ARRIVAL_TIME ]; then
            TIME_REMAINING=$((ARRIVAL_TIME - TIME_PASSED))
            echo "Waiting for arrival time for job ${JOB_NAME} (Remaining: ${TIME_REMAINING}s)"
            sleep 1
            continue
        fi

        # k8s 스케줄러에만 Gang 스케줄링 적용
        if [ "$SCHEDULER" = "k8s" ]; then
            # Gang 스케줄링 로직: 사용 가능한 GPU 수 확인
            AVAILABLE_GPUS=$(get_available_gpus)
            echo "Current available GPUs: $AVAILABLE_GPUS (needed: $WORKER_NUM)"

            # 완료된 작업 확인 및 정리
            cleanup_completed_jobs $SCHEDULER

            # 자원이 해제되었으므로 다시 확인
            AVAILABLE_GPUS=$(get_available_gpus)
            echo "Available GPUs after cleanup: $AVAILABLE_GPUS (needed: $WORKER_NUM)"

            # Gang 스케줄링: 필요한 모든 GPU가 사용 가능할 때만 작업 제출
            if [ $AVAILABLE_GPUS -ge $WORKER_NUM ]; then
                echo "Sufficient GPUs available ($AVAILABLE_GPUS >= $WORKER_NUM). Starting job ${JOB_NAME} now."
                return 0
            else
                echo "Waiting for sufficient GPU resources for job ${JOB_NAME} ($AVAILABLE_GPUS/$WORKER_NUM available)"
                sleep 5
                continue
            fi
        else
            # 다른 스케줄러는 기존 로직 사용 (대기 중인 포드 확인)
            PENDING_PODS=$(kubectl get pods | grep -e "Pending" | wc -l)

            # 대기 중인 포드가 없으면 (이전 작업들이 모두 자원 할당 받은 상태) 즉시 작업 시작
            if [ $PENDING_PODS -eq 0 ]; then
                echo "Arrival time reached and no pending pods. Starting job ${JOB_NAME} now."
                CURRENT_EPOCH=$(date +%s)
                TIME_PASSED=$((CURRENT_EPOCH - STARTEPOCH))
                echo $TIME_PASSED > ${SAVEPATH}/${JOB_NAME}_queuehead_timestamp.txt
                return 0
            else
                # 대기 중인 포드가 있으면 완료된 작업 확인 및 정리
                if cleanup_completed_jobs $SCHEDULER; then
                    # 완료된 작업이 정리되었으므로 대기 중인 포드 다시 확인
                    PENDING_PODS=$(kubectl get pods | grep -e "Pending" | wc -l)
                    if [ $PENDING_PODS -eq 0 ]; then
                        echo "All previous jobs allocated. Starting job ${JOB_NAME} now."
                        return 0
                    fi
                fi

                echo "Arrival time reached but waiting for previous jobs to be allocated resources first."
                sleep 0.5
            fi
        fi
    done
}

echo "총 GPU 수: 32"


# 작업: id0_speech_whisper_sync_batch16 (모델: whisper, 워커: 4, 도착시간: 0초)
wait_for_resources_or_arrival 0 id0_speech_whisper_sync_batch16 4 gangk8s
# 작업 생성 시간 기록
echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/id0_speech_whisper_sync_batch16_job_create.txt
kubectl apply -f ${TFPATH}/net_script/id0_speech_whisper_sync_batch16_gangk8s.yaml
wait_for_pod_scheduling id0_speech_whisper_sync_batch16 4


# 작업: id1_cifar10_resnet44_sync_batch1024 (모델: resnet44, 워커: 1, 도착시간: 0초)
wait_for_resources_or_arrival 0 id1_cifar10_resnet44_sync_batch1024 1 gangk8s
# 작업 생성 시간 기록
echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/id1_cifar10_resnet44_sync_batch1024_job_create.txt
kubectl apply -f ${TFPATH}/net_script/id1_cifar10_resnet44_sync_batch1024_gangk8s.yaml
wait_for_pod_scheduling id1_cifar10_resnet44_sync_batch1024 1


# 작업: id2_cifar10_resnet44_sync_batch8192 (모델: resnet44, 워커: 8, 도착시간: 0초)
wait_for_resources_or_arrival 0 id2_cifar10_resnet44_sync_batch8192 8 gangk8s
# 작업 생성 시간 기록
echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/id2_cifar10_resnet44_sync_batch8192_job_create.txt
kubectl apply -f ${TFPATH}/net_script/id2_cifar10_resnet44_sync_batch8192_gangk8s.yaml
wait_for_pod_scheduling id2_cifar10_resnet44_sync_batch8192 8


# 작업: id3_cifar10_resnet44_sync_batch4096 (모델: resnet44, 워커: 4, 도착시간: 0초)
wait_for_resources_or_arrival 0 id3_cifar10_resnet44_sync_batch4096 4 gangk8s
# 작업 생성 시간 기록
echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/id3_cifar10_resnet44_sync_batch4096_job_create.txt
kubectl apply -f ${TFPATH}/net_script/id3_cifar10_resnet44_sync_batch4096_gangk8s.yaml
wait_for_pod_scheduling id3_cifar10_resnet44_sync_batch4096 4


# 작업: id4_imagenet_resnet50_sync_batch512 (모델: resnet50, 워커: 4, 도착시간: 0초)
wait_for_resources_or_arrival 0 id4_imagenet_resnet50_sync_batch512 4 gangk8s
# 작업 생성 시간 기록
echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/id4_imagenet_resnet50_sync_batch512_job_create.txt
kubectl apply -f ${TFPATH}/net_script/id4_imagenet_resnet50_sync_batch512_gangk8s.yaml
wait_for_pod_scheduling id4_imagenet_resnet50_sync_batch512 4


# 작업: id5_cifar10_densenet40_k12_sync_batch8192 (모델: densenet40_k12, 워커: 8, 도착시간: 0초)
wait_for_resources_or_arrival 0 id5_cifar10_densenet40_k12_sync_batch8192 8 gangk8s
# 작업 생성 시간 기록
echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/id5_cifar10_densenet40_k12_sync_batch8192_job_create.txt
kubectl apply -f ${TFPATH}/net_script/id5_cifar10_densenet40_k12_sync_batch8192_gangk8s.yaml
wait_for_pod_scheduling id5_cifar10_densenet40_k12_sync_batch8192 8


# 작업: id6_cifar10_resnet44_sync_batch1024 (모델: resnet44, 워커: 1, 도착시간: 0초)
wait_for_resources_or_arrival 0 id6_cifar10_resnet44_sync_batch1024 1 gangk8s
# 작업 생성 시간 기록
echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/id6_cifar10_resnet44_sync_batch1024_job_create.txt
kubectl apply -f ${TFPATH}/net_script/id6_cifar10_resnet44_sync_batch1024_gangk8s.yaml
wait_for_pod_scheduling id6_cifar10_resnet44_sync_batch1024 1


# 작업: id7_imagenet_vgg16_sync_batch1024 (모델: vgg16, 워커: 8, 도착시간: 0초)
wait_for_resources_or_arrival 0 id7_imagenet_vgg16_sync_batch1024 8 gangk8s
# 작업 생성 시간 기록
echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/id7_imagenet_vgg16_sync_batch1024_job_create.txt
kubectl apply -f ${TFPATH}/net_script/id7_imagenet_vgg16_sync_batch1024_gangk8s.yaml
wait_for_pod_scheduling id7_imagenet_vgg16_sync_batch1024 8


# 작업: id8_imagenet_vgg16_sync_batch128 (모델: vgg16, 워커: 1, 도착시간: 0초)
wait_for_resources_or_arrival 0 id8_imagenet_vgg16_sync_batch128 1 gangk8s
# 작업 생성 시간 기록
echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/id8_imagenet_vgg16_sync_batch128_job_create.txt
kubectl apply -f ${TFPATH}/net_script/id8_imagenet_vgg16_sync_batch128_gangk8s.yaml
wait_for_pod_scheduling id8_imagenet_vgg16_sync_batch128 1


# 작업: id9_squad_bert_sync_batch32 (모델: bert, 워커: 8, 도착시간: 0초)
wait_for_resources_or_arrival 0 id9_squad_bert_sync_batch32 8 gangk8s
# 작업 생성 시간 기록
echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/id9_squad_bert_sync_batch32_job_create.txt
kubectl apply -f ${TFPATH}/net_script/id9_squad_bert_sync_batch32_gangk8s.yaml
wait_for_pod_scheduling id9_squad_bert_sync_batch32 8


# 작업: id10_imagenet_vgg16_sync_batch256 (모델: vgg16, 워커: 2, 도착시간: 0초)
wait_for_resources_or_arrival 0 id10_imagenet_vgg16_sync_batch256 2 gangk8s
# 작업 생성 시간 기록
echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/id10_imagenet_vgg16_sync_batch256_job_create.txt
kubectl apply -f ${TFPATH}/net_script/id10_imagenet_vgg16_sync_batch256_gangk8s.yaml
wait_for_pod_scheduling id10_imagenet_vgg16_sync_batch256 2


# 작업: id11_imagenet_vgg16_sync_batch512 (모델: vgg16, 워커: 4, 도착시간: 0초)
wait_for_resources_or_arrival 0 id11_imagenet_vgg16_sync_batch512 4 gangk8s
# 작업 생성 시간 기록
echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/id11_imagenet_vgg16_sync_batch512_job_create.txt
kubectl apply -f ${TFPATH}/net_script/id11_imagenet_vgg16_sync_batch512_gangk8s.yaml
wait_for_pod_scheduling id11_imagenet_vgg16_sync_batch512 4


# 작업: id12_cifar10_resnet44_sync_batch1024 (모델: resnet44, 워커: 1, 도착시간: 0초)
wait_for_resources_or_arrival 0 id12_cifar10_resnet44_sync_batch1024 1 gangk8s
# 작업 생성 시간 기록
echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/id12_cifar10_resnet44_sync_batch1024_job_create.txt
kubectl apply -f ${TFPATH}/net_script/id12_cifar10_resnet44_sync_batch1024_gangk8s.yaml
wait_for_pod_scheduling id12_cifar10_resnet44_sync_batch1024 1


# 작업: id13_cifar10_resnet44_sync_batch2048 (모델: resnet44, 워커: 2, 도착시간: 0초)
wait_for_resources_or_arrival 0 id13_cifar10_resnet44_sync_batch2048 2 gangk8s
# 작업 생성 시간 기록
echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/id13_cifar10_resnet44_sync_batch2048_job_create.txt
kubectl apply -f ${TFPATH}/net_script/id13_cifar10_resnet44_sync_batch2048_gangk8s.yaml
wait_for_pod_scheduling id13_cifar10_resnet44_sync_batch2048 2


# 작업: id14_cifar10_resnet44_sync_batch2048 (모델: resnet44, 워커: 2, 도착시간: 0초)
wait_for_resources_or_arrival 0 id14_cifar10_resnet44_sync_batch2048 2 gangk8s
# 작업 생성 시간 기록
echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/id14_cifar10_resnet44_sync_batch2048_job_create.txt
kubectl apply -f ${TFPATH}/net_script/id14_cifar10_resnet44_sync_batch2048_gangk8s.yaml
wait_for_pod_scheduling id14_cifar10_resnet44_sync_batch2048 2


# 작업: id15_cifar10_resnet44_sync_batch8192 (모델: resnet44, 워커: 8, 도착시간: 0초)
wait_for_resources_or_arrival 0 id15_cifar10_resnet44_sync_batch8192 8 gangk8s
# 작업 생성 시간 기록
echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/id15_cifar10_resnet44_sync_batch8192_job_create.txt
kubectl apply -f ${TFPATH}/net_script/id15_cifar10_resnet44_sync_batch8192_gangk8s.yaml
wait_for_pod_scheduling id15_cifar10_resnet44_sync_batch8192 8


# 작업: id16_imagenet_vgg16_sync_batch1024 (모델: vgg16, 워커: 8, 도착시간: 0초)
wait_for_resources_or_arrival 0 id16_imagenet_vgg16_sync_batch1024 8 gangk8s
# 작업 생성 시간 기록
echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/id16_imagenet_vgg16_sync_batch1024_job_create.txt
kubectl apply -f ${TFPATH}/net_script/id16_imagenet_vgg16_sync_batch1024_gangk8s.yaml
wait_for_pod_scheduling id16_imagenet_vgg16_sync_batch1024 8


# 작업: id17_cifar10_resnet44_sync_batch8192 (모델: resnet44, 워커: 8, 도착시간: 0초)
wait_for_resources_or_arrival 0 id17_cifar10_resnet44_sync_batch8192 8 gangk8s
# 작업 생성 시간 기록
echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/id17_cifar10_resnet44_sync_batch8192_job_create.txt
kubectl apply -f ${TFPATH}/net_script/id17_cifar10_resnet44_sync_batch8192_gangk8s.yaml
wait_for_pod_scheduling id17_cifar10_resnet44_sync_batch8192 8


# 작업: id18_imagenet_resnet50_sync_batch1024 (모델: resnet50, 워커: 8, 도착시간: 0초)
wait_for_resources_or_arrival 0 id18_imagenet_resnet50_sync_batch1024 8 gangk8s
# 작업 생성 시간 기록
echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/id18_imagenet_resnet50_sync_batch1024_job_create.txt
kubectl apply -f ${TFPATH}/net_script/id18_imagenet_resnet50_sync_batch1024_gangk8s.yaml
wait_for_pod_scheduling id18_imagenet_resnet50_sync_batch1024 8


# 작업: id19_cifar10_resnet44_sync_batch1024 (모델: resnet44, 워커: 1, 도착시간: 0초)
wait_for_resources_or_arrival 0 id19_cifar10_resnet44_sync_batch1024 1 gangk8s
# 작업 생성 시간 기록
echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/id19_cifar10_resnet44_sync_batch1024_job_create.txt
kubectl apply -f ${TFPATH}/net_script/id19_cifar10_resnet44_sync_batch1024_gangk8s.yaml
wait_for_pod_scheduling id19_cifar10_resnet44_sync_batch1024 1


# 작업: id20_cifar10_resnet44_sync_batch2048 (모델: resnet44, 워커: 2, 도착시간: 0초)
wait_for_resources_or_arrival 0 id20_cifar10_resnet44_sync_batch2048 2 gangk8s
# 작업 생성 시간 기록
echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/id20_cifar10_resnet44_sync_batch2048_job_create.txt
kubectl apply -f ${TFPATH}/net_script/id20_cifar10_resnet44_sync_batch2048_gangk8s.yaml
wait_for_pod_scheduling id20_cifar10_resnet44_sync_batch2048 2


# 작업: id21_cifar10_resnet44_sync_batch4096 (모델: resnet44, 워커: 4, 도착시간: 0초)
wait_for_resources_or_arrival 0 id21_cifar10_resnet44_sync_batch4096 4 gangk8s
# 작업 생성 시간 기록
echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/id21_cifar10_resnet44_sync_batch4096_job_create.txt
kubectl apply -f ${TFPATH}/net_script/id21_cifar10_resnet44_sync_batch4096_gangk8s.yaml
wait_for_pod_scheduling id21_cifar10_resnet44_sync_batch4096 4


# 작업: id22_cifar10_resnet44_sync_batch1024 (모델: resnet44, 워커: 1, 도착시간: 0초)
wait_for_resources_or_arrival 0 id22_cifar10_resnet44_sync_batch1024 1 gangk8s
# 작업 생성 시간 기록
echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/id22_cifar10_resnet44_sync_batch1024_job_create.txt
kubectl apply -f ${TFPATH}/net_script/id22_cifar10_resnet44_sync_batch1024_gangk8s.yaml
wait_for_pod_scheduling id22_cifar10_resnet44_sync_batch1024 1


# 작업: id23_cifar10_resnet44_sync_batch8192 (모델: resnet44, 워커: 8, 도착시간: 0초)
wait_for_resources_or_arrival 0 id23_cifar10_resnet44_sync_batch8192 8 gangk8s
# 작업 생성 시간 기록
echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/id23_cifar10_resnet44_sync_batch8192_job_create.txt
kubectl apply -f ${TFPATH}/net_script/id23_cifar10_resnet44_sync_batch8192_gangk8s.yaml
wait_for_pod_scheduling id23_cifar10_resnet44_sync_batch8192 8


# 작업: id24_imagenet_vgg16_sync_batch256 (모델: vgg16, 워커: 2, 도착시간: 0초)
wait_for_resources_or_arrival 0 id24_imagenet_vgg16_sync_batch256 2 gangk8s
# 작업 생성 시간 기록
echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/id24_imagenet_vgg16_sync_batch256_job_create.txt
kubectl apply -f ${TFPATH}/net_script/id24_imagenet_vgg16_sync_batch256_gangk8s.yaml
wait_for_pod_scheduling id24_imagenet_vgg16_sync_batch256 2


# 작업: id25_cifar10_resnet44_sync_batch2048 (모델: resnet44, 워커: 2, 도착시간: 0초)
wait_for_resources_or_arrival 0 id25_cifar10_resnet44_sync_batch2048 2 gangk8s
# 작업 생성 시간 기록
echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/id25_cifar10_resnet44_sync_batch2048_job_create.txt
kubectl apply -f ${TFPATH}/net_script/id25_cifar10_resnet44_sync_batch2048_gangk8s.yaml
wait_for_pod_scheduling id25_cifar10_resnet44_sync_batch2048 2


# 작업: id26_cifar10_resnet44_sync_batch8192 (모델: resnet44, 워커: 8, 도착시간: 0초)
wait_for_resources_or_arrival 0 id26_cifar10_resnet44_sync_batch8192 8 gangk8s
# 작업 생성 시간 기록
echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/id26_cifar10_resnet44_sync_batch8192_job_create.txt
kubectl apply -f ${TFPATH}/net_script/id26_cifar10_resnet44_sync_batch8192_gangk8s.yaml
wait_for_pod_scheduling id26_cifar10_resnet44_sync_batch8192 8


# 작업: id27_imagenet_vgg16_sync_batch512 (모델: vgg16, 워커: 4, 도착시간: 0초)
wait_for_resources_or_arrival 0 id27_imagenet_vgg16_sync_batch512 4 gangk8s
# 작업 생성 시간 기록
echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/id27_imagenet_vgg16_sync_batch512_job_create.txt
kubectl apply -f ${TFPATH}/net_script/id27_imagenet_vgg16_sync_batch512_gangk8s.yaml
wait_for_pod_scheduling id27_imagenet_vgg16_sync_batch512 4


# 작업: id28_cifar10_resnet44_sync_batch8192 (모델: resnet44, 워커: 8, 도착시간: 0초)
wait_for_resources_or_arrival 0 id28_cifar10_resnet44_sync_batch8192 8 gangk8s
# 작업 생성 시간 기록
echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/id28_cifar10_resnet44_sync_batch8192_job_create.txt
kubectl apply -f ${TFPATH}/net_script/id28_cifar10_resnet44_sync_batch8192_gangk8s.yaml
wait_for_pod_scheduling id28_cifar10_resnet44_sync_batch8192 8


# 작업: id29_cifar10_resnet44_sync_batch8192 (모델: resnet44, 워커: 8, 도착시간: 0초)
wait_for_resources_or_arrival 0 id29_cifar10_resnet44_sync_batch8192 8 gangk8s
# 작업 생성 시간 기록
echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/id29_cifar10_resnet44_sync_batch8192_job_create.txt
kubectl apply -f ${TFPATH}/net_script/id29_cifar10_resnet44_sync_batch8192_gangk8s.yaml
wait_for_pod_scheduling id29_cifar10_resnet44_sync_batch8192 8


# 작업: id30_cifar10_alexnet_sync_batch16384 (모델: alexnet, 워커: 4, 도착시간: 0초)
wait_for_resources_or_arrival 0 id30_cifar10_alexnet_sync_batch16384 4 gangk8s
# 작업 생성 시간 기록
echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/id30_cifar10_alexnet_sync_batch16384_job_create.txt
kubectl apply -f ${TFPATH}/net_script/id30_cifar10_alexnet_sync_batch16384_gangk8s.yaml
wait_for_pod_scheduling id30_cifar10_alexnet_sync_batch16384 4


# 작업: id31_imagenet_googlenet_sync_batch1024 (모델: googlenet, 워커: 4, 도착시간: 0초)
wait_for_resources_or_arrival 0 id31_imagenet_googlenet_sync_batch1024 4 gangk8s
# 작업 생성 시간 기록
echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/id31_imagenet_googlenet_sync_batch1024_job_create.txt
kubectl apply -f ${TFPATH}/net_script/id31_imagenet_googlenet_sync_batch1024_gangk8s.yaml
wait_for_pod_scheduling id31_imagenet_googlenet_sync_batch1024 4


# 작업: id32_imagenet_vgg16_sync_batch512 (모델: vgg16, 워커: 4, 도착시간: 0초)
wait_for_resources_or_arrival 0 id32_imagenet_vgg16_sync_batch512 4 gangk8s
# 작업 생성 시간 기록
echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/id32_imagenet_vgg16_sync_batch512_job_create.txt
kubectl apply -f ${TFPATH}/net_script/id32_imagenet_vgg16_sync_batch512_gangk8s.yaml
wait_for_pod_scheduling id32_imagenet_vgg16_sync_batch512 4


# 작업: id33_speech_wav2vec2_sync_batch16 (모델: wav2vec2, 워커: 4, 도착시간: 0초)
wait_for_resources_or_arrival 0 id33_speech_wav2vec2_sync_batch16 4 gangk8s
# 작업 생성 시간 기록
echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/id33_speech_wav2vec2_sync_batch16_job_create.txt
kubectl apply -f ${TFPATH}/net_script/id33_speech_wav2vec2_sync_batch16_gangk8s.yaml
wait_for_pod_scheduling id33_speech_wav2vec2_sync_batch16 4


# 작업: id34_cifar10_resnet44_sync_batch8192 (모델: resnet44, 워커: 8, 도착시간: 0초)
wait_for_resources_or_arrival 0 id34_cifar10_resnet44_sync_batch8192 8 gangk8s
# 작업 생성 시간 기록
echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/id34_cifar10_resnet44_sync_batch8192_job_create.txt
kubectl apply -f ${TFPATH}/net_script/id34_cifar10_resnet44_sync_batch8192_gangk8s.yaml
wait_for_pod_scheduling id34_cifar10_resnet44_sync_batch8192 8


# 작업: id35_squad_gpt2_sync_batch16 (모델: gpt2, 워커: 4, 도착시간: 0초)
wait_for_resources_or_arrival 0 id35_squad_gpt2_sync_batch16 4 gangk8s
# 작업 생성 시간 기록
echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/id35_squad_gpt2_sync_batch16_job_create.txt
kubectl apply -f ${TFPATH}/net_script/id35_squad_gpt2_sync_batch16_gangk8s.yaml
wait_for_pod_scheduling id35_squad_gpt2_sync_batch16 4


# 작업: id36_cifar10_resnet44_sync_batch2048 (모델: resnet44, 워커: 2, 도착시간: 0초)
wait_for_resources_or_arrival 0 id36_cifar10_resnet44_sync_batch2048 2 gangk8s
# 작업 생성 시간 기록
echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/id36_cifar10_resnet44_sync_batch2048_job_create.txt
kubectl apply -f ${TFPATH}/net_script/id36_cifar10_resnet44_sync_batch2048_gangk8s.yaml
wait_for_pod_scheduling id36_cifar10_resnet44_sync_batch2048 2


# 작업: id37_imagenet_vgg16_sync_batch512 (모델: vgg16, 워커: 4, 도착시간: 0초)
wait_for_resources_or_arrival 0 id37_imagenet_vgg16_sync_batch512 4 gangk8s
# 작업 생성 시간 기록
echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/id37_imagenet_vgg16_sync_batch512_job_create.txt
kubectl apply -f ${TFPATH}/net_script/id37_imagenet_vgg16_sync_batch512_gangk8s.yaml
wait_for_pod_scheduling id37_imagenet_vgg16_sync_batch512 4


# 작업: id38_imagenet_resnet50_sync_batch1024 (모델: resnet50, 워커: 8, 도착시간: 0초)
wait_for_resources_or_arrival 0 id38_imagenet_resnet50_sync_batch1024 8 gangk8s
# 작업 생성 시간 기록
echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/id38_imagenet_resnet50_sync_batch1024_job_create.txt
kubectl apply -f ${TFPATH}/net_script/id38_imagenet_resnet50_sync_batch1024_gangk8s.yaml
wait_for_pod_scheduling id38_imagenet_resnet50_sync_batch1024 8


# 작업: id39_cifar10_resnet44_sync_batch4096 (모델: resnet44, 워커: 4, 도착시간: 0초)
wait_for_resources_or_arrival 0 id39_cifar10_resnet44_sync_batch4096 4 gangk8s
# 작업 생성 시간 기록
echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/id39_cifar10_resnet44_sync_batch4096_job_create.txt
kubectl apply -f ${TFPATH}/net_script/id39_cifar10_resnet44_sync_batch4096_gangk8s.yaml
wait_for_pod_scheduling id39_cifar10_resnet44_sync_batch4096 4


# 작업: id40_cifar10_alexnet_sync_batch8192 (모델: alexnet, 워커: 2, 도착시간: 0초)
wait_for_resources_or_arrival 0 id40_cifar10_alexnet_sync_batch8192 2 gangk8s
# 작업 생성 시간 기록
echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/id40_cifar10_alexnet_sync_batch8192_job_create.txt
kubectl apply -f ${TFPATH}/net_script/id40_cifar10_alexnet_sync_batch8192_gangk8s.yaml
wait_for_pod_scheduling id40_cifar10_alexnet_sync_batch8192 2


# 작업: id41_imagenet_resnet50_sync_batch512 (모델: resnet50, 워커: 4, 도착시간: 0초)
wait_for_resources_or_arrival 0 id41_imagenet_resnet50_sync_batch512 4 gangk8s
# 작업 생성 시간 기록
echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/id41_imagenet_resnet50_sync_batch512_job_create.txt
kubectl apply -f ${TFPATH}/net_script/id41_imagenet_resnet50_sync_batch512_gangk8s.yaml
wait_for_pod_scheduling id41_imagenet_resnet50_sync_batch512 4


# 작업: id42_cifar10_alexnet_sync_batch16384 (모델: alexnet, 워커: 4, 도착시간: 0초)
wait_for_resources_or_arrival 0 id42_cifar10_alexnet_sync_batch16384 4 gangk8s
# 작업 생성 시간 기록
echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/id42_cifar10_alexnet_sync_batch16384_job_create.txt
kubectl apply -f ${TFPATH}/net_script/id42_cifar10_alexnet_sync_batch16384_gangk8s.yaml
wait_for_pod_scheduling id42_cifar10_alexnet_sync_batch16384 4


# 작업: id43_imagenet_vgg16_sync_batch256 (모델: vgg16, 워커: 2, 도착시간: 0초)
wait_for_resources_or_arrival 0 id43_imagenet_vgg16_sync_batch256 2 gangk8s
# 작업 생성 시간 기록
echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/id43_imagenet_vgg16_sync_batch256_job_create.txt
kubectl apply -f ${TFPATH}/net_script/id43_imagenet_vgg16_sync_batch256_gangk8s.yaml
wait_for_pod_scheduling id43_imagenet_vgg16_sync_batch256 2


# 작업: id44_cifar10_resnet44_sync_batch8192 (모델: resnet44, 워커: 8, 도착시간: 0초)
wait_for_resources_or_arrival 0 id44_cifar10_resnet44_sync_batch8192 8 gangk8s
# 작업 생성 시간 기록
echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/id44_cifar10_resnet44_sync_batch8192_job_create.txt
kubectl apply -f ${TFPATH}/net_script/id44_cifar10_resnet44_sync_batch8192_gangk8s.yaml
wait_for_pod_scheduling id44_cifar10_resnet44_sync_batch8192 8


# 작업: id45_imagenet_vgg16_sync_batch256 (모델: vgg16, 워커: 2, 도착시간: 0초)
wait_for_resources_or_arrival 0 id45_imagenet_vgg16_sync_batch256 2 gangk8s
# 작업 생성 시간 기록
echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/id45_imagenet_vgg16_sync_batch256_job_create.txt
kubectl apply -f ${TFPATH}/net_script/id45_imagenet_vgg16_sync_batch256_gangk8s.yaml
wait_for_pod_scheduling id45_imagenet_vgg16_sync_batch256 2


# 작업: id46_imagenet_resnet50_sync_batch256 (모델: resnet50, 워커: 2, 도착시간: 0초)
wait_for_resources_or_arrival 0 id46_imagenet_resnet50_sync_batch256 2 gangk8s
# 작업 생성 시간 기록
echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/id46_imagenet_resnet50_sync_batch256_job_create.txt
kubectl apply -f ${TFPATH}/net_script/id46_imagenet_resnet50_sync_batch256_gangk8s.yaml
wait_for_pod_scheduling id46_imagenet_resnet50_sync_batch256 2


# 작업: id47_cifar10_resnet44_sync_batch4096 (모델: resnet44, 워커: 4, 도착시간: 0초)
wait_for_resources_or_arrival 0 id47_cifar10_resnet44_sync_batch4096 4 gangk8s
# 작업 생성 시간 기록
echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/id47_cifar10_resnet44_sync_batch4096_job_create.txt
kubectl apply -f ${TFPATH}/net_script/id47_cifar10_resnet44_sync_batch4096_gangk8s.yaml
wait_for_pod_scheduling id47_cifar10_resnet44_sync_batch4096 4


# 작업: id48_cifar10_alexnet_sync_batch16384 (모델: alexnet, 워커: 4, 도착시간: 0초)
wait_for_resources_or_arrival 0 id48_cifar10_alexnet_sync_batch16384 4 gangk8s
# 작업 생성 시간 기록
echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/id48_cifar10_alexnet_sync_batch16384_job_create.txt
kubectl apply -f ${TFPATH}/net_script/id48_cifar10_alexnet_sync_batch16384_gangk8s.yaml
wait_for_pod_scheduling id48_cifar10_alexnet_sync_batch16384 4


# 작업: id49_cifar10_resnet44_sync_batch2048 (모델: resnet44, 워커: 2, 도착시간: 0초)
wait_for_resources_or_arrival 0 id49_cifar10_resnet44_sync_batch2048 2 gangk8s
# 작업 생성 시간 기록
echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/id49_cifar10_resnet44_sync_batch2048_job_create.txt
kubectl apply -f ${TFPATH}/net_script/id49_cifar10_resnet44_sync_batch2048_gangk8s.yaml
wait_for_pod_scheduling id49_cifar10_resnet44_sync_batch2048 2


# 작업: id50_cifar10_resnet44_sync_batch4096 (모델: resnet44, 워커: 4, 도착시간: 0초)
wait_for_resources_or_arrival 0 id50_cifar10_resnet44_sync_batch4096 4 gangk8s
# 작업 생성 시간 기록
echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/id50_cifar10_resnet44_sync_batch4096_job_create.txt
kubectl apply -f ${TFPATH}/net_script/id50_cifar10_resnet44_sync_batch4096_gangk8s.yaml
wait_for_pod_scheduling id50_cifar10_resnet44_sync_batch4096 4


# 작업: id51_cifar10_resnet44_sync_batch8192 (모델: resnet44, 워커: 8, 도착시간: 0초)
wait_for_resources_or_arrival 0 id51_cifar10_resnet44_sync_batch8192 8 gangk8s
# 작업 생성 시간 기록
echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/id51_cifar10_resnet44_sync_batch8192_job_create.txt
kubectl apply -f ${TFPATH}/net_script/id51_cifar10_resnet44_sync_batch8192_gangk8s.yaml
wait_for_pod_scheduling id51_cifar10_resnet44_sync_batch8192 8


# 작업: id52_cifar10_resnet44_sync_batch8192 (모델: resnet44, 워커: 8, 도착시간: 0초)
wait_for_resources_or_arrival 0 id52_cifar10_resnet44_sync_batch8192 8 gangk8s
# 작업 생성 시간 기록
echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/id52_cifar10_resnet44_sync_batch8192_job_create.txt
kubectl apply -f ${TFPATH}/net_script/id52_cifar10_resnet44_sync_batch8192_gangk8s.yaml
wait_for_pod_scheduling id52_cifar10_resnet44_sync_batch8192 8


# 작업: id53_cifar10_resnet44_sync_batch8192 (모델: resnet44, 워커: 8, 도착시간: 0초)
wait_for_resources_or_arrival 0 id53_cifar10_resnet44_sync_batch8192 8 gangk8s
# 작업 생성 시간 기록
echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/id53_cifar10_resnet44_sync_batch8192_job_create.txt
kubectl apply -f ${TFPATH}/net_script/id53_cifar10_resnet44_sync_batch8192_gangk8s.yaml
wait_for_pod_scheduling id53_cifar10_resnet44_sync_batch8192 8


# 작업: id54_cifar10_resnet110_sync_batch8192 (모델: resnet110, 워커: 8, 도착시간: 0초)
wait_for_resources_or_arrival 0 id54_cifar10_resnet110_sync_batch8192 8 gangk8s
# 작업 생성 시간 기록
echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/id54_cifar10_resnet110_sync_batch8192_job_create.txt
kubectl apply -f ${TFPATH}/net_script/id54_cifar10_resnet110_sync_batch8192_gangk8s.yaml
wait_for_pod_scheduling id54_cifar10_resnet110_sync_batch8192 8


# 작업: id55_cifar10_resnet44_sync_batch8192 (모델: resnet44, 워커: 8, 도착시간: 0초)
wait_for_resources_or_arrival 0 id55_cifar10_resnet44_sync_batch8192 8 gangk8s
# 작업 생성 시간 기록
echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/id55_cifar10_resnet44_sync_batch8192_job_create.txt
kubectl apply -f ${TFPATH}/net_script/id55_cifar10_resnet44_sync_batch8192_gangk8s.yaml
wait_for_pod_scheduling id55_cifar10_resnet44_sync_batch8192 8


# 작업: id56_cifar10_resnet44_sync_batch8192 (모델: resnet44, 워커: 8, 도착시간: 0초)
wait_for_resources_or_arrival 0 id56_cifar10_resnet44_sync_batch8192 8 gangk8s
# 작업 생성 시간 기록
echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/id56_cifar10_resnet44_sync_batch8192_job_create.txt
kubectl apply -f ${TFPATH}/net_script/id56_cifar10_resnet44_sync_batch8192_gangk8s.yaml
wait_for_pod_scheduling id56_cifar10_resnet44_sync_batch8192 8


# 작업: id57_cifar10_resnet44_sync_batch8192 (모델: resnet44, 워커: 8, 도착시간: 0초)
wait_for_resources_or_arrival 0 id57_cifar10_resnet44_sync_batch8192 8 gangk8s
# 작업 생성 시간 기록
echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/id57_cifar10_resnet44_sync_batch8192_job_create.txt
kubectl apply -f ${TFPATH}/net_script/id57_cifar10_resnet44_sync_batch8192_gangk8s.yaml
wait_for_pod_scheduling id57_cifar10_resnet44_sync_batch8192 8


# 작업: id58_imagenet_vgg16_sync_batch1024 (모델: vgg16, 워커: 8, 도착시간: 0초)
wait_for_resources_or_arrival 0 id58_imagenet_vgg16_sync_batch1024 8 gangk8s
# 작업 생성 시간 기록
echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/id58_imagenet_vgg16_sync_batch1024_job_create.txt
kubectl apply -f ${TFPATH}/net_script/id58_imagenet_vgg16_sync_batch1024_gangk8s.yaml
wait_for_pod_scheduling id58_imagenet_vgg16_sync_batch1024 8


# 작업: id59_imagenet_resnet50_sync_batch1024 (모델: resnet50, 워커: 8, 도착시간: 0초)
wait_for_resources_or_arrival 0 id59_imagenet_resnet50_sync_batch1024 8 gangk8s
# 작업 생성 시간 기록
echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/id59_imagenet_resnet50_sync_batch1024_job_create.txt
kubectl apply -f ${TFPATH}/net_script/id59_imagenet_resnet50_sync_batch1024_gangk8s.yaml
wait_for_pod_scheduling id59_imagenet_resnet50_sync_batch1024 8



ENDTIME=`date "+%H:%M:%S.%N"`
echo "$ENDTIME" > ${SAVEPATH}/end_makespan.txt
ENDLOGTIME=$(($(date +%s%N)/1000000000))
LOGTIME=$(($ENDLOGTIME - $STARTLOGTIME))

# 스케줄러 전체 로그
kubectl logs -n kube-system kube-scheduler-xsailor-master > ${SAVEPATH}/scheduler_full_log.txt

kubectl logs -n kube-system tensorspot-scheduler > ${SAVEPATH}/scheduler_log.txt


# On-prem
# ssh xsailor2@163.152.20.132 "sudo sh /home/jhlee21/gpu_off.sh"
# ssh xsailor3@163.152.20.155 "sudo sh /home/jhlee21/gpu_off.sh"
 