
#!/bin/bash
STARTTIME=`date "+%H:%M:%S.%N"`
STARTEPOCH=`date +%s`  # 스크립트 시작 시간 (epoch 초)
STARTLOGTIME=$(($(date +%s%N)/1000000000))
TFPATH="/home/tensorspot/Cloud-init"
# GCP
SAVEPATH="/home/tensorspot/tfjob"
sudo rm -rf ${SAVEPATH}/*
echo "$STARTTIME" > ${SAVEPATH}/start_makespan.txt
# GCP

# gcloud compute ssh --zone us-central1-a xsailor-master --command "sudo sh /home/jhlee21/gpu.sh &" &

# gcloud compute ssh --zone us-central1-a xsailor-worker1 --command "sudo sh /home/jhlee21/gpu.sh &" &

# 사용 가능한 총 GPU 수 체크하는 함수
total_gpu_num=$(kubectl get nodes "-o=custom-columns=NAME:.metadata.name,GPU:.status.allocatable.nvidia\.com/gpu" | grep -v NAME | awk '{if ($2 ~ /^[0-9]+$/) sum += $2} END {print sum}')

# 값이 없거나 0이면 기본값 사용
if [ -z "$total_gpu_num" ] || [ "$total_gpu_num" = "0" ]; then
    # 실제 노드에서 GPU 확인
    NODE_COUNT=$(kubectl get nodes | grep Ready | wc -l)
    if [ "$NODE_COUNT" -gt 0 ]; then
        # 노드당 평균 8개 GPU 가정 (로그에서 확인된 값)
        total_gpu_num=$((NODE_COUNT * 8))
    else
        # 기본값
        total_gpu_num=8
    fi
fi

echo "총 GPU 수: $total_gpu_num"
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
        SCHEDULED_PODS=$(kubectl get pods | grep $JOB_NAME_DASH | grep -v Pending | wc -l)

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
            break
        fi
    done
}

# 자원과 arrival_time을 고려하여 대기하는 함수 (스케줄러에 따라 다른 로직 적용)
wait_for_resources_or_arrival() {
    ARRIVAL_TIME=$1
    JOB_NAME=$2
    WORKER_NUM=$3
    SCHEDULER="$4"

    echo "Checking resources for job ${JOB_NAME} (arrival time: ${ARRIVAL_TIME}s, workers: $WORKER_NUM)"

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
                    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt
                    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt

                    # 작업 삭제
                    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_${SCHEDULER}.yaml
                done

                # 자원이 해제되었으므로 다시 확인
                AVAILABLE_GPUS=$(get_available_gpus)
                echo "Available GPUs after cleanup: $AVAILABLE_GPUS (needed: $WORKER_NUM)"
            fi

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
                return 0
            else
                # 대기 중인 포드가 있으면 완료된 작업 확인 및 정리
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

                        echo "Job ${COMPLETED_JOB} completed (controller/chief is in Completed state)"

                        # 노드 정보 저장
                        kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt
                        echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt

                        # 작업 삭제
                        kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_${SCHEDULER}.yaml
                    done

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

# 작업: id0_squad_gpt2_sync_batch16 (모델: gpt2, 워커: 4, 도착시간: 0초)
wait_for_resources_or_arrival 0 id0_squad_gpt2_sync_batch16 4 colo
echo "$(date "+%H:%M:%S.%N") - 작업 id0_squad_gpt2_sync_batch16 시작" > ${SAVEPATH}/id0_squad_gpt2_sync_batch16_job_start.txt
kubectl apply -f ${TFPATH}/net_script/id0_squad_gpt2_sync_batch16_colo.yaml
wait_for_pod_scheduling id0_squad_gpt2_sync_batch16 4


# 작업: id1_imagenet_resnet50_sync_batch1024 (모델: resnet50, 워커: 8, 도착시간: 103초)
wait_for_resources_or_arrival 103 id1_imagenet_resnet50_sync_batch1024 8 colo
echo "$(date "+%H:%M:%S.%N") - 작업 id1_imagenet_resnet50_sync_batch1024 시작" > ${SAVEPATH}/id1_imagenet_resnet50_sync_batch1024_job_start.txt
kubectl apply -f ${TFPATH}/net_script/id1_imagenet_resnet50_sync_batch1024_colo.yaml
wait_for_pod_scheduling id1_imagenet_resnet50_sync_batch1024 8


# 작업: id2_imagenet_resnet50_sync_batch512 (모델: resnet50, 워커: 4, 도착시간: 169초)
wait_for_resources_or_arrival 169 id2_imagenet_resnet50_sync_batch512 4 colo
echo "$(date "+%H:%M:%S.%N") - 작업 id2_imagenet_resnet50_sync_batch512 시작" > ${SAVEPATH}/id2_imagenet_resnet50_sync_batch512_job_start.txt
kubectl apply -f ${TFPATH}/net_script/id2_imagenet_resnet50_sync_batch512_colo.yaml
wait_for_pod_scheduling id2_imagenet_resnet50_sync_batch512 4


# 작업: id3_cifar10_resnet44_sync_batch4096 (모델: resnet44, 워커: 4, 도착시간: 243초)
wait_for_resources_or_arrival 243 id3_cifar10_resnet44_sync_batch4096 4 colo
echo "$(date "+%H:%M:%S.%N") - 작업 id3_cifar10_resnet44_sync_batch4096 시작" > ${SAVEPATH}/id3_cifar10_resnet44_sync_batch4096_job_start.txt
kubectl apply -f ${TFPATH}/net_script/id3_cifar10_resnet44_sync_batch4096_colo.yaml
wait_for_pod_scheduling id3_cifar10_resnet44_sync_batch4096 4


# 작업: id4_cifar10_resnet44_sync_batch4096 (모델: resnet44, 워커: 4, 도착시간: 490초)
wait_for_resources_or_arrival 490 id4_cifar10_resnet44_sync_batch4096 4 colo
echo "$(date "+%H:%M:%S.%N") - 작업 id4_cifar10_resnet44_sync_batch4096 시작" > ${SAVEPATH}/id4_cifar10_resnet44_sync_batch4096_job_start.txt
kubectl apply -f ${TFPATH}/net_script/id4_cifar10_resnet44_sync_batch4096_colo.yaml
wait_for_pod_scheduling id4_cifar10_resnet44_sync_batch4096 4


# 작업: id5_imagenet_resnet50_sync_batch512 (모델: resnet50, 워커: 4, 도착시간: 516초)
wait_for_resources_or_arrival 516 id5_imagenet_resnet50_sync_batch512 4 colo
echo "$(date "+%H:%M:%S.%N") - 작업 id5_imagenet_resnet50_sync_batch512 시작" > ${SAVEPATH}/id5_imagenet_resnet50_sync_batch512_job_start.txt
kubectl apply -f ${TFPATH}/net_script/id5_imagenet_resnet50_sync_batch512_colo.yaml
wait_for_pod_scheduling id5_imagenet_resnet50_sync_batch512 4


# 작업: id6_imagenet_vgg16_sync_batch512 (모델: vgg16, 워커: 4, 도착시간: 841초)
wait_for_resources_or_arrival 841 id6_imagenet_vgg16_sync_batch512 4 colo
echo "$(date "+%H:%M:%S.%N") - 작업 id6_imagenet_vgg16_sync_batch512 시작" > ${SAVEPATH}/id6_imagenet_vgg16_sync_batch512_job_start.txt
kubectl apply -f ${TFPATH}/net_script/id6_imagenet_vgg16_sync_batch512_colo.yaml
wait_for_pod_scheduling id6_imagenet_vgg16_sync_batch512 4


# 작업: id7_imagenet_vgg16_sync_batch1024 (모델: vgg16, 워커: 8, 도착시간: 850초)
wait_for_resources_or_arrival 850 id7_imagenet_vgg16_sync_batch1024 8 colo
echo "$(date "+%H:%M:%S.%N") - 작업 id7_imagenet_vgg16_sync_batch1024 시작" > ${SAVEPATH}/id7_imagenet_vgg16_sync_batch1024_job_start.txt
kubectl apply -f ${TFPATH}/net_script/id7_imagenet_vgg16_sync_batch1024_colo.yaml
wait_for_pod_scheduling id7_imagenet_vgg16_sync_batch1024 8


# 작업: id8_squad_bert_sync_batch32 (모델: bert, 워커: 8, 도착시간: 952초)
wait_for_resources_or_arrival 952 id8_squad_bert_sync_batch32 8 colo
echo "$(date "+%H:%M:%S.%N") - 작업 id8_squad_bert_sync_batch32 시작" > ${SAVEPATH}/id8_squad_bert_sync_batch32_job_start.txt
kubectl apply -f ${TFPATH}/net_script/id8_squad_bert_sync_batch32_colo.yaml
wait_for_pod_scheduling id8_squad_bert_sync_batch32 8


# 작업: id9_squad_bert_sync_batch32 (모델: bert, 워커: 8, 도착시간: 955초)
wait_for_resources_or_arrival 955 id9_squad_bert_sync_batch32 8 colo
echo "$(date "+%H:%M:%S.%N") - 작업 id9_squad_bert_sync_batch32 시작" > ${SAVEPATH}/id9_squad_bert_sync_batch32_job_start.txt
kubectl apply -f ${TFPATH}/net_script/id9_squad_bert_sync_batch32_colo.yaml
wait_for_pod_scheduling id9_squad_bert_sync_batch32 8


# 작업: id10_imagenet_vgg16_sync_batch256 (모델: vgg16, 워커: 2, 도착시간: 1078초)
wait_for_resources_or_arrival 1078 id10_imagenet_vgg16_sync_batch256 2 colo
echo "$(date "+%H:%M:%S.%N") - 작업 id10_imagenet_vgg16_sync_batch256 시작" > ${SAVEPATH}/id10_imagenet_vgg16_sync_batch256_job_start.txt
kubectl apply -f ${TFPATH}/net_script/id10_imagenet_vgg16_sync_batch256_colo.yaml
wait_for_pod_scheduling id10_imagenet_vgg16_sync_batch256 2


# 작업: id11_imagenet_resnet50_sync_batch512 (모델: resnet50, 워커: 4, 도착시간: 1192초)
wait_for_resources_or_arrival 1192 id11_imagenet_resnet50_sync_batch512 4 colo
echo "$(date "+%H:%M:%S.%N") - 작업 id11_imagenet_resnet50_sync_batch512 시작" > ${SAVEPATH}/id11_imagenet_resnet50_sync_batch512_job_start.txt
kubectl apply -f ${TFPATH}/net_script/id11_imagenet_resnet50_sync_batch512_colo.yaml
wait_for_pod_scheduling id11_imagenet_resnet50_sync_batch512 4


# 작업: id12_squad_bert_sync_batch16 (모델: bert, 워커: 4, 도착시간: 1415초)
wait_for_resources_or_arrival 1415 id12_squad_bert_sync_batch16 4 colo
echo "$(date "+%H:%M:%S.%N") - 작업 id12_squad_bert_sync_batch16 시작" > ${SAVEPATH}/id12_squad_bert_sync_batch16_job_start.txt
kubectl apply -f ${TFPATH}/net_script/id12_squad_bert_sync_batch16_colo.yaml
wait_for_pod_scheduling id12_squad_bert_sync_batch16 4


# 작업: id13_squad_bert_sync_batch8 (모델: bert, 워커: 2, 도착시간: 1735초)
wait_for_resources_or_arrival 1735 id13_squad_bert_sync_batch8 2 colo
echo "$(date "+%H:%M:%S.%N") - 작업 id13_squad_bert_sync_batch8 시작" > ${SAVEPATH}/id13_squad_bert_sync_batch8_job_start.txt
kubectl apply -f ${TFPATH}/net_script/id13_squad_bert_sync_batch8_colo.yaml
wait_for_pod_scheduling id13_squad_bert_sync_batch8 2


# 작업: id14_squad_gpt2_sync_batch8 (모델: gpt2, 워커: 2, 도착시간: 1801초)
wait_for_resources_or_arrival 1801 id14_squad_gpt2_sync_batch8 2 colo
echo "$(date "+%H:%M:%S.%N") - 작업 id14_squad_gpt2_sync_batch8 시작" > ${SAVEPATH}/id14_squad_gpt2_sync_batch8_job_start.txt
kubectl apply -f ${TFPATH}/net_script/id14_squad_gpt2_sync_batch8_colo.yaml
wait_for_pod_scheduling id14_squad_gpt2_sync_batch8 2


# 작업: id15_squad_gpt2_sync_batch32 (모델: gpt2, 워커: 8, 도착시간: 1926초)
wait_for_resources_or_arrival 1926 id15_squad_gpt2_sync_batch32 8 colo
echo "$(date "+%H:%M:%S.%N") - 작업 id15_squad_gpt2_sync_batch32 시작" > ${SAVEPATH}/id15_squad_gpt2_sync_batch32_job_start.txt
kubectl apply -f ${TFPATH}/net_script/id15_squad_gpt2_sync_batch32_colo.yaml
wait_for_pod_scheduling id15_squad_gpt2_sync_batch32 8


# 작업: id16_imagenet_vgg16_sync_batch512 (모델: vgg16, 워커: 4, 도착시간: 2216초)
wait_for_resources_or_arrival 2216 id16_imagenet_vgg16_sync_batch512 4 colo
echo "$(date "+%H:%M:%S.%N") - 작업 id16_imagenet_vgg16_sync_batch512 시작" > ${SAVEPATH}/id16_imagenet_vgg16_sync_batch512_job_start.txt
kubectl apply -f ${TFPATH}/net_script/id16_imagenet_vgg16_sync_batch512_colo.yaml
wait_for_pod_scheduling id16_imagenet_vgg16_sync_batch512 4


# 작업: id17_imagenet_resnet50_sync_batch1024 (모델: resnet50, 워커: 8, 도착시간: 2325초)
wait_for_resources_or_arrival 2325 id17_imagenet_resnet50_sync_batch1024 8 colo
echo "$(date "+%H:%M:%S.%N") - 작업 id17_imagenet_resnet50_sync_batch1024 시작" > ${SAVEPATH}/id17_imagenet_resnet50_sync_batch1024_job_start.txt
kubectl apply -f ${TFPATH}/net_script/id17_imagenet_resnet50_sync_batch1024_colo.yaml
wait_for_pod_scheduling id17_imagenet_resnet50_sync_batch1024 8


# 작업: id18_cifar10_resnet44_sync_batch2048 (모델: resnet44, 워커: 2, 도착시간: 2369초)
wait_for_resources_or_arrival 2369 id18_cifar10_resnet44_sync_batch2048 2 colo
echo "$(date "+%H:%M:%S.%N") - 작업 id18_cifar10_resnet44_sync_batch2048 시작" > ${SAVEPATH}/id18_cifar10_resnet44_sync_batch2048_job_start.txt
kubectl apply -f ${TFPATH}/net_script/id18_cifar10_resnet44_sync_batch2048_colo.yaml
wait_for_pod_scheduling id18_cifar10_resnet44_sync_batch2048 2


# 작업: id19_cifar10_resnet44_sync_batch2048 (모델: resnet44, 워커: 2, 도착시간: 2412초)
wait_for_resources_or_arrival 2412 id19_cifar10_resnet44_sync_batch2048 2 colo
echo "$(date "+%H:%M:%S.%N") - 작업 id19_cifar10_resnet44_sync_batch2048 시작" > ${SAVEPATH}/id19_cifar10_resnet44_sync_batch2048_job_start.txt
kubectl apply -f ${TFPATH}/net_script/id19_cifar10_resnet44_sync_batch2048_colo.yaml
wait_for_pod_scheduling id19_cifar10_resnet44_sync_batch2048 2


# 작업: id20_squad_bert_sync_batch32 (모델: bert, 워커: 8, 도착시간: 2451초)
wait_for_resources_or_arrival 2451 id20_squad_bert_sync_batch32 8 colo
echo "$(date "+%H:%M:%S.%N") - 작업 id20_squad_bert_sync_batch32 시작" > ${SAVEPATH}/id20_squad_bert_sync_batch32_job_start.txt
kubectl apply -f ${TFPATH}/net_script/id20_squad_bert_sync_batch32_colo.yaml
wait_for_pod_scheduling id20_squad_bert_sync_batch32 8


# 작업: id21_imagenet_vgg16_sync_batch256 (모델: vgg16, 워커: 2, 도착시간: 2806초)
wait_for_resources_or_arrival 2806 id21_imagenet_vgg16_sync_batch256 2 colo
echo "$(date "+%H:%M:%S.%N") - 작업 id21_imagenet_vgg16_sync_batch256 시작" > ${SAVEPATH}/id21_imagenet_vgg16_sync_batch256_job_start.txt
kubectl apply -f ${TFPATH}/net_script/id21_imagenet_vgg16_sync_batch256_colo.yaml
wait_for_pod_scheduling id21_imagenet_vgg16_sync_batch256 2


# 작업: id22_imagenet_resnet50_sync_batch1024 (모델: resnet50, 워커: 8, 도착시간: 2864초)
wait_for_resources_or_arrival 2864 id22_imagenet_resnet50_sync_batch1024 8 colo
echo "$(date "+%H:%M:%S.%N") - 작업 id22_imagenet_resnet50_sync_batch1024 시작" > ${SAVEPATH}/id22_imagenet_resnet50_sync_batch1024_job_start.txt
kubectl apply -f ${TFPATH}/net_script/id22_imagenet_resnet50_sync_batch1024_colo.yaml
wait_for_pod_scheduling id22_imagenet_resnet50_sync_batch1024 8


# 작업: id23_squad_gpt2_sync_batch32 (모델: gpt2, 워커: 8, 도착시간: 3194초)
wait_for_resources_or_arrival 3194 id23_squad_gpt2_sync_batch32 8 colo
echo "$(date "+%H:%M:%S.%N") - 작업 id23_squad_gpt2_sync_batch32 시작" > ${SAVEPATH}/id23_squad_gpt2_sync_batch32_job_start.txt
kubectl apply -f ${TFPATH}/net_script/id23_squad_gpt2_sync_batch32_colo.yaml
wait_for_pod_scheduling id23_squad_gpt2_sync_batch32 8


# 작업: id24_squad_gpt2_sync_batch32 (모델: gpt2, 워커: 8, 도착시간: 3412초)
wait_for_resources_or_arrival 3412 id24_squad_gpt2_sync_batch32 8 colo
echo "$(date "+%H:%M:%S.%N") - 작업 id24_squad_gpt2_sync_batch32 시작" > ${SAVEPATH}/id24_squad_gpt2_sync_batch32_job_start.txt
kubectl apply -f ${TFPATH}/net_script/id24_squad_gpt2_sync_batch32_colo.yaml
wait_for_pod_scheduling id24_squad_gpt2_sync_batch32 8


# 작업: id25_cifar10_resnet44_sync_batch8192 (모델: resnet44, 워커: 8, 도착시간: 3544초)
wait_for_resources_or_arrival 3544 id25_cifar10_resnet44_sync_batch8192 8 colo
echo "$(date "+%H:%M:%S.%N") - 작업 id25_cifar10_resnet44_sync_batch8192 시작" > ${SAVEPATH}/id25_cifar10_resnet44_sync_batch8192_job_start.txt
kubectl apply -f ${TFPATH}/net_script/id25_cifar10_resnet44_sync_batch8192_colo.yaml
wait_for_pod_scheduling id25_cifar10_resnet44_sync_batch8192 8


# 작업: id26_squad_bert_sync_batch32 (모델: bert, 워커: 8, 도착시간: 3544초)
wait_for_resources_or_arrival 3544 id26_squad_bert_sync_batch32 8 colo
echo "$(date "+%H:%M:%S.%N") - 작업 id26_squad_bert_sync_batch32 시작" > ${SAVEPATH}/id26_squad_bert_sync_batch32_job_start.txt
kubectl apply -f ${TFPATH}/net_script/id26_squad_bert_sync_batch32_colo.yaml
wait_for_pod_scheduling id26_squad_bert_sync_batch32 8


# 작업: id27_imagenet_vgg16_sync_batch1024 (모델: vgg16, 워커: 8, 도착시간: 3803초)
wait_for_resources_or_arrival 3803 id27_imagenet_vgg16_sync_batch1024 8 colo
echo "$(date "+%H:%M:%S.%N") - 작업 id27_imagenet_vgg16_sync_batch1024 시작" > ${SAVEPATH}/id27_imagenet_vgg16_sync_batch1024_job_start.txt
kubectl apply -f ${TFPATH}/net_script/id27_imagenet_vgg16_sync_batch1024_colo.yaml
wait_for_pod_scheduling id27_imagenet_vgg16_sync_batch1024 8


# 작업: id28_squad_gpt2_sync_batch32 (모델: gpt2, 워커: 8, 도착시간: 4087초)
wait_for_resources_or_arrival 4087 id28_squad_gpt2_sync_batch32 8 colo
echo "$(date "+%H:%M:%S.%N") - 작업 id28_squad_gpt2_sync_batch32 시작" > ${SAVEPATH}/id28_squad_gpt2_sync_batch32_job_start.txt
kubectl apply -f ${TFPATH}/net_script/id28_squad_gpt2_sync_batch32_colo.yaml
wait_for_pod_scheduling id28_squad_gpt2_sync_batch32 8


# 작업: id29_cifar10_resnet44_sync_batch8192 (모델: resnet44, 워커: 8, 도착시간: 4088초)
wait_for_resources_or_arrival 4088 id29_cifar10_resnet44_sync_batch8192 8 colo
echo "$(date "+%H:%M:%S.%N") - 작업 id29_cifar10_resnet44_sync_batch8192 시작" > ${SAVEPATH}/id29_cifar10_resnet44_sync_batch8192_job_start.txt
kubectl apply -f ${TFPATH}/net_script/id29_cifar10_resnet44_sync_batch8192_colo.yaml
wait_for_pod_scheduling id29_cifar10_resnet44_sync_batch8192 8


ENDTIME=`date "+%H:%M:%S.%N"`
echo "$ENDTIME" > ${SAVEPATH}/end_makespan.txt
ENDLOGTIME=$(($(date +%s%N)/1000000000))
LOGTIME=$(($ENDLOGTIME - $STARTLOGTIME))
kubectl logs -n kube-system kube-scheduler-xsailor-master  > ${SAVEPATH}/scheduler_full_log.txt

kubectl logs -n kube-system tensorspot-scheduler > ${SAVEPATH}/scheduler_log.txt

# gcloud compute ssh --zone us-central1-a xsailor-master --command "sudo sh /home/jhlee21/gpu_off.sh"

# gcloud compute ssh --zone us-central1-a xsailor-worker1 --command "sudo sh /home/jhlee21/gpu_off.sh"
