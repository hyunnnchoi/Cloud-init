#!/bin/bash
STARTTIME=`date "+%H:%M:%S.%N"`
STARTEPOCH=`date +%s`  # 스크립트 시작 시간 (epoch 초)
STARTLOGTIME=$(($(date +%s%N)/1000000000))
TFPATH="/home/tensorspot/Cloud-init"
SAVEPATH="/home/tensorspot/tfjob"


PEM_KEY="/home/ubuntu/tethys-v-c2/tethys.pem"


sudo rm -rf ${SAVEPATH}/*
echo "$STARTTIME" > ${SAVEPATH}/start_makespan.txt




# Lambda Labs - 동적으로 노드 IP 가져와서 GPU 스크립트 실행
NODE_IPS=$(kubectl get nodes -o wide --no-headers | awk '{print $6}')
for node_ip in $NODE_IPS; do
    ssh -i ${PEM_KEY} -o StrictHostKeyChecking=no ubuntu@$node_ip "sudo sh /home/tensorspot/Cloud-init/gpu.sh &" &
done



# 사용 가능한 총 GPU 수 체크하는 함수
total_gpu_num=$(kubectl get nodes "-o=custom-columns=NAME:.metadata.name,GPU:.status.allocatable.nvidia\\.com/gpu" | grep -v NAME | awk '{if ($2 ~ /^[0-9]+$/) sum += $2} END {print sum}')
configured_gpu_num=16
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
    TIMEOUT=300  # 5분 타임아웃
    START_TIME=$(date +%s)

    while [ $SCHEDULED_PODS -lt $WORKER_COUNT ]
    do
        # 현재 이 작업의 Running 상태이거나 ContainerCreating 상태인 포드 수 계산
        SCHEDULED_PODS=$(kubectl get pods -l job-name=$JOB_NAME -o jsonpath='{range .items[*]}{.status.phase}{"\n"}{end}' | grep -E "(Running|ContainerCreating|Completed)" | wc -l)

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
            kubectl get pods -o jsonpath='{range .items[?(@.metadata.name=~"'$JOB_NAME_DASH'")]}{.metadata.name}{"\t"}{.spec.nodeName}{"\n"}{end}' >> ${SAVEPATH}/${JOB_NAME}_node_allocation.txt
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

echo "총 GPU 수: 16"


# 작업: id0_squad_bert_sync_batch8 (모델: bert, 워커: 2, 도착시간: 0초)
wait_for_resources_or_arrival 0 id0_squad_bert_sync_batch8 2 spot
# 작업 생성 시간 기록
echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/id0_squad_bert_sync_batch8_job_create.txt
kubectl apply -f ${TFPATH}/net_script/id0_squad_bert_sync_batch8_spot.yaml
wait_for_pod_scheduling id0_squad_bert_sync_batch8 2


# 작업: id1_squad_bert_sync_batch32 (모델: bert, 워커: 8, 도착시간: 822초)
wait_for_resources_or_arrival 822 id1_squad_bert_sync_batch32 8 spot
# 작업 생성 시간 기록
echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/id1_squad_bert_sync_batch32_job_create.txt
kubectl apply -f ${TFPATH}/net_script/id1_squad_bert_sync_batch32_spot.yaml
wait_for_pod_scheduling id1_squad_bert_sync_batch32 8


# 작업: id2_imagenet_googlenet_sync_batch1024 (모델: googlenet, 워커: 4, 도착시간: 1524초)
wait_for_resources_or_arrival 1524 id2_imagenet_googlenet_sync_batch1024 4 spot
# 작업 생성 시간 기록
echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/id2_imagenet_googlenet_sync_batch1024_job_create.txt
kubectl apply -f ${TFPATH}/net_script/id2_imagenet_googlenet_sync_batch1024_spot.yaml
wait_for_pod_scheduling id2_imagenet_googlenet_sync_batch1024 4


# 작업: id3_imagenet_vgg16_sync_batch256 (모델: vgg16, 워커: 2, 도착시간: 2163초)
wait_for_resources_or_arrival 2163 id3_imagenet_vgg16_sync_batch256 2 spot
# 작업 생성 시간 기록
echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/id3_imagenet_vgg16_sync_batch256_job_create.txt
kubectl apply -f ${TFPATH}/net_script/id3_imagenet_vgg16_sync_batch256_spot.yaml
wait_for_pod_scheduling id3_imagenet_vgg16_sync_batch256 2


# 작업: id4_squad_bert_sync_batch16 (모델: bert, 워커: 4, 도착시간: 2265초)
wait_for_resources_or_arrival 2265 id4_squad_bert_sync_batch16 4 spot
# 작업 생성 시간 기록
echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/id4_squad_bert_sync_batch16_job_create.txt
kubectl apply -f ${TFPATH}/net_script/id4_squad_bert_sync_batch16_spot.yaml
wait_for_pod_scheduling id4_squad_bert_sync_batch16 4


# 작업: id5_imagenet_resnet44_sync_batch2048 (모델: resnet44, 워커: 2, 도착시간: 3291초)
wait_for_resources_or_arrival 3291 id5_imagenet_resnet44_sync_batch2048 2 spot
# 작업 생성 시간 기록
echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/id5_imagenet_resnet44_sync_batch2048_job_create.txt
kubectl apply -f ${TFPATH}/net_script/id5_imagenet_resnet44_sync_batch2048_spot.yaml
wait_for_pod_scheduling id5_imagenet_resnet44_sync_batch2048 2


# 작업: id6_imagenet_inception3_sync_batch256 (모델: inception3, 워커: 4, 도착시간: 3372초)
wait_for_resources_or_arrival 3372 id6_imagenet_inception3_sync_batch256 4 spot
# 작업 생성 시간 기록
echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/id6_imagenet_inception3_sync_batch256_job_create.txt
kubectl apply -f ${TFPATH}/net_script/id6_imagenet_inception3_sync_batch256_spot.yaml
wait_for_pod_scheduling id6_imagenet_inception3_sync_batch256 4


# 작업: id7_speech_whisper_sync_batch32 (모델: whisper, 워커: 8, 도착시간: 4831초)
wait_for_resources_or_arrival 4831 id7_speech_whisper_sync_batch32 8 spot
# 작업 생성 시간 기록
echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/id7_speech_whisper_sync_batch32_job_create.txt
kubectl apply -f ${TFPATH}/net_script/id7_speech_whisper_sync_batch32_spot.yaml
wait_for_pod_scheduling id7_speech_whisper_sync_batch32 8


# 작업: id8_imagenet_densenet100_k12_sync_batch1024 (모델: densenet100_k12, 워커: 8, 도착시간: 5493초)
wait_for_resources_or_arrival 5493 id8_imagenet_densenet100_k12_sync_batch1024 8 spot
# 작업 생성 시간 기록
echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/id8_imagenet_densenet100_k12_sync_batch1024_job_create.txt
kubectl apply -f ${TFPATH}/net_script/id8_imagenet_densenet100_k12_sync_batch1024_spot.yaml
wait_for_pod_scheduling id8_imagenet_densenet100_k12_sync_batch1024 8


# 작업: id9_imagenet_resnet44_sync_batch2048 (모델: resnet44, 워커: 2, 도착시간: 7322초)
wait_for_resources_or_arrival 7322 id9_imagenet_resnet44_sync_batch2048 2 spot
# 작업 생성 시간 기록
echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/id9_imagenet_resnet44_sync_batch2048_job_create.txt
kubectl apply -f ${TFPATH}/net_script/id9_imagenet_resnet44_sync_batch2048_spot.yaml
wait_for_pod_scheduling id9_imagenet_resnet44_sync_batch2048 2


# 작업: id10_imagenet_resnet110_sync_batch8192 (모델: resnet110, 워커: 8, 도착시간: 7641초)
wait_for_resources_or_arrival 7641 id10_imagenet_resnet110_sync_batch8192 8 spot
# 작업 생성 시간 기록
echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/id10_imagenet_resnet110_sync_batch8192_job_create.txt
kubectl apply -f ${TFPATH}/net_script/id10_imagenet_resnet110_sync_batch8192_spot.yaml
wait_for_pod_scheduling id10_imagenet_resnet110_sync_batch8192 8


# 작업: id11_imagenet_resnet44_sync_batch2048 (모델: resnet44, 워커: 2, 도착시간: 7678초)
wait_for_resources_or_arrival 7678 id11_imagenet_resnet44_sync_batch2048 2 spot
# 작업 생성 시간 기록
echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/id11_imagenet_resnet44_sync_batch2048_job_create.txt
kubectl apply -f ${TFPATH}/net_script/id11_imagenet_resnet44_sync_batch2048_spot.yaml
wait_for_pod_scheduling id11_imagenet_resnet44_sync_batch2048 2


# 작업: id12_imagenet_densenet100_k12_sync_batch512 (모델: densenet100_k12, 워커: 4, 도착시간: 8875초)
wait_for_resources_or_arrival 8875 id12_imagenet_densenet100_k12_sync_batch512 4 spot
# 작업 생성 시간 기록
echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/id12_imagenet_densenet100_k12_sync_batch512_job_create.txt
kubectl apply -f ${TFPATH}/net_script/id12_imagenet_densenet100_k12_sync_batch512_spot.yaml
wait_for_pod_scheduling id12_imagenet_densenet100_k12_sync_batch512 4


# 작업: id13_imagenet_densenet40_k12_sync_batch4096 (모델: densenet40_k12, 워커: 4, 도착시간: 9280초)
wait_for_resources_or_arrival 9280 id13_imagenet_densenet40_k12_sync_batch4096 4 spot
# 작업 생성 시간 기록
echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/id13_imagenet_densenet40_k12_sync_batch4096_job_create.txt
kubectl apply -f ${TFPATH}/net_script/id13_imagenet_densenet40_k12_sync_batch4096_spot.yaml
wait_for_pod_scheduling id13_imagenet_densenet40_k12_sync_batch4096 4


# 작업: id14_imagenet_resnet44_sync_batch8192 (모델: resnet44, 워커: 8, 도착시간: 9674초)
wait_for_resources_or_arrival 9674 id14_imagenet_resnet44_sync_batch8192 8 spot
# 작업 생성 시간 기록
echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/id14_imagenet_resnet44_sync_batch8192_job_create.txt
kubectl apply -f ${TFPATH}/net_script/id14_imagenet_resnet44_sync_batch8192_spot.yaml
wait_for_pod_scheduling id14_imagenet_resnet44_sync_batch8192 8


# 작업: id15_imagenet_resnet44_sync_batch2048 (모델: resnet44, 워커: 2, 도착시간: 10469초)
wait_for_resources_or_arrival 10469 id15_imagenet_resnet44_sync_batch2048 2 spot
# 작업 생성 시간 기록
echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/id15_imagenet_resnet44_sync_batch2048_job_create.txt
kubectl apply -f ${TFPATH}/net_script/id15_imagenet_resnet44_sync_batch2048_spot.yaml
wait_for_pod_scheduling id15_imagenet_resnet44_sync_batch2048 2


# 작업: id16_squad_bert_sync_batch16 (모델: bert, 워커: 4, 도착시간: 10663초)
wait_for_resources_or_arrival 10663 id16_squad_bert_sync_batch16 4 spot
# 작업 생성 시간 기록
echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/id16_squad_bert_sync_batch16_job_create.txt
kubectl apply -f ${TFPATH}/net_script/id16_squad_bert_sync_batch16_spot.yaml
wait_for_pod_scheduling id16_squad_bert_sync_batch16 4


# 작업: id17_imagenet_densenet40_k12_sync_batch8192 (모델: densenet40_k12, 워커: 8, 도착시간: 11697초)
wait_for_resources_or_arrival 11697 id17_imagenet_densenet40_k12_sync_batch8192 8 spot
# 작업 생성 시간 기록
echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/id17_imagenet_densenet40_k12_sync_batch8192_job_create.txt
kubectl apply -f ${TFPATH}/net_script/id17_imagenet_densenet40_k12_sync_batch8192_spot.yaml
wait_for_pod_scheduling id17_imagenet_densenet40_k12_sync_batch8192 8


# 작업: id18_imagenet_resnet50_sync_batch512 (모델: resnet50, 워커: 4, 도착시간: 11716초)
wait_for_resources_or_arrival 11716 id18_imagenet_resnet50_sync_batch512 4 spot
# 작업 생성 시간 기록
echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/id18_imagenet_resnet50_sync_batch512_job_create.txt
kubectl apply -f ${TFPATH}/net_script/id18_imagenet_resnet50_sync_batch512_spot.yaml
wait_for_pod_scheduling id18_imagenet_resnet50_sync_batch512 4


# 작업: id19_imagenet_resnet50_sync_batch1024 (모델: resnet50, 워커: 8, 도착시간: 11961초)
wait_for_resources_or_arrival 11961 id19_imagenet_resnet50_sync_batch1024 8 spot
# 작업 생성 시간 기록
echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/id19_imagenet_resnet50_sync_batch1024_job_create.txt
kubectl apply -f ${TFPATH}/net_script/id19_imagenet_resnet50_sync_batch1024_spot.yaml
wait_for_pod_scheduling id19_imagenet_resnet50_sync_batch1024 8


# 작업: id20_imagenet_inception3_sync_batch256 (모델: inception3, 워커: 4, 도착시간: 12650초)
wait_for_resources_or_arrival 12650 id20_imagenet_inception3_sync_batch256 4 spot
# 작업 생성 시간 기록
echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/id20_imagenet_inception3_sync_batch256_job_create.txt
kubectl apply -f ${TFPATH}/net_script/id20_imagenet_inception3_sync_batch256_spot.yaml
wait_for_pod_scheduling id20_imagenet_inception3_sync_batch256 4


# 작업: id21_imagenet_densenet100_k12_sync_batch1024 (모델: densenet100_k12, 워커: 8, 도착시간: 13006초)
wait_for_resources_or_arrival 13006 id21_imagenet_densenet100_k12_sync_batch1024 8 spot
# 작업 생성 시간 기록
echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/id21_imagenet_densenet100_k12_sync_batch1024_job_create.txt
kubectl apply -f ${TFPATH}/net_script/id21_imagenet_densenet100_k12_sync_batch1024_spot.yaml
wait_for_pod_scheduling id21_imagenet_densenet100_k12_sync_batch1024 8


# 작업: id22_imagenet_densenet40_k12_sync_batch8192 (모델: densenet40_k12, 워커: 8, 도착시간: 13419초)
wait_for_resources_or_arrival 13419 id22_imagenet_densenet40_k12_sync_batch8192 8 spot
# 작업 생성 시간 기록
echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/id22_imagenet_densenet40_k12_sync_batch8192_job_create.txt
kubectl apply -f ${TFPATH}/net_script/id22_imagenet_densenet40_k12_sync_batch8192_spot.yaml
wait_for_pod_scheduling id22_imagenet_densenet40_k12_sync_batch8192 8


# 작업: id23_imagenet_resnet110_sync_batch4096 (모델: resnet110, 워커: 4, 도착시간: 14028초)
wait_for_resources_or_arrival 14028 id23_imagenet_resnet110_sync_batch4096 4 spot
# 작업 생성 시간 기록
echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/id23_imagenet_resnet110_sync_batch4096_job_create.txt
kubectl apply -f ${TFPATH}/net_script/id23_imagenet_resnet110_sync_batch4096_spot.yaml
wait_for_pod_scheduling id23_imagenet_resnet110_sync_batch4096 4


# 작업: id24_squad_gpt2_sync_batch32 (모델: gpt2, 워커: 8, 도착시간: 14241초)
wait_for_resources_or_arrival 14241 id24_squad_gpt2_sync_batch32 8 spot
# 작업 생성 시간 기록
echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/id24_squad_gpt2_sync_batch32_job_create.txt
kubectl apply -f ${TFPATH}/net_script/id24_squad_gpt2_sync_batch32_spot.yaml
wait_for_pod_scheduling id24_squad_gpt2_sync_batch32 8


# 작업: id25_imagenet_densenet100_k12_sync_batch1024 (모델: densenet100_k12, 워커: 8, 도착시간: 14261초)
wait_for_resources_or_arrival 14261 id25_imagenet_densenet100_k12_sync_batch1024 8 spot
# 작업 생성 시간 기록
echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/id25_imagenet_densenet100_k12_sync_batch1024_job_create.txt
kubectl apply -f ${TFPATH}/net_script/id25_imagenet_densenet100_k12_sync_batch1024_spot.yaml
wait_for_pod_scheduling id25_imagenet_densenet100_k12_sync_batch1024 8


# 작업: id26_speech_whisper_sync_batch32 (모델: whisper, 워커: 8, 도착시간: 14491초)
wait_for_resources_or_arrival 14491 id26_speech_whisper_sync_batch32 8 spot
# 작업 생성 시간 기록
echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/id26_speech_whisper_sync_batch32_job_create.txt
kubectl apply -f ${TFPATH}/net_script/id26_speech_whisper_sync_batch32_spot.yaml
wait_for_pod_scheduling id26_speech_whisper_sync_batch32 8


# 작업: id27_speech_whisper_sync_batch32 (모델: whisper, 워커: 8, 도착시간: 14760초)
wait_for_resources_or_arrival 14760 id27_speech_whisper_sync_batch32 8 spot
# 작업 생성 시간 기록
echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/id27_speech_whisper_sync_batch32_job_create.txt
kubectl apply -f ${TFPATH}/net_script/id27_speech_whisper_sync_batch32_spot.yaml
wait_for_pod_scheduling id27_speech_whisper_sync_batch32 8


# 작업: id28_imagenet_densenet40_k12_sync_batch8192 (모델: densenet40_k12, 워커: 8, 도착시간: 14787초)
wait_for_resources_or_arrival 14787 id28_imagenet_densenet40_k12_sync_batch8192 8 spot
# 작업 생성 시간 기록
echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/id28_imagenet_densenet40_k12_sync_batch8192_job_create.txt
kubectl apply -f ${TFPATH}/net_script/id28_imagenet_densenet40_k12_sync_batch8192_spot.yaml
wait_for_pod_scheduling id28_imagenet_densenet40_k12_sync_batch8192 8


# 작업: id29_imagenet_densenet100_k12_sync_batch1024 (모델: densenet100_k12, 워커: 8, 도착시간: 15343초)
wait_for_resources_or_arrival 15343 id29_imagenet_densenet100_k12_sync_batch1024 8 spot
# 작업 생성 시간 기록
echo "$(date "+%H:%M:%S.%N")" > ${SAVEPATH}/id29_imagenet_densenet100_k12_sync_batch1024_job_create.txt
kubectl apply -f ${TFPATH}/net_script/id29_imagenet_densenet100_k12_sync_batch1024_spot.yaml
wait_for_pod_scheduling id29_imagenet_densenet100_k12_sync_batch1024 8



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
 
