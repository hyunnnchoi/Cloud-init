
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

# 자원과 arrival_time을 고려하여 대기하는 함수 - 컨트롤러 Completed 상태 확인 로직 추가
wait_for_resources_or_arrival() {
    ARRIVAL_TIME=$1
    JOB_NAME=$2
    WORKER_NUM=$3

    echo "Checking resources for job ${JOB_NAME} (arrival time: ${ARRIVAL_TIME}s)"

    while true; do
        RUNNING_GPU_PODS=$(kubectl get pod -o wide | grep Running | grep -e "worker-" -e "chief-" | wc -l)
        
        # 현재 가용 GPU 계산
        AVAILABLE_GPUS=$((16 - RUNNING_GPU_PODS))
        
        # 디버그 정보 출력
        echo "DEBUG: Available GPUs=${AVAILABLE_GPUS}, Required GPUs=${WORKER_NUM}"
        
        # 자원이 충분한 경우 즉시 작업 시작
        if [ $AVAILABLE_GPUS -ge $WORKER_NUM ]; then
            echo "Resources available for job ${JOB_NAME}. Starting immediately."
            return 0
        fi

        # arrival time 체크
        CURRENT_EPOCH=$(date +%s)
        TIME_PASSED=$((CURRENT_EPOCH - STARTEPOCH))

        # arrival time이 도래한 경우 즉시 작업 시작 (자원이 부족해도)
        if [ $TIME_PASSED -ge $ARRIVAL_TIME ]; then
            echo "Arrival time reached for job ${JOB_NAME}. Starting regardless of resource availability."
            return 0
        fi

        # 완료된 작업 확인 및 정리 - controller/chief가 Completed 상태인 경우 작업 완료로 간주
        COMPLETED_CONTROLLERS=$(kubectl get pod -o wide | grep -e "controller-" -e "chief-" | grep Completed | awk '{print $1}')

        if [ -n "${COMPLETED_CONTROLLERS}" ]; then
            for completed_pod in ${COMPLETED_CONTROLLERS}; do
                # 작업 이름 추출 (예: id1_cifar10_alexnet_sync_batch32768)
                COMPLETED_JOB=$(echo ${completed_pod} | awk -F '-' '{
                    jobname = $1
                    for (i = 2; i <= NF - 2; i++) {
                        jobname = jobname "_" $i
                    }
                    print jobname
                }')

                # 작업 포드 이름 추출 (예: id1-cifar10-alexnet-sync-batch32768)
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
                kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
            done
        fi

        # 남은 시간 계산 및 표시
        TIME_REMAINING=$((ARRIVAL_TIME - TIME_PASSED))
        if [ $TIME_REMAINING -gt 0 ]; then
            echo "Waiting for resources or arrival time for job ${JOB_NAME} (Remaining: ${TIME_REMAINING}s)"
        else
            echo "Arrival time already passed, waiting for resources to become available"
        fi

        sleep 0.1s
    done
}


# 첫 번째 작업 처리
MODEL="id0_squad_gpt2l_sync_batch8"
ARRIVAL_TIME=0
WORKER_NUM=2
CURRENT_EPOCH=`date +%s`
TIME_DIFF=$((ARRIVAL_TIME - (CURRENT_EPOCH - STARTEPOCH)))

# arrival_time까지 대기
if [ $TIME_DIFF -gt 0 ]; then
    echo "Waiting for arrival time of $MODEL: $TIME_DIFF seconds"
    sleep $TIME_DIFF
fi

mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 첫 번째 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" $WORKER_NUM


# 작업 1: id1_cifar10_alexnet_sync_batch32768 처리
echo "Preparing job 1: id1_cifar10_alexnet_sync_batch32768 (Workers: 8, Arrival: 2811)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 2811 "id1_cifar10_alexnet_sync_batch32768" 8

MODEL="id1_cifar10_alexnet_sync_batch32768"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 8


# 작업 2: id2_squad_bert_sync_batch8 처리
echo "Preparing job 2: id2_squad_bert_sync_batch8 (Workers: 2, Arrival: 6262)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 6262 "id2_squad_bert_sync_batch8" 2

MODEL="id2_squad_bert_sync_batch8"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 2


# 작업 3: id3_cifar10_resnet110_sync_batch2048 처리
echo "Preparing job 3: id3_cifar10_resnet110_sync_batch2048 (Workers: 2, Arrival: 12213)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 12213 "id3_cifar10_resnet110_sync_batch2048" 2

MODEL="id3_cifar10_resnet110_sync_batch2048"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 2


# 작업 4: id4_squad_gpt2xl_sync_batch8 처리
echo "Preparing job 4: id4_squad_gpt2xl_sync_batch8 (Workers: 2, Arrival: 12394)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 12394 "id4_squad_gpt2xl_sync_batch8" 2

MODEL="id4_squad_gpt2xl_sync_batch8"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 2


# 작업 5: id5_squad_gpt2xl_sync_batch32 처리
echo "Preparing job 5: id5_squad_gpt2xl_sync_batch32 (Workers: 8, Arrival: 33588)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 33588 "id5_squad_gpt2xl_sync_batch32" 8

MODEL="id5_squad_gpt2xl_sync_batch32"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 8


# 작업 6: id6_imagenet_vgg16_sync_batch256 처리
echo "Preparing job 6: id6_imagenet_vgg16_sync_batch256 (Workers: 2, Arrival: 36169)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 36169 "id6_imagenet_vgg16_sync_batch256" 2

MODEL="id6_imagenet_vgg16_sync_batch256"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 2


# 작업 7: id7_imagenet_vgg16_sync_batch512 처리
echo "Preparing job 7: id7_imagenet_vgg16_sync_batch512 (Workers: 4, Arrival: 37502)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 37502 "id7_imagenet_vgg16_sync_batch512" 4

MODEL="id7_imagenet_vgg16_sync_batch512"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 4


# 작업 8: id8_cifar10_alexnet_sync_batch8192 처리
echo "Preparing job 8: id8_cifar10_alexnet_sync_batch8192 (Workers: 2, Arrival: 46244)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 46244 "id8_cifar10_alexnet_sync_batch8192" 2

MODEL="id8_cifar10_alexnet_sync_batch8192"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 2


# 작업 9: id9_cifar10_densenet100_k12_sync_batch256 처리
echo "Preparing job 9: id9_cifar10_densenet100_k12_sync_batch256 (Workers: 2, Arrival: 51844)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 51844 "id9_cifar10_densenet100_k12_sync_batch256" 2

MODEL="id9_cifar10_densenet100_k12_sync_batch256"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 2


# 작업 10: id10_squad_bert_sync_batch32 처리
echo "Preparing job 10: id10_squad_bert_sync_batch32 (Workers: 8, Arrival: 64283)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 64283 "id10_squad_bert_sync_batch32" 8

MODEL="id10_squad_bert_sync_batch32"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 8


# 작업 11: id11_squad_gpt2l_sync_batch8 처리
echo "Preparing job 11: id11_squad_gpt2l_sync_batch8 (Workers: 2, Arrival: 65915)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 65915 "id11_squad_gpt2l_sync_batch8" 2

MODEL="id11_squad_gpt2l_sync_batch8"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 2


# 작업 12: id12_imagenet_vgg16_sync_batch256 처리
echo "Preparing job 12: id12_imagenet_vgg16_sync_batch256 (Workers: 2, Arrival: 69187)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 69187 "id12_imagenet_vgg16_sync_batch256" 2

MODEL="id12_imagenet_vgg16_sync_batch256"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 2


# 작업 13: id13_squad_gpt2xl_sync_batch32 처리
echo "Preparing job 13: id13_squad_gpt2xl_sync_batch32 (Workers: 8, Arrival: 72641)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 72641 "id13_squad_gpt2xl_sync_batch32" 8

MODEL="id13_squad_gpt2xl_sync_batch32"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 8


# 작업 14: id14_imagenet_vgg16_sync_batch512 처리
echo "Preparing job 14: id14_imagenet_vgg16_sync_batch512 (Workers: 4, Arrival: 88616)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 88616 "id14_imagenet_vgg16_sync_batch512" 4

MODEL="id14_imagenet_vgg16_sync_batch512"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 4


# 작업 15: id15_squad_bert_sync_batch16 처리
echo "Preparing job 15: id15_squad_bert_sync_batch16 (Workers: 4, Arrival: 88934)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 88934 "id15_squad_bert_sync_batch16" 4

MODEL="id15_squad_bert_sync_batch16"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 4


# 작업 16: id16_squad_gpt2l_sync_batch16 처리
echo "Preparing job 16: id16_squad_gpt2l_sync_batch16 (Workers: 4, Arrival: 90418)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 90418 "id16_squad_gpt2l_sync_batch16" 4

MODEL="id16_squad_gpt2l_sync_batch16"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 4


# 작업 17: id17_cifar10_alexnet_sync_batch8192 처리
echo "Preparing job 17: id17_cifar10_alexnet_sync_batch8192 (Workers: 2, Arrival: 91279)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 91279 "id17_cifar10_alexnet_sync_batch8192" 2

MODEL="id17_cifar10_alexnet_sync_batch8192"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 2


# 작업 18: id18_imagenet_resnet50_sync_batch512 처리
echo "Preparing job 18: id18_imagenet_resnet50_sync_batch512 (Workers: 4, Arrival: 92550)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 92550 "id18_imagenet_resnet50_sync_batch512" 4

MODEL="id18_imagenet_resnet50_sync_batch512"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 4


# 작업 19: id19_squad_bertl_sync_batch8 처리
echo "Preparing job 19: id19_squad_bertl_sync_batch8 (Workers: 2, Arrival: 95251)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 95251 "id19_squad_bertl_sync_batch8" 2

MODEL="id19_squad_bertl_sync_batch8"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 2


# 작업 20: id20_squad_bert_sync_batch16 처리
echo "Preparing job 20: id20_squad_bert_sync_batch16 (Workers: 4, Arrival: 97147)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 97147 "id20_squad_bert_sync_batch16" 4

MODEL="id20_squad_bert_sync_batch16"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 4


# 작업 21: id21_cifar10_densenet100_k12_sync_batch256 처리
echo "Preparing job 21: id21_cifar10_densenet100_k12_sync_batch256 (Workers: 2, Arrival: 99188)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 99188 "id21_cifar10_densenet100_k12_sync_batch256" 2

MODEL="id21_cifar10_densenet100_k12_sync_batch256"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 2


# 작업 22: id22_squad_gpt2_sync_batch8 처리
echo "Preparing job 22: id22_squad_gpt2_sync_batch8 (Workers: 2, Arrival: 106748)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 106748 "id22_squad_gpt2_sync_batch8" 2

MODEL="id22_squad_gpt2_sync_batch8"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 2


# 작업 23: id23_squad_gpt2_sync_batch16 처리
echo "Preparing job 23: id23_squad_gpt2_sync_batch16 (Workers: 4, Arrival: 117562)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 117562 "id23_squad_gpt2_sync_batch16" 4

MODEL="id23_squad_gpt2_sync_batch16"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 4


# 작업 24: id24_squad_bertl_sync_batch8 처리
echo "Preparing job 24: id24_squad_bertl_sync_batch8 (Workers: 2, Arrival: 117859)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 117859 "id24_squad_bertl_sync_batch8" 2

MODEL="id24_squad_bertl_sync_batch8"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 2


# 작업 25: id25_imagenet_vgg16_sync_batch1024 처리
echo "Preparing job 25: id25_imagenet_vgg16_sync_batch1024 (Workers: 8, Arrival: 118812)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 118812 "id25_imagenet_vgg16_sync_batch1024" 8

MODEL="id25_imagenet_vgg16_sync_batch1024"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 8


# 작업 26: id26_cifar10_resnet110_sync_batch4096 처리
echo "Preparing job 26: id26_cifar10_resnet110_sync_batch4096 (Workers: 4, Arrival: 123334)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 123334 "id26_cifar10_resnet110_sync_batch4096" 4

MODEL="id26_cifar10_resnet110_sync_batch4096"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 4


# 작업 27: id27_cifar10_densenet100_k12_sync_batch1024 처리
echo "Preparing job 27: id27_cifar10_densenet100_k12_sync_batch1024 (Workers: 8, Arrival: 125140)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 125140 "id27_cifar10_densenet100_k12_sync_batch1024" 8

MODEL="id27_cifar10_densenet100_k12_sync_batch1024"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 8


# 작업 28: id28_squad_gpt2_sync_batch32 처리
echo "Preparing job 28: id28_squad_gpt2_sync_batch32 (Workers: 8, Arrival: 126333)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 126333 "id28_squad_gpt2_sync_batch32" 8

MODEL="id28_squad_gpt2_sync_batch32"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 8


# 작업 29: id29_imagenet_resnet50_sync_batch1024 처리
echo "Preparing job 29: id29_imagenet_resnet50_sync_batch1024 (Workers: 8, Arrival: 127756)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 127756 "id29_imagenet_resnet50_sync_batch1024" 8

MODEL="id29_imagenet_resnet50_sync_batch1024"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 8


# 작업 30: id30_squad_bert_sync_batch32 처리
echo "Preparing job 30: id30_squad_bert_sync_batch32 (Workers: 8, Arrival: 129339)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 129339 "id30_squad_bert_sync_batch32" 8

MODEL="id30_squad_bert_sync_batch32"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 8


# 작업 31: id31_cifar10_densenet100_k12_sync_batch256 처리
echo "Preparing job 31: id31_cifar10_densenet100_k12_sync_batch256 (Workers: 2, Arrival: 137017)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 137017 "id31_cifar10_densenet100_k12_sync_batch256" 2

MODEL="id31_cifar10_densenet100_k12_sync_batch256"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 2


# 작업 32: id32_squad_bertl_sync_batch16 처리
echo "Preparing job 32: id32_squad_bertl_sync_batch16 (Workers: 4, Arrival: 137615)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 137615 "id32_squad_bertl_sync_batch16" 4

MODEL="id32_squad_bertl_sync_batch16"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 4


# 작업 33: id33_cifar10_densenet100_k12_sync_batch256 처리
echo "Preparing job 33: id33_cifar10_densenet100_k12_sync_batch256 (Workers: 2, Arrival: 142633)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 142633 "id33_cifar10_densenet100_k12_sync_batch256" 2

MODEL="id33_cifar10_densenet100_k12_sync_batch256"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 2


# 작업 34: id34_cifar10_resnet110_sync_batch4096 처리
echo "Preparing job 34: id34_cifar10_resnet110_sync_batch4096 (Workers: 4, Arrival: 145905)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 145905 "id34_cifar10_resnet110_sync_batch4096" 4

MODEL="id34_cifar10_resnet110_sync_batch4096"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 4


# 작업 35: id35_squad_gpt2_sync_batch16 처리
echo "Preparing job 35: id35_squad_gpt2_sync_batch16 (Workers: 4, Arrival: 147335)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 147335 "id35_squad_gpt2_sync_batch16" 4

MODEL="id35_squad_gpt2_sync_batch16"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 4


# 작업 36: id36_imagenet_vgg16_sync_batch256 처리
echo "Preparing job 36: id36_imagenet_vgg16_sync_batch256 (Workers: 2, Arrival: 149549)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 149549 "id36_imagenet_vgg16_sync_batch256" 2

MODEL="id36_imagenet_vgg16_sync_batch256"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 2


# 작업 37: id37_squad_bert_sync_batch16 처리
echo "Preparing job 37: id37_squad_bert_sync_batch16 (Workers: 4, Arrival: 150752)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 150752 "id37_squad_bert_sync_batch16" 4

MODEL="id37_squad_bert_sync_batch16"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 4


# 작업 38: id38_cifar10_resnet110_sync_batch8192 처리
echo "Preparing job 38: id38_cifar10_resnet110_sync_batch8192 (Workers: 8, Arrival: 154597)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 154597 "id38_cifar10_resnet110_sync_batch8192" 8

MODEL="id38_cifar10_resnet110_sync_batch8192"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 8


# 작업 39: id39_cifar10_resnet110_sync_batch8192 처리
echo "Preparing job 39: id39_cifar10_resnet110_sync_batch8192 (Workers: 8, Arrival: 154943)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 154943 "id39_cifar10_resnet110_sync_batch8192" 8

MODEL="id39_cifar10_resnet110_sync_batch8192"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 8


# 작업 40: id40_squad_gpt2xl_sync_batch32 처리
echo "Preparing job 40: id40_squad_gpt2xl_sync_batch32 (Workers: 8, Arrival: 154964)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 154964 "id40_squad_gpt2xl_sync_batch32" 8

MODEL="id40_squad_gpt2xl_sync_batch32"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 8


# 작업 41: id41_imagenet_resnet50_sync_batch256 처리
echo "Preparing job 41: id41_imagenet_resnet50_sync_batch256 (Workers: 2, Arrival: 158984)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 158984 "id41_imagenet_resnet50_sync_batch256" 2

MODEL="id41_imagenet_resnet50_sync_batch256"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 2


# 작업 42: id42_imagenet_resnet50_sync_batch512 처리
echo "Preparing job 42: id42_imagenet_resnet50_sync_batch512 (Workers: 4, Arrival: 159862)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 159862 "id42_imagenet_resnet50_sync_batch512" 4

MODEL="id42_imagenet_resnet50_sync_batch512"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 4


# 작업 43: id43_imagenet_resnet50_sync_batch512 처리
echo "Preparing job 43: id43_imagenet_resnet50_sync_batch512 (Workers: 4, Arrival: 160161)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 160161 "id43_imagenet_resnet50_sync_batch512" 4

MODEL="id43_imagenet_resnet50_sync_batch512"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 4


# 작업 44: id44_cifar10_densenet100_k12_sync_batch1024 처리
echo "Preparing job 44: id44_cifar10_densenet100_k12_sync_batch1024 (Workers: 8, Arrival: 162217)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 162217 "id44_cifar10_densenet100_k12_sync_batch1024" 8

MODEL="id44_cifar10_densenet100_k12_sync_batch1024"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 8


# 작업 45: id45_squad_bertl_sync_batch32 처리
echo "Preparing job 45: id45_squad_bertl_sync_batch32 (Workers: 8, Arrival: 162429)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 162429 "id45_squad_bertl_sync_batch32" 8

MODEL="id45_squad_bertl_sync_batch32"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 8


# 작업 46: id46_imagenet_vgg16_sync_batch512 처리
echo "Preparing job 46: id46_imagenet_vgg16_sync_batch512 (Workers: 4, Arrival: 171281)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 171281 "id46_imagenet_vgg16_sync_batch512" 4

MODEL="id46_imagenet_vgg16_sync_batch512"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 4


# 작업 47: id47_squad_gpt2l_sync_batch32 처리
echo "Preparing job 47: id47_squad_gpt2l_sync_batch32 (Workers: 8, Arrival: 171395)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 171395 "id47_squad_gpt2l_sync_batch32" 8

MODEL="id47_squad_gpt2l_sync_batch32"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 8


# 작업 48: id48_squad_gpt2xl_sync_batch16 처리
echo "Preparing job 48: id48_squad_gpt2xl_sync_batch16 (Workers: 4, Arrival: 174911)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 174911 "id48_squad_gpt2xl_sync_batch16" 4

MODEL="id48_squad_gpt2xl_sync_batch16"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 4


# 작업 49: id49_cifar10_resnet110_sync_batch4096 처리
echo "Preparing job 49: id49_cifar10_resnet110_sync_batch4096 (Workers: 4, Arrival: 177258)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 177258 "id49_cifar10_resnet110_sync_batch4096" 4

MODEL="id49_cifar10_resnet110_sync_batch4096"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 4


# 작업 50: id50_squad_bertl_sync_batch32 처리
echo "Preparing job 50: id50_squad_bertl_sync_batch32 (Workers: 8, Arrival: 181791)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 181791 "id50_squad_bertl_sync_batch32" 8

MODEL="id50_squad_bertl_sync_batch32"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 8


# 작업 51: id51_squad_bert_sync_batch16 처리
echo "Preparing job 51: id51_squad_bert_sync_batch16 (Workers: 4, Arrival: 183408)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 183408 "id51_squad_bert_sync_batch16" 4

MODEL="id51_squad_bert_sync_batch16"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 4


# 작업 52: id52_cifar10_resnet110_sync_batch8192 처리
echo "Preparing job 52: id52_cifar10_resnet110_sync_batch8192 (Workers: 8, Arrival: 184093)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 184093 "id52_cifar10_resnet110_sync_batch8192" 8

MODEL="id52_cifar10_resnet110_sync_batch8192"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 8


# 작업 53: id53_cifar10_resnet110_sync_batch8192 처리
echo "Preparing job 53: id53_cifar10_resnet110_sync_batch8192 (Workers: 8, Arrival: 200392)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 200392 "id53_cifar10_resnet110_sync_batch8192" 8

MODEL="id53_cifar10_resnet110_sync_batch8192"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 8


# 작업 54: id54_squad_gpt2_sync_batch32 처리
echo "Preparing job 54: id54_squad_gpt2_sync_batch32 (Workers: 8, Arrival: 207817)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 207817 "id54_squad_gpt2_sync_batch32" 8

MODEL="id54_squad_gpt2_sync_batch32"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 8


# 작업 55: id55_cifar10_densenet100_k12_sync_batch1024 처리
echo "Preparing job 55: id55_cifar10_densenet100_k12_sync_batch1024 (Workers: 8, Arrival: 215823)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 215823 "id55_cifar10_densenet100_k12_sync_batch1024" 8

MODEL="id55_cifar10_densenet100_k12_sync_batch1024"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 8


# 작업 56: id56_cifar10_densenet100_k12_sync_batch512 처리
echo "Preparing job 56: id56_cifar10_densenet100_k12_sync_batch512 (Workers: 4, Arrival: 216994)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 216994 "id56_cifar10_densenet100_k12_sync_batch512" 4

MODEL="id56_cifar10_densenet100_k12_sync_batch512"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 4


# 작업 57: id57_squad_gpt2l_sync_batch32 처리
echo "Preparing job 57: id57_squad_gpt2l_sync_batch32 (Workers: 8, Arrival: 217156)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 217156 "id57_squad_gpt2l_sync_batch32" 8

MODEL="id57_squad_gpt2l_sync_batch32"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 8


# 작업 58: id58_squad_gpt2xl_sync_batch32 처리
echo "Preparing job 58: id58_squad_gpt2xl_sync_batch32 (Workers: 8, Arrival: 218625)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 218625 "id58_squad_gpt2xl_sync_batch32" 8

MODEL="id58_squad_gpt2xl_sync_batch32"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 8


# 작업 59: id59_squad_gpt2xl_sync_batch32 처리
echo "Preparing job 59: id59_squad_gpt2xl_sync_batch32 (Workers: 8, Arrival: 221757)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 221757 "id59_squad_gpt2xl_sync_batch32" 8

MODEL="id59_squad_gpt2xl_sync_batch32"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 8


# 작업 60: id60_squad_gpt2_sync_batch16 처리
echo "Preparing job 60: id60_squad_gpt2_sync_batch16 (Workers: 4, Arrival: 223365)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 223365 "id60_squad_gpt2_sync_batch16" 4

MODEL="id60_squad_gpt2_sync_batch16"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 4


# 작업 61: id61_cifar10_densenet100_k12_sync_batch1024 처리
echo "Preparing job 61: id61_cifar10_densenet100_k12_sync_batch1024 (Workers: 8, Arrival: 230519)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 230519 "id61_cifar10_densenet100_k12_sync_batch1024" 8

MODEL="id61_cifar10_densenet100_k12_sync_batch1024"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 8


# 작업 62: id62_cifar10_alexnet_sync_batch16384 처리
echo "Preparing job 62: id62_cifar10_alexnet_sync_batch16384 (Workers: 4, Arrival: 231807)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 231807 "id62_cifar10_alexnet_sync_batch16384" 4

MODEL="id62_cifar10_alexnet_sync_batch16384"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 4


# 작업 63: id63_cifar10_resnet110_sync_batch4096 처리
echo "Preparing job 63: id63_cifar10_resnet110_sync_batch4096 (Workers: 4, Arrival: 245468)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 245468 "id63_cifar10_resnet110_sync_batch4096" 4

MODEL="id63_cifar10_resnet110_sync_batch4096"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 4


# 작업 64: id64_squad_bert_sync_batch32 처리
echo "Preparing job 64: id64_squad_bert_sync_batch32 (Workers: 8, Arrival: 247953)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 247953 "id64_squad_bert_sync_batch32" 8

MODEL="id64_squad_bert_sync_batch32"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 8


# 작업 65: id65_cifar10_alexnet_sync_batch32768 처리
echo "Preparing job 65: id65_cifar10_alexnet_sync_batch32768 (Workers: 8, Arrival: 255457)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 255457 "id65_cifar10_alexnet_sync_batch32768" 8

MODEL="id65_cifar10_alexnet_sync_batch32768"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 8


# 작업 66: id66_imagenet_vgg16_sync_batch1024 처리
echo "Preparing job 66: id66_imagenet_vgg16_sync_batch1024 (Workers: 8, Arrival: 256335)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 256335 "id66_imagenet_vgg16_sync_batch1024" 8

MODEL="id66_imagenet_vgg16_sync_batch1024"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 8


# 작업 67: id67_squad_gpt2_sync_batch16 처리
echo "Preparing job 67: id67_squad_gpt2_sync_batch16 (Workers: 4, Arrival: 258490)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 258490 "id67_squad_gpt2_sync_batch16" 4

MODEL="id67_squad_gpt2_sync_batch16"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 4


# 작업 68: id68_squad_bert_sync_batch32 처리
echo "Preparing job 68: id68_squad_bert_sync_batch32 (Workers: 8, Arrival: 263379)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 263379 "id68_squad_bert_sync_batch32" 8

MODEL="id68_squad_bert_sync_batch32"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 8


# 작업 69: id69_squad_gpt2l_sync_batch32 처리
echo "Preparing job 69: id69_squad_gpt2l_sync_batch32 (Workers: 8, Arrival: 263985)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 263985 "id69_squad_gpt2l_sync_batch32" 8

MODEL="id69_squad_gpt2l_sync_batch32"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 8


# 작업 70: id70_cifar10_alexnet_sync_batch32768 처리
echo "Preparing job 70: id70_cifar10_alexnet_sync_batch32768 (Workers: 8, Arrival: 264564)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 264564 "id70_cifar10_alexnet_sync_batch32768" 8

MODEL="id70_cifar10_alexnet_sync_batch32768"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 8


# 작업 71: id71_squad_gpt2_sync_batch16 처리
echo "Preparing job 71: id71_squad_gpt2_sync_batch16 (Workers: 4, Arrival: 278760)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 278760 "id71_squad_gpt2_sync_batch16" 4

MODEL="id71_squad_gpt2_sync_batch16"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 4


# 작업 72: id72_imagenet_resnet50_sync_batch512 처리
echo "Preparing job 72: id72_imagenet_resnet50_sync_batch512 (Workers: 4, Arrival: 283858)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 283858 "id72_imagenet_resnet50_sync_batch512" 4

MODEL="id72_imagenet_resnet50_sync_batch512"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 4


# 작업 73: id73_squad_gpt2l_sync_batch32 처리
echo "Preparing job 73: id73_squad_gpt2l_sync_batch32 (Workers: 8, Arrival: 284029)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 284029 "id73_squad_gpt2l_sync_batch32" 8

MODEL="id73_squad_gpt2l_sync_batch32"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 8


# 작업 74: id74_imagenet_resnet50_sync_batch512 처리
echo "Preparing job 74: id74_imagenet_resnet50_sync_batch512 (Workers: 4, Arrival: 286098)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 286098 "id74_imagenet_resnet50_sync_batch512" 4

MODEL="id74_imagenet_resnet50_sync_batch512"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 4


# 작업 75: id75_imagenet_resnet50_sync_batch512 처리
echo "Preparing job 75: id75_imagenet_resnet50_sync_batch512 (Workers: 4, Arrival: 288409)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 288409 "id75_imagenet_resnet50_sync_batch512" 4

MODEL="id75_imagenet_resnet50_sync_batch512"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 4


# 작업 76: id76_squad_gpt2l_sync_batch32 처리
echo "Preparing job 76: id76_squad_gpt2l_sync_batch32 (Workers: 8, Arrival: 293950)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 293950 "id76_squad_gpt2l_sync_batch32" 8

MODEL="id76_squad_gpt2l_sync_batch32"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 8


# 작업 77: id77_squad_gpt2xl_sync_batch16 처리
echo "Preparing job 77: id77_squad_gpt2xl_sync_batch16 (Workers: 4, Arrival: 295124)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 295124 "id77_squad_gpt2xl_sync_batch16" 4

MODEL="id77_squad_gpt2xl_sync_batch16"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 4


# 작업 78: id78_cifar10_densenet100_k12_sync_batch1024 처리
echo "Preparing job 78: id78_cifar10_densenet100_k12_sync_batch1024 (Workers: 8, Arrival: 295953)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 295953 "id78_cifar10_densenet100_k12_sync_batch1024" 8

MODEL="id78_cifar10_densenet100_k12_sync_batch1024"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 8


# 작업 79: id79_squad_bert_sync_batch16 처리
echo "Preparing job 79: id79_squad_bert_sync_batch16 (Workers: 4, Arrival: 296296)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 296296 "id79_squad_bert_sync_batch16" 4

MODEL="id79_squad_bert_sync_batch16"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 4


# 작업 80: id80_squad_gpt2xl_sync_batch32 처리
echo "Preparing job 80: id80_squad_gpt2xl_sync_batch32 (Workers: 8, Arrival: 298569)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 298569 "id80_squad_gpt2xl_sync_batch32" 8

MODEL="id80_squad_gpt2xl_sync_batch32"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 8


# 작업 81: id81_imagenet_vgg16_sync_batch512 처리
echo "Preparing job 81: id81_imagenet_vgg16_sync_batch512 (Workers: 4, Arrival: 303312)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 303312 "id81_imagenet_vgg16_sync_batch512" 4

MODEL="id81_imagenet_vgg16_sync_batch512"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 4


# 작업 82: id82_cifar10_alexnet_sync_batch32768 처리
echo "Preparing job 82: id82_cifar10_alexnet_sync_batch32768 (Workers: 8, Arrival: 303556)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 303556 "id82_cifar10_alexnet_sync_batch32768" 8

MODEL="id82_cifar10_alexnet_sync_batch32768"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 8


# 작업 83: id83_squad_gpt2_sync_batch16 처리
echo "Preparing job 83: id83_squad_gpt2_sync_batch16 (Workers: 4, Arrival: 313589)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 313589 "id83_squad_gpt2_sync_batch16" 4

MODEL="id83_squad_gpt2_sync_batch16"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 4


# 작업 84: id84_cifar10_alexnet_sync_batch16384 처리
echo "Preparing job 84: id84_cifar10_alexnet_sync_batch16384 (Workers: 4, Arrival: 315964)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 315964 "id84_cifar10_alexnet_sync_batch16384" 4

MODEL="id84_cifar10_alexnet_sync_batch16384"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 4


# 작업 85: id85_squad_gpt2xl_sync_batch16 처리
echo "Preparing job 85: id85_squad_gpt2xl_sync_batch16 (Workers: 4, Arrival: 317079)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 317079 "id85_squad_gpt2xl_sync_batch16" 4

MODEL="id85_squad_gpt2xl_sync_batch16"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 4


# 작업 86: id86_cifar10_alexnet_sync_batch32768 처리
echo "Preparing job 86: id86_cifar10_alexnet_sync_batch32768 (Workers: 8, Arrival: 317480)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 317480 "id86_cifar10_alexnet_sync_batch32768" 8

MODEL="id86_cifar10_alexnet_sync_batch32768"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 8


# 작업 87: id87_cifar10_resnet110_sync_batch4096 처리
echo "Preparing job 87: id87_cifar10_resnet110_sync_batch4096 (Workers: 4, Arrival: 318301)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 318301 "id87_cifar10_resnet110_sync_batch4096" 4

MODEL="id87_cifar10_resnet110_sync_batch4096"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 4


# 작업 88: id88_squad_bertl_sync_batch32 처리
echo "Preparing job 88: id88_squad_bertl_sync_batch32 (Workers: 8, Arrival: 329391)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 329391 "id88_squad_bertl_sync_batch32" 8

MODEL="id88_squad_bertl_sync_batch32"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 8


# 작업 89: id89_imagenet_vgg16_sync_batch512 처리
echo "Preparing job 89: id89_imagenet_vgg16_sync_batch512 (Workers: 4, Arrival: 333526)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 333526 "id89_imagenet_vgg16_sync_batch512" 4

MODEL="id89_imagenet_vgg16_sync_batch512"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 4


# 작업 90: id90_squad_bertl_sync_batch32 처리
echo "Preparing job 90: id90_squad_bertl_sync_batch32 (Workers: 8, Arrival: 336482)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 336482 "id90_squad_bertl_sync_batch32" 8

MODEL="id90_squad_bertl_sync_batch32"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 8


# 작업 91: id91_squad_bertl_sync_batch16 처리
echo "Preparing job 91: id91_squad_bertl_sync_batch16 (Workers: 4, Arrival: 340835)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 340835 "id91_squad_bertl_sync_batch16" 4

MODEL="id91_squad_bertl_sync_batch16"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 4


# 작업 92: id92_imagenet_resnet50_sync_batch1024 처리
echo "Preparing job 92: id92_imagenet_resnet50_sync_batch1024 (Workers: 8, Arrival: 343161)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 343161 "id92_imagenet_resnet50_sync_batch1024" 8

MODEL="id92_imagenet_resnet50_sync_batch1024"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 8


# 작업 93: id93_squad_gpt2l_sync_batch32 처리
echo "Preparing job 93: id93_squad_gpt2l_sync_batch32 (Workers: 8, Arrival: 348486)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 348486 "id93_squad_gpt2l_sync_batch32" 8

MODEL="id93_squad_gpt2l_sync_batch32"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 8


# 작업 94: id94_squad_gpt2_sync_batch32 처리
echo "Preparing job 94: id94_squad_gpt2_sync_batch32 (Workers: 8, Arrival: 348684)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 348684 "id94_squad_gpt2_sync_batch32" 8

MODEL="id94_squad_gpt2_sync_batch32"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 8


# 작업 95: id95_cifar10_alexnet_sync_batch16384 처리
echo "Preparing job 95: id95_cifar10_alexnet_sync_batch16384 (Workers: 4, Arrival: 352079)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 352079 "id95_cifar10_alexnet_sync_batch16384" 4

MODEL="id95_cifar10_alexnet_sync_batch16384"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 4


# 작업 96: id96_squad_bertl_sync_batch16 처리
echo "Preparing job 96: id96_squad_bertl_sync_batch16 (Workers: 4, Arrival: 352781)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 352781 "id96_squad_bertl_sync_batch16" 4

MODEL="id96_squad_bertl_sync_batch16"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 4


# 작업 97: id97_imagenet_resnet50_sync_batch512 처리
echo "Preparing job 97: id97_imagenet_resnet50_sync_batch512 (Workers: 4, Arrival: 353302)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 353302 "id97_imagenet_resnet50_sync_batch512" 4

MODEL="id97_imagenet_resnet50_sync_batch512"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 4


# 작업 98: id98_squad_bertl_sync_batch16 처리
echo "Preparing job 98: id98_squad_bertl_sync_batch16 (Workers: 4, Arrival: 355003)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 355003 "id98_squad_bertl_sync_batch16" 4

MODEL="id98_squad_bertl_sync_batch16"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 4


# 작업 99: id99_squad_gpt2l_sync_batch32 처리
echo "Preparing job 99: id99_squad_gpt2l_sync_batch32 (Workers: 8, Arrival: 355394)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 355394 "id99_squad_gpt2l_sync_batch32" 8

MODEL="id99_squad_gpt2l_sync_batch32"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 8


# 모든 작업이 완료될 때까지 대기
RUNNING=`kubectl get pod -o wide | awk '{print $1}' | sed -n '1p'`
while [ -n "${RUNNING}" ]
do
  # Controller/Chief가 Completed 상태인 경우 작업 완료로 간주
  COMPLETED_CONTROLLERS=`kubectl get pod -o wide | grep -e "controller-" -e "chief-" | grep Completed | awk '{print $1}'`

  if [ -n "${COMPLETED_CONTROLLERS}" ]; then
    for completed_pod in ${COMPLETED_CONTROLLERS}; do
      # 작업 이름 추출 (예: id1_cifar10_alexnet_sync_batch32768)
      COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
          jobname = jobname "_" $i
        }
        print jobname
      }'`

      # 작업 포드 이름 추출 (예: id1-cifar10-alexnet-sync-batch32768)
      COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
          jobname = jobname "-" $i
        }
        print jobname
      }'`

      echo "Job ${COMPLETED_JOB} completed (controller/chief is in Completed state)"

      # 노드 정보 저장
      kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt
      echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt

      # 작업 삭제
      kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
    done
  fi

  sleep 0.1s;
  RUNNING=`kubectl get pod -o wide | awk '{print $1}' | sed -n '1p'`
done

ENDTIME=`date "+%H:%M:%S.%N"`
echo "$ENDTIME" > ${SAVEPATH}/end_makespan.txt
ENDLOGTIME=$(($(date +%s%N)/1000000000))
LOGTIME=$(($ENDLOGTIME - $STARTLOGTIME))
kubectl logs -n kube-system kube-scheduler-xsailor-master  > ${SAVEPATH}/scheduler_full_log.txt
kubectl logs -n kube-system tensorspot-scheduler > ${SAVEPATH}/scheduler_log.txt
