
#!/bin/bash
STARTTIME=`date "+%H:%M:%S.%N"`
STARTLOGTIME=$(($(date +%s%N)/1000000000))
TFPATH="/home/tensorspot/Cloud-init" # Job(yaml) 저장 위치
# xsailor
SAVEPATH="/home/tensorspot/tfjob" # 결과 저장 위치

sudo rm -rf ${SAVEPATH}/*
echo "$STARTTIME" > ${SAVEPATH}/start_makespan.txt

# ssh on-prem # IP 수정해야 함.
ssh ubuntu@64.181.219.200 "sudo sh /home/tensorspot/Cloud-init/gpu.sh &" & #
ssh ubuntu@149.130.214.173 "sudo sh /home/tensorspot/Cloud-init/gpu.sh &" &


MODEL="id0_squad_gpt2l_sync_batch8"
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 0 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id1_cifar10_alexnet_sync_batch32768"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 6 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id2_squad_bert_sync_batch8"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 6 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id3_cifar10_resnet110_sync_batch2048"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 6 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id4_squad_gpt2xl_sync_batch8"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 0 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id5_squad_gpt2xl_sync_batch32"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 6 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id6_imagenet_vgg16_sync_batch256"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 4 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id7_imagenet_vgg16_sync_batch512"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 6 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id8_cifar10_alexnet_sync_batch8192"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 6 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id9_cifar10_densenet100_k12_sync_batch256"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 0 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id10_squad_bert_sync_batch32"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 6 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id11_squad_gpt2l_sync_batch8"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 6 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id12_imagenet_vgg16_sync_batch256"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 0 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id13_squad_gpt2xl_sync_batch32"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 4 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id14_imagenet_vgg16_sync_batch512"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 4 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id15_squad_bert_sync_batch16"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 4 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id16_squad_gpt2l_sync_batch16"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 6 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id17_cifar10_alexnet_sync_batch8192"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 4 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id18_imagenet_resnet50_sync_batch512"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 6 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id19_squad_bertl_sync_batch8"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 4 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id20_squad_bert_sync_batch16"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 6 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id21_cifar10_densenet100_k12_sync_batch256"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 6 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id22_squad_gpt2_sync_batch8"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 4 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id23_squad_gpt2_sync_batch16"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 6 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id24_squad_bertl_sync_batch8"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 0 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id25_imagenet_vgg16_sync_batch1024"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 4 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id26_cifar10_resnet110_sync_batch4096"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 0 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id27_cifar10_densenet100_k12_sync_batch1024"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 0 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id28_squad_gpt2_sync_batch32"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 0 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id29_imagenet_resnet50_sync_batch1024"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 0 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id30_squad_bert_sync_batch32"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 6 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id31_cifar10_densenet100_k12_sync_batch256"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 4 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id32_squad_bertl_sync_batch16"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 6 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id33_cifar10_densenet100_k12_sync_batch256"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 4 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id34_cifar10_resnet110_sync_batch4096"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 4 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id35_squad_gpt2_sync_batch16"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 6 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id36_imagenet_vgg16_sync_batch256"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 4 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id37_squad_bert_sync_batch16"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 0 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id38_cifar10_resnet110_sync_batch8192"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 0 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id39_cifar10_resnet110_sync_batch8192"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 0 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id40_squad_gpt2xl_sync_batch32"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 6 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id41_imagenet_resnet50_sync_batch256"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 4 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id42_imagenet_resnet50_sync_batch512"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 4 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id43_imagenet_resnet50_sync_batch512"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 0 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id44_cifar10_densenet100_k12_sync_batch1024"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 0 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id45_squad_bertl_sync_batch32"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 4 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id46_imagenet_vgg16_sync_batch512"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 0 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id47_squad_gpt2l_sync_batch32"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 4 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id48_squad_gpt2xl_sync_batch16"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 4 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id49_cifar10_resnet110_sync_batch4096"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 0 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id50_squad_bertl_sync_batch32"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 4 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id51_squad_bert_sync_batch16"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 0 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id52_cifar10_resnet110_sync_batch8192"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 0 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id53_cifar10_resnet110_sync_batch8192"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 0 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id54_squad_gpt2_sync_batch32"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 0 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id55_cifar10_densenet100_k12_sync_batch1024"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 4 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id56_cifar10_densenet100_k12_sync_batch512"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 0 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id57_squad_gpt2l_sync_batch32"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 0 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id58_squad_gpt2xl_sync_batch32"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 0 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id59_squad_gpt2xl_sync_batch32"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 4 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id60_squad_gpt2_sync_batch16"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 0 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id61_cifar10_densenet100_k12_sync_batch1024"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 4 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id62_cifar10_alexnet_sync_batch16384"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 4 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id63_cifar10_resnet110_sync_batch4096"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 0 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id64_squad_bert_sync_batch32"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 0 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id65_cifar10_alexnet_sync_batch32768"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 0 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id66_imagenet_vgg16_sync_batch1024"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 4 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id67_squad_gpt2_sync_batch16"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 0 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id68_squad_bert_sync_batch32"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 0 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id69_squad_gpt2l_sync_batch32"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 0 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id70_cifar10_alexnet_sync_batch32768"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 4 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id71_squad_gpt2_sync_batch16"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 4 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id72_imagenet_resnet50_sync_batch512"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 0 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id73_squad_gpt2l_sync_batch32"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 4 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id74_imagenet_resnet50_sync_batch512"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 4 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id75_imagenet_resnet50_sync_batch512"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 0 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id76_squad_gpt2l_sync_batch32"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 4 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id77_squad_gpt2xl_sync_batch16"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 0 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id78_cifar10_densenet100_k12_sync_batch1024"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 4 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id79_squad_bert_sync_batch16"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 0 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id80_squad_gpt2xl_sync_batch32"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 4 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id81_imagenet_vgg16_sync_batch512"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 0 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id82_cifar10_alexnet_sync_batch32768"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 4 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id83_squad_gpt2_sync_batch16"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 4 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id84_cifar10_alexnet_sync_batch16384"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 4 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id85_squad_gpt2xl_sync_batch16"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 0 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id86_cifar10_alexnet_sync_batch32768"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 4 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id87_cifar10_resnet110_sync_batch4096"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 0 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id88_squad_bertl_sync_batch32"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 4 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id89_imagenet_vgg16_sync_batch512"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 0 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id90_squad_bertl_sync_batch32"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 4 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id91_squad_bertl_sync_batch16"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 0 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id92_imagenet_resnet50_sync_batch1024"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 0 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id93_squad_gpt2l_sync_batch32"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 0 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id94_squad_gpt2_sync_batch32"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 4 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id95_cifar10_alexnet_sync_batch16384"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 4 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id96_squad_bertl_sync_batch16"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 4 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id97_imagenet_resnet50_sync_batch512"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 4 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id98_squad_bertl_sync_batch16"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
while [ $WORKERNUM -gt 0 ]
do
COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "_" $i
        }
        print jobname
        }'`
    done
    for completed_pod in ${COMPLETED}; do
    COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
        jobname = jobname "-" $i
        }
        print jobname
    }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt

    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
fi
sleep 0.1s;
WORKERNUM=`kubectl get pod -o wide | grep -e "worker-" -e "chief-" | wc -l`
done

MODEL="id99_squad_gpt2l_sync_batch32"
sudo rm -rf ${SAVEPATH}/${MODEL}
mkdir -p ${SAVEPATH}/${MODEL}
#### Training the model
date "+%H:%M:%S.%N" > ${SAVEPATH}/${MODEL}_job_create.txt
kubectl create -f ${TFPATH}/net_script/${MODEL}_spot.yaml
sleep 0.1s

RUNNING=`kubectl get pod -o wide | awk '{print $1}' | sed -n '1p'`
while [ -n "${RUNNING}" ]
do
  COMPLETED=`kubectl get pod -o wide | grep Completed | awk '{print $1}' | sed -n '1p'`
  if [ -n "${COMPLETED}" ]; then
    for completed_pod in ${COMPLETED}; do
      COMPLETED_JOB=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
          jobname = jobname "_" $i
        }
        print jobname
      }'`
    done
    for completed_pod in ${COMPLETED}; do
      COMPLETED_JOB_POD=`echo ${completed_pod} | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
          jobname = jobname "-" $i
        }
        print jobname
      }'`
    done
    # Save node information for all pods in the job
    kubectl get pod -o wide | grep ${COMPLETED_JOB_POD} | awk '{print $1 "\t" $7}' > ${SAVEPATH}/${COMPLETED_JOB}_node_info.txt
    echo $(date "+%H:%M:%S.%N") > ${SAVEPATH}/${COMPLETED_JOB}_job_finished.txt
    kubectl delete -f ${TFPATH}/net_script/${COMPLETED_JOB}_spot.yaml
  fi
  sleep 0.1s;
  RUNNING=`kubectl get pod -o wide | awk '{print $1}' | sed -n '1p'`
done

ENDTIME=`date "+%H:%M:%S.%N"`
echo "$ENDTIME" > ${SAVEPATH}/end_makespan.txt
ENDLOGTIME=$(($(date +%s%N)/1000000000))
LOGTIME=$(($ENDLOGTIME - $STARTLOGTIME))
kubectl logs -n kube-system --since $(($LOGTIME+5))s kube-scheduler-xsailor-master > ${SAVEPATH}/scheduler_log.txt
kubectl logs -n kube-system kube-scheduler-xsailor-master  > ${SAVEPATH}/scheduler_full_log.txt
# On-prem
ssh ubuntu@64.181.219.200 "sudo sh /home/tensorspot/Cloud-init/gpu_off.sh"
ssh ubuntu@149.130.214.173 "sudo sh /home/tensorspot/Cloud-init/gpu_off.sh"
