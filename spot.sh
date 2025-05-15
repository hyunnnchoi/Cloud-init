
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

# 작업: id0_imagenet_googlenet_sync_batch512 (모델: googlenet, 워커: 2, 도착시간: 0초)
wait_for_resources_or_arrival 0 id0_imagenet_googlenet_sync_batch512 2 spot
echo "$(date "+%H:%M:%S.%N") - 작업 id0_imagenet_googlenet_sync_batch512 시작" > ${SAVEPATH}/id0_imagenet_googlenet_sync_batch512_job_start.txt
kubectl apply -f ${TFPATH}/net_script/id0_imagenet_googlenet_sync_batch512_spot.yaml
wait_for_pod_scheduling id0_imagenet_googlenet_sync_batch512 2


# 작업: id1_squad_gpt2_sync_batch32 (모델: gpt2, 워커: 8, 도착시간: 51초)
wait_for_resources_or_arrival 51 id1_squad_gpt2_sync_batch32 8 spot
echo "$(date "+%H:%M:%S.%N") - 작업 id1_squad_gpt2_sync_batch32 시작" > ${SAVEPATH}/id1_squad_gpt2_sync_batch32_job_start.txt
kubectl apply -f ${TFPATH}/net_script/id1_squad_gpt2_sync_batch32_spot.yaml
wait_for_pod_scheduling id1_squad_gpt2_sync_batch32 8


# 작업: id2_cifar10_resnet44_sync_batch2048 (모델: resnet44, 워커: 2, 도착시간: 1068초)
wait_for_resources_or_arrival 1068 id2_cifar10_resnet44_sync_batch2048 2 spot
echo "$(date "+%H:%M:%S.%N") - 작업 id2_cifar10_resnet44_sync_batch2048 시작" > ${SAVEPATH}/id2_cifar10_resnet44_sync_batch2048_job_start.txt
kubectl apply -f ${TFPATH}/net_script/id2_cifar10_resnet44_sync_batch2048_spot.yaml
wait_for_pod_scheduling id2_cifar10_resnet44_sync_batch2048 2


# 작업: id3_imagenet_inception3_sync_batch128 (모델: inception3, 워커: 2, 도착시간: 1356초)
wait_for_resources_or_arrival 1356 id3_imagenet_inception3_sync_batch128 2 spot
echo "$(date "+%H:%M:%S.%N") - 작업 id3_imagenet_inception3_sync_batch128 시작" > ${SAVEPATH}/id3_imagenet_inception3_sync_batch128_job_start.txt
kubectl apply -f ${TFPATH}/net_script/id3_imagenet_inception3_sync_batch128_spot.yaml
wait_for_pod_scheduling id3_imagenet_inception3_sync_batch128 2


# 작업: id4_squad_gpt2_sync_batch16 (모델: gpt2, 워커: 4, 도착시간: 2360초)
wait_for_resources_or_arrival 2360 id4_squad_gpt2_sync_batch16 4 spot
echo "$(date "+%H:%M:%S.%N") - 작업 id4_squad_gpt2_sync_batch16 시작" > ${SAVEPATH}/id4_squad_gpt2_sync_batch16_job_start.txt
kubectl apply -f ${TFPATH}/net_script/id4_squad_gpt2_sync_batch16_spot.yaml
wait_for_pod_scheduling id4_squad_gpt2_sync_batch16 4


# 작업: id5_imagenet_inception3_sync_batch128 (모델: inception3, 워커: 2, 도착시간: 2809초)
wait_for_resources_or_arrival 2809 id5_imagenet_inception3_sync_batch128 2 spot
echo "$(date "+%H:%M:%S.%N") - 작업 id5_imagenet_inception3_sync_batch128 시작" > ${SAVEPATH}/id5_imagenet_inception3_sync_batch128_job_start.txt
kubectl apply -f ${TFPATH}/net_script/id5_imagenet_inception3_sync_batch128_spot.yaml
wait_for_pod_scheduling id5_imagenet_inception3_sync_batch128 2


# 작업: id6_cifar10_resnet110_sync_batch2048 (모델: resnet110, 워커: 2, 도착시간: 3206초)
wait_for_resources_or_arrival 3206 id6_cifar10_resnet110_sync_batch2048 2 spot
echo "$(date "+%H:%M:%S.%N") - 작업 id6_cifar10_resnet110_sync_batch2048 시작" > ${SAVEPATH}/id6_cifar10_resnet110_sync_batch2048_job_start.txt
kubectl apply -f ${TFPATH}/net_script/id6_cifar10_resnet110_sync_batch2048_spot.yaml
wait_for_pod_scheduling id6_cifar10_resnet110_sync_batch2048 2


# 작업: id7_cifar10_resnet44_sync_batch2048 (모델: resnet44, 워커: 2, 도착시간: 3575초)
wait_for_resources_or_arrival 3575 id7_cifar10_resnet44_sync_batch2048 2 spot
echo "$(date "+%H:%M:%S.%N") - 작업 id7_cifar10_resnet44_sync_batch2048 시작" > ${SAVEPATH}/id7_cifar10_resnet44_sync_batch2048_job_start.txt
kubectl apply -f ${TFPATH}/net_script/id7_cifar10_resnet44_sync_batch2048_spot.yaml
wait_for_pod_scheduling id7_cifar10_resnet44_sync_batch2048 2


# 작업: id8_imagenet_inception3_sync_batch256 (모델: inception3, 워커: 4, 도착시간: 4904초)
wait_for_resources_or_arrival 4904 id8_imagenet_inception3_sync_batch256 4 spot
echo "$(date "+%H:%M:%S.%N") - 작업 id8_imagenet_inception3_sync_batch256 시작" > ${SAVEPATH}/id8_imagenet_inception3_sync_batch256_job_start.txt
kubectl apply -f ${TFPATH}/net_script/id8_imagenet_inception3_sync_batch256_spot.yaml
wait_for_pod_scheduling id8_imagenet_inception3_sync_batch256 4


# 작업: id9_imagenet_inception3_sync_batch256 (모델: inception3, 워커: 4, 도착시간: 4982초)
wait_for_resources_or_arrival 4982 id9_imagenet_inception3_sync_batch256 4 spot
echo "$(date "+%H:%M:%S.%N") - 작업 id9_imagenet_inception3_sync_batch256 시작" > ${SAVEPATH}/id9_imagenet_inception3_sync_batch256_job_start.txt
kubectl apply -f ${TFPATH}/net_script/id9_imagenet_inception3_sync_batch256_spot.yaml
wait_for_pod_scheduling id9_imagenet_inception3_sync_batch256 4


# 작업: id10_cifar10_resnet110_sync_batch8192 (모델: resnet110, 워커: 8, 도착시간: 5262초)
wait_for_resources_or_arrival 5262 id10_cifar10_resnet110_sync_batch8192 8 spot
echo "$(date "+%H:%M:%S.%N") - 작업 id10_cifar10_resnet110_sync_batch8192 시작" > ${SAVEPATH}/id10_cifar10_resnet110_sync_batch8192_job_start.txt
kubectl apply -f ${TFPATH}/net_script/id10_cifar10_resnet110_sync_batch8192_spot.yaml
wait_for_pod_scheduling id10_cifar10_resnet110_sync_batch8192 8


# 작업: id11_imagenet_googlenet_sync_batch1024 (모델: googlenet, 워커: 4, 도착시간: 6799초)
wait_for_resources_or_arrival 6799 id11_imagenet_googlenet_sync_batch1024 4 spot
echo "$(date "+%H:%M:%S.%N") - 작업 id11_imagenet_googlenet_sync_batch1024 시작" > ${SAVEPATH}/id11_imagenet_googlenet_sync_batch1024_job_start.txt
kubectl apply -f ${TFPATH}/net_script/id11_imagenet_googlenet_sync_batch1024_spot.yaml
wait_for_pod_scheduling id11_imagenet_googlenet_sync_batch1024 4


# 작업: id12_imagenet_inception3_sync_batch512 (모델: inception3, 워커: 8, 도착시간: 7765초)
wait_for_resources_or_arrival 7765 id12_imagenet_inception3_sync_batch512 8 spot
echo "$(date "+%H:%M:%S.%N") - 작업 id12_imagenet_inception3_sync_batch512 시작" > ${SAVEPATH}/id12_imagenet_inception3_sync_batch512_job_start.txt
kubectl apply -f ${TFPATH}/net_script/id12_imagenet_inception3_sync_batch512_spot.yaml
wait_for_pod_scheduling id12_imagenet_inception3_sync_batch512 8


# 작업: id13_cifar10_resnet44_sync_batch4096 (모델: resnet44, 워커: 4, 도착시간: 7817초)
wait_for_resources_or_arrival 7817 id13_cifar10_resnet44_sync_batch4096 4 spot
echo "$(date "+%H:%M:%S.%N") - 작업 id13_cifar10_resnet44_sync_batch4096 시작" > ${SAVEPATH}/id13_cifar10_resnet44_sync_batch4096_job_start.txt
kubectl apply -f ${TFPATH}/net_script/id13_cifar10_resnet44_sync_batch4096_spot.yaml
wait_for_pod_scheduling id13_cifar10_resnet44_sync_batch4096 4


# 작업: id14_cifar10_densenet100_k12_sync_batch1024 (모델: densenet100_k12, 워커: 8, 도착시간: 8594초)
wait_for_resources_or_arrival 8594 id14_cifar10_densenet100_k12_sync_batch1024 8 spot
echo "$(date "+%H:%M:%S.%N") - 작업 id14_cifar10_densenet100_k12_sync_batch1024 시작" > ${SAVEPATH}/id14_cifar10_densenet100_k12_sync_batch1024_job_start.txt
kubectl apply -f ${TFPATH}/net_script/id14_cifar10_densenet100_k12_sync_batch1024_spot.yaml
wait_for_pod_scheduling id14_cifar10_densenet100_k12_sync_batch1024 8


# 작업: id15_imagenet_googlenet_sync_batch1024 (모델: googlenet, 워커: 4, 도착시간: 8739초)
wait_for_resources_or_arrival 8739 id15_imagenet_googlenet_sync_batch1024 4 spot
echo "$(date "+%H:%M:%S.%N") - 작업 id15_imagenet_googlenet_sync_batch1024 시작" > ${SAVEPATH}/id15_imagenet_googlenet_sync_batch1024_job_start.txt
kubectl apply -f ${TFPATH}/net_script/id15_imagenet_googlenet_sync_batch1024_spot.yaml
wait_for_pod_scheduling id15_imagenet_googlenet_sync_batch1024 4


# 작업: id16_cifar10_resnet110_sync_batch4096 (모델: resnet110, 워커: 4, 도착시간: 9215초)
wait_for_resources_or_arrival 9215 id16_cifar10_resnet110_sync_batch4096 4 spot
echo "$(date "+%H:%M:%S.%N") - 작업 id16_cifar10_resnet110_sync_batch4096 시작" > ${SAVEPATH}/id16_cifar10_resnet110_sync_batch4096_job_start.txt
kubectl apply -f ${TFPATH}/net_script/id16_cifar10_resnet110_sync_batch4096_spot.yaml
wait_for_pod_scheduling id16_cifar10_resnet110_sync_batch4096 4


# 작업: id17_squad_gpt2_sync_batch16 (모델: gpt2, 워커: 4, 도착시간: 10271초)
wait_for_resources_or_arrival 10271 id17_squad_gpt2_sync_batch16 4 spot
echo "$(date "+%H:%M:%S.%N") - 작업 id17_squad_gpt2_sync_batch16 시작" > ${SAVEPATH}/id17_squad_gpt2_sync_batch16_job_start.txt
kubectl apply -f ${TFPATH}/net_script/id17_squad_gpt2_sync_batch16_spot.yaml
wait_for_pod_scheduling id17_squad_gpt2_sync_batch16 4


# 작업: id18_cifar10_resnet110_sync_batch8192 (모델: resnet110, 워커: 8, 도착시간: 11163초)
wait_for_resources_or_arrival 11163 id18_cifar10_resnet110_sync_batch8192 8 spot
echo "$(date "+%H:%M:%S.%N") - 작업 id18_cifar10_resnet110_sync_batch8192 시작" > ${SAVEPATH}/id18_cifar10_resnet110_sync_batch8192_job_start.txt
kubectl apply -f ${TFPATH}/net_script/id18_cifar10_resnet110_sync_batch8192_spot.yaml
wait_for_pod_scheduling id18_cifar10_resnet110_sync_batch8192 8


# 작업: id19_imagenet_inception3_sync_batch256 (모델: inception3, 워커: 4, 도착시간: 13016초)
wait_for_resources_or_arrival 13016 id19_imagenet_inception3_sync_batch256 4 spot
echo "$(date "+%H:%M:%S.%N") - 작업 id19_imagenet_inception3_sync_batch256 시작" > ${SAVEPATH}/id19_imagenet_inception3_sync_batch256_job_start.txt
kubectl apply -f ${TFPATH}/net_script/id19_imagenet_inception3_sync_batch256_spot.yaml
wait_for_pod_scheduling id19_imagenet_inception3_sync_batch256 4


# 작업: id20_imagenet_inception3_sync_batch512 (모델: inception3, 워커: 8, 도착시간: 14996초)
wait_for_resources_or_arrival 14996 id20_imagenet_inception3_sync_batch512 8 spot
echo "$(date "+%H:%M:%S.%N") - 작업 id20_imagenet_inception3_sync_batch512 시작" > ${SAVEPATH}/id20_imagenet_inception3_sync_batch512_job_start.txt
kubectl apply -f ${TFPATH}/net_script/id20_imagenet_inception3_sync_batch512_spot.yaml
wait_for_pod_scheduling id20_imagenet_inception3_sync_batch512 8


# 작업: id21_imagenet_inception3_sync_batch512 (모델: inception3, 워커: 8, 도착시간: 16155초)
wait_for_resources_or_arrival 16155 id21_imagenet_inception3_sync_batch512 8 spot
echo "$(date "+%H:%M:%S.%N") - 작업 id21_imagenet_inception3_sync_batch512 시작" > ${SAVEPATH}/id21_imagenet_inception3_sync_batch512_job_start.txt
kubectl apply -f ${TFPATH}/net_script/id21_imagenet_inception3_sync_batch512_spot.yaml
wait_for_pod_scheduling id21_imagenet_inception3_sync_batch512 8


# 작업: id22_cifar10_resnet110_sync_batch8192 (모델: resnet110, 워커: 8, 도착시간: 16308초)
wait_for_resources_or_arrival 16308 id22_cifar10_resnet110_sync_batch8192 8 spot
echo "$(date "+%H:%M:%S.%N") - 작업 id22_cifar10_resnet110_sync_batch8192 시작" > ${SAVEPATH}/id22_cifar10_resnet110_sync_batch8192_job_start.txt
kubectl apply -f ${TFPATH}/net_script/id22_cifar10_resnet110_sync_batch8192_spot.yaml
wait_for_pod_scheduling id22_cifar10_resnet110_sync_batch8192 8


# 작업: id23_imagenet_inception3_sync_batch512 (모델: inception3, 워커: 8, 도착시간: 16810초)
wait_for_resources_or_arrival 16810 id23_imagenet_inception3_sync_batch512 8 spot
echo "$(date "+%H:%M:%S.%N") - 작업 id23_imagenet_inception3_sync_batch512 시작" > ${SAVEPATH}/id23_imagenet_inception3_sync_batch512_job_start.txt
kubectl apply -f ${TFPATH}/net_script/id23_imagenet_inception3_sync_batch512_spot.yaml
wait_for_pod_scheduling id23_imagenet_inception3_sync_batch512 8


# 작업: id24_squad_gpt2_sync_batch32 (모델: gpt2, 워커: 8, 도착시간: 18612초)
wait_for_resources_or_arrival 18612 id24_squad_gpt2_sync_batch32 8 spot
echo "$(date "+%H:%M:%S.%N") - 작업 id24_squad_gpt2_sync_batch32 시작" > ${SAVEPATH}/id24_squad_gpt2_sync_batch32_job_start.txt
kubectl apply -f ${TFPATH}/net_script/id24_squad_gpt2_sync_batch32_spot.yaml
wait_for_pod_scheduling id24_squad_gpt2_sync_batch32 8


# 작업: id25_squad_gpt2_sync_batch32 (모델: gpt2, 워커: 8, 도착시간: 18733초)
wait_for_resources_or_arrival 18733 id25_squad_gpt2_sync_batch32 8 spot
echo "$(date "+%H:%M:%S.%N") - 작업 id25_squad_gpt2_sync_batch32 시작" > ${SAVEPATH}/id25_squad_gpt2_sync_batch32_job_start.txt
kubectl apply -f ${TFPATH}/net_script/id25_squad_gpt2_sync_batch32_spot.yaml
wait_for_pod_scheduling id25_squad_gpt2_sync_batch32 8


# 작업: id26_squad_bert_sync_batch32 (모델: bert, 워커: 8, 도착시간: 21863초)
wait_for_resources_or_arrival 21863 id26_squad_bert_sync_batch32 8 spot
echo "$(date "+%H:%M:%S.%N") - 작업 id26_squad_bert_sync_batch32 시작" > ${SAVEPATH}/id26_squad_bert_sync_batch32_job_start.txt
kubectl apply -f ${TFPATH}/net_script/id26_squad_bert_sync_batch32_spot.yaml
wait_for_pod_scheduling id26_squad_bert_sync_batch32 8


# 작업: id27_cifar10_densenet100_k12_sync_batch1024 (모델: densenet100_k12, 워커: 8, 도착시간: 22124초)
wait_for_resources_or_arrival 22124 id27_cifar10_densenet100_k12_sync_batch1024 8 spot
echo "$(date "+%H:%M:%S.%N") - 작업 id27_cifar10_densenet100_k12_sync_batch1024 시작" > ${SAVEPATH}/id27_cifar10_densenet100_k12_sync_batch1024_job_start.txt
kubectl apply -f ${TFPATH}/net_script/id27_cifar10_densenet100_k12_sync_batch1024_spot.yaml
wait_for_pod_scheduling id27_cifar10_densenet100_k12_sync_batch1024 8


# 작업: id28_squad_gpt2_sync_batch32 (모델: gpt2, 워커: 8, 도착시간: 22454초)
wait_for_resources_or_arrival 22454 id28_squad_gpt2_sync_batch32 8 spot
echo "$(date "+%H:%M:%S.%N") - 작업 id28_squad_gpt2_sync_batch32 시작" > ${SAVEPATH}/id28_squad_gpt2_sync_batch32_job_start.txt
kubectl apply -f ${TFPATH}/net_script/id28_squad_gpt2_sync_batch32_spot.yaml
wait_for_pod_scheduling id28_squad_gpt2_sync_batch32 8


# 작업: id29_cifar10_resnet44_sync_batch8192 (모델: resnet44, 워커: 8, 도착시간: 24277초)
wait_for_resources_or_arrival 24277 id29_cifar10_resnet44_sync_batch8192 8 spot
echo "$(date "+%H:%M:%S.%N") - 작업 id29_cifar10_resnet44_sync_batch8192 시작" > ${SAVEPATH}/id29_cifar10_resnet44_sync_batch8192_job_start.txt
kubectl apply -f ${TFPATH}/net_script/id29_cifar10_resnet44_sync_batch8192_spot.yaml
wait_for_pod_scheduling id29_cifar10_resnet44_sync_batch8192 8


ENDTIME=`date "+%H:%M:%S.%N"`
echo "$ENDTIME" > ${SAVEPATH}/end_makespan.txt
ENDLOGTIME=$(($(date +%s%N)/1000000000))
LOGTIME=$(($ENDLOGTIME - $STARTLOGTIME))
kubectl logs -n kube-system kube-scheduler-xsailor-master  > ${SAVEPATH}/scheduler_full_log.txt

kubectl logs -n kube-system tensorspot-scheduler > ${SAVEPATH}/scheduler_log.txt

# gcloud compute ssh --zone us-central1-a xsailor-master --command "sudo sh /home/jhlee21/gpu_off.sh"

# gcloud compute ssh --zone us-central1-a xsailor-worker1 --command "sudo sh /home/jhlee21/gpu_off.sh"
