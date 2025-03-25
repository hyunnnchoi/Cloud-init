
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
# 자원과 arrival_time을 고려하여 대기하는 함수 - 수정된 버전
wait_for_resources_or_arrival() {
    ARRIVAL_TIME=$1
    JOB_NAME=$2
    WORKER_NUM=$3

    echo "Checking resources for job ${JOB_NAME} (arrival time: ${ARRIVAL_TIME}s)"

    while true; do
        # arrival time 체크
        CURRENT_EPOCH=$(date +%s)
        TIME_PASSED=$((CURRENT_EPOCH - STARTEPOCH))

        # arrival time이 되지 않았으면 계속 대기
        if [ $TIME_PASSED -lt $ARRIVAL_TIME ]; then
            TIME_REMAINING=$((ARRIVAL_TIME - TIME_PASSED))
            echo "Waiting for arrival time for job ${JOB_NAME} (Remaining: ${TIME_REMAINING}s)"
            sleep 0.1s
            continue
        fi

        # arrival time이 되었으면 이전 작업 상태 확인
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

                # 완료된 작업이 정리되었으므로 대기 중인 포드 다시 확인
                PENDING_PODS=$(kubectl get pods | grep -e "Pending" | wc -l)
                if [ $PENDING_PODS -eq 0 ]; then
                    echo "All previous jobs allocated. Starting job ${JOB_NAME} now."
                    return 0
                fi
            fi

            echo "Arrival time reached but waiting for previous jobs to be allocated resources first."
            sleep 0.5s
        fi
    done
}



# 첫 번째 작업 처리
MODEL="id0_imagenet_vgg16_sync_batch256"
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


# 작업 1: id1_cifar10_resnet110_sync_batch8192 처리
echo "Preparing job 1: id1_cifar10_resnet110_sync_batch8192 (Workers: 8, Arrival: 1)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 1 "id1_cifar10_resnet110_sync_batch8192" 8

MODEL="id1_cifar10_resnet110_sync_batch8192"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 8


# 작업 2: id2_squad_gpt2_sync_batch8 처리
echo "Preparing job 2: id2_squad_gpt2_sync_batch8 (Workers: 2, Arrival: 42)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 42 "id2_squad_gpt2_sync_batch8" 2

MODEL="id2_squad_gpt2_sync_batch8"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 2


# 작업 3: id3_squad_bertl_sync_batch8 처리
echo "Preparing job 3: id3_squad_bertl_sync_batch8 (Workers: 2, Arrival: 80)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 80 "id3_squad_bertl_sync_batch8" 2

MODEL="id3_squad_bertl_sync_batch8"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 2


# 작업 4: id4_squad_gpt2xl_sync_batch8 처리
echo "Preparing job 4: id4_squad_gpt2xl_sync_batch8 (Workers: 2, Arrival: 107)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 107 "id4_squad_gpt2xl_sync_batch8" 2

MODEL="id4_squad_gpt2xl_sync_batch8"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 2


# 작업 5: id5_squad_gpt2l_sync_batch32 처리
echo "Preparing job 5: id5_squad_gpt2l_sync_batch32 (Workers: 8, Arrival: 108)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 108 "id5_squad_gpt2l_sync_batch32" 8

MODEL="id5_squad_gpt2l_sync_batch32"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 8


# 작업 6: id6_squad_gpt2m_sync_batch8 처리
echo "Preparing job 6: id6_squad_gpt2m_sync_batch8 (Workers: 2, Arrival: 125)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 125 "id6_squad_gpt2m_sync_batch8" 2

MODEL="id6_squad_gpt2m_sync_batch8"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 2


# 작업 7: id7_squad_gpt2m_sync_batch32 처리
echo "Preparing job 7: id7_squad_gpt2m_sync_batch32 (Workers: 8, Arrival: 219)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 219 "id7_squad_gpt2m_sync_batch32" 8

MODEL="id7_squad_gpt2m_sync_batch32"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 8


# 작업 8: id8_cifar10_resnet110_sync_batch4096 처리
echo "Preparing job 8: id8_cifar10_resnet110_sync_batch4096 (Workers: 4, Arrival: 337)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 337 "id8_cifar10_resnet110_sync_batch4096" 4

MODEL="id8_cifar10_resnet110_sync_batch4096"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 4


# 작업 9: id9_squad_bert_sync_batch16 처리
echo "Preparing job 9: id9_squad_bert_sync_batch16 (Workers: 4, Arrival: 407)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 407 "id9_squad_bert_sync_batch16" 4

MODEL="id9_squad_bert_sync_batch16"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 4


# 작업 10: id10_imagenet_resnet50_sync_batch512 처리
echo "Preparing job 10: id10_imagenet_resnet50_sync_batch512 (Workers: 4, Arrival: 605)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 605 "id10_imagenet_resnet50_sync_batch512" 4

MODEL="id10_imagenet_resnet50_sync_batch512"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 4


# 작업 11: id11_squad_gpt2xl_sync_batch16 처리
echo "Preparing job 11: id11_squad_gpt2xl_sync_batch16 (Workers: 4, Arrival: 684)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 684 "id11_squad_gpt2xl_sync_batch16" 4

MODEL="id11_squad_gpt2xl_sync_batch16"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 4


# 작업 12: id12_squad_gpt2xl_sync_batch32 처리
echo "Preparing job 12: id12_squad_gpt2xl_sync_batch32 (Workers: 8, Arrival: 871)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 871 "id12_squad_gpt2xl_sync_batch32" 8

MODEL="id12_squad_gpt2xl_sync_batch32"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 8


# 작업 13: id13_imagenet_resnet50_sync_batch1024 처리
echo "Preparing job 13: id13_imagenet_resnet50_sync_batch1024 (Workers: 8, Arrival: 1015)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 1015 "id13_imagenet_resnet50_sync_batch1024" 8

MODEL="id13_imagenet_resnet50_sync_batch1024"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 8


# 작업 14: id14_imagenet_inception3_sync_batch256 처리
echo "Preparing job 14: id14_imagenet_inception3_sync_batch256 (Workers: 4, Arrival: 1060)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 1060 "id14_imagenet_inception3_sync_batch256" 4

MODEL="id14_imagenet_inception3_sync_batch256"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 4


# 작업 15: id15_squad_gpt2m_sync_batch16 처리
echo "Preparing job 15: id15_squad_gpt2m_sync_batch16 (Workers: 4, Arrival: 1067)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 1067 "id15_squad_gpt2m_sync_batch16" 4

MODEL="id15_squad_gpt2m_sync_batch16"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 4


# 작업 16: id16_imagenet_vgg16_sync_batch1024 처리
echo "Preparing job 16: id16_imagenet_vgg16_sync_batch1024 (Workers: 8, Arrival: 1103)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 1103 "id16_imagenet_vgg16_sync_batch1024" 8

MODEL="id16_imagenet_vgg16_sync_batch1024"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 8


# 작업 17: id17_squad_gpt2_sync_batch32 처리
echo "Preparing job 17: id17_squad_gpt2_sync_batch32 (Workers: 8, Arrival: 1186)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 1186 "id17_squad_gpt2_sync_batch32" 8

MODEL="id17_squad_gpt2_sync_batch32"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 8


# 작업 18: id18_squad_bert_sync_batch16 처리
echo "Preparing job 18: id18_squad_bert_sync_batch16 (Workers: 4, Arrival: 1269)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 1269 "id18_squad_bert_sync_batch16" 4

MODEL="id18_squad_bert_sync_batch16"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 4


# 작업 19: id19_imagenet_resnet50_sync_batch512 처리
echo "Preparing job 19: id19_imagenet_resnet50_sync_batch512 (Workers: 4, Arrival: 1337)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 1337 "id19_imagenet_resnet50_sync_batch512" 4

MODEL="id19_imagenet_resnet50_sync_batch512"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 4


# 작업 20: id20_squad_bert_sync_batch32 처리
echo "Preparing job 20: id20_squad_bert_sync_batch32 (Workers: 8, Arrival: 1361)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 1361 "id20_squad_bert_sync_batch32" 8

MODEL="id20_squad_bert_sync_batch32"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 8


# 작업 21: id21_squad_bertl_sync_batch32 처리
echo "Preparing job 21: id21_squad_bertl_sync_batch32 (Workers: 8, Arrival: 1424)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 1424 "id21_squad_bertl_sync_batch32" 8

MODEL="id21_squad_bertl_sync_batch32"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 8


# 작업 22: id22_imagenet_vgg16_sync_batch1024 처리
echo "Preparing job 22: id22_imagenet_vgg16_sync_batch1024 (Workers: 8, Arrival: 1460)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 1460 "id22_imagenet_vgg16_sync_batch1024" 8

MODEL="id22_imagenet_vgg16_sync_batch1024"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 8


# 작업 23: id23_squad_gpt2l_sync_batch16 처리
echo "Preparing job 23: id23_squad_gpt2l_sync_batch16 (Workers: 4, Arrival: 1730)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 1730 "id23_squad_gpt2l_sync_batch16" 4

MODEL="id23_squad_gpt2l_sync_batch16"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 4


# 작업 24: id24_squad_gpt2l_sync_batch32 처리
echo "Preparing job 24: id24_squad_gpt2l_sync_batch32 (Workers: 8, Arrival: 1873)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 1873 "id24_squad_gpt2l_sync_batch32" 8

MODEL="id24_squad_gpt2l_sync_batch32"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 8


# 작업 25: id25_imagenet_inception3_sync_batch256 처리
echo "Preparing job 25: id25_imagenet_inception3_sync_batch256 (Workers: 4, Arrival: 1970)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 1970 "id25_imagenet_inception3_sync_batch256" 4

MODEL="id25_imagenet_inception3_sync_batch256"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 4


# 작업 26: id26_imagenet_inception3_sync_batch256 처리
echo "Preparing job 26: id26_imagenet_inception3_sync_batch256 (Workers: 4, Arrival: 1990)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 1990 "id26_imagenet_inception3_sync_batch256" 4

MODEL="id26_imagenet_inception3_sync_batch256"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 4


# 작업 27: id27_squad_gpt2_sync_batch32 처리
echo "Preparing job 27: id27_squad_gpt2_sync_batch32 (Workers: 8, Arrival: 2013)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 2013 "id27_squad_gpt2_sync_batch32" 8

MODEL="id27_squad_gpt2_sync_batch32"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 8


# 작업 28: id28_squad_bertl_sync_batch16 처리
echo "Preparing job 28: id28_squad_bertl_sync_batch16 (Workers: 4, Arrival: 2016)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 2016 "id28_squad_bertl_sync_batch16" 4

MODEL="id28_squad_bertl_sync_batch16"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
echo "Submitting job: $MODEL"
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${MODEL}_job_submitted.txt

# 작업이 실제로 노드에 스케줄링될 때까지 대기
wait_for_pod_scheduling "$MODEL" 4


# 작업 29: id29_cifar10_resnet110_sync_batch8192 처리
echo "Preparing job 29: id29_cifar10_resnet110_sync_batch8192 (Workers: 8, Arrival: 2110)"

# 자원 또는 arrival_time 대기
wait_for_resources_or_arrival 2110 "id29_cifar10_resnet110_sync_batch8192" 8

MODEL="id29_cifar10_resnet110_sync_batch8192"
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
gcloud compute ssh --zone us-central1-a xsailor-master --command "sudo sh /home/jhlee21/gpu_off.sh"
gcloud compute ssh --zone us-central1-a xsailor-worker1 --command "sudo sh /home/jhlee21/gpu_off.sh"
