#!/bin/bash

echo "=== 실험 롤백 스크립트 시작 ==="
ROLLBACK_TIME=`date "+%H:%M:%S.%N"`
echo "롤백 시작 시간: $ROLLBACK_TIME"

# 경로 설정
TFPATH="/home/tensorspot/Cloud-init"
DATAPATH="/home/tensorspot/data"
SAVEPATH="/home/tensorspot/tfjob"
PEM_KEY="~/tethys-v/tethys.pem"

echo "1. 마스터 노드 데이터 삭제 중..."
# 마스터 노드의 데이터 삭제
sudo rm -rf ${DATAPATH}/*
sudo rm -rf ${SAVEPATH}/*
echo "마스터 노드 데이터 삭제 완료"

echo "2. 워커 노드들의 데이터 삭제 중..."
# 동적으로 노드 IP 가져오기 (colo.sh와 동일한 방식)
NODE_IPS=$(kubectl get nodes -o wide --no-headers | awk '{print $6}')

# 각 워커 노드에서 데이터 삭제
for node_ip in $NODE_IPS; do
    echo "워커 노드 $node_ip 데이터 삭제 중..."
    ssh -i ${PEM_KEY} -o StrictHostKeyChecking=no ubuntu@$node_ip "sudo rm -rf /home/tensorspot/data/* && sudo rm -rf /home/tensorspot/tfjob/*" &
done

# 모든 SSH 작업 완료 대기
wait
echo "모든 워커 노드 데이터 삭제 완료"

echo "3. GPU 측정 스크립트 종료 중..."
# 모든 노드에서 GPU 스크립트 종료
for node_ip in $NODE_IPS; do
    echo "노드 $node_ip GPU 스크립트 종료 중..."
    ssh -i ${PEM_KEY} -o StrictHostKeyChecking=no ubuntu@$node_ip "sudo sh /home/tensorspot/Cloud-init/gpu_off.sh" &
done

# 모든 SSH 작업 완료 대기
wait
echo "모든 노드 GPU 스크립트 종료 완료"

echo "4. 스케줄러 재시작 중..."
# 스케줄러 삭제 및 재생성
cd ${TFPATH}
kubectl delete -f tensorspot_ar.yaml
sleep 10
kubectl create -f tensorspot_ar.yaml
echo "스케줄러 재시작 완료"

echo "5. CoreDNS 재시작 중..."
# CoreDNS 포드 삭제 (자동으로 재시작됨)
kubectl delete pods -n kube-system -l k8s-app=kube-dns
echo "CoreDNS 재시작 완료"

echo "6. 실행 중인 작업 정리 중..."
# 실행 중인 TensorFlow Job들 정리
kubectl get pods | grep -E "(worker|chief|controller)" | awk '{print $1}' | while read pod; do
    if [ ! -z "$pod" ]; then
        echo "포드 $pod 삭제 중..."
        kubectl delete pod $pod --force --grace-period=0
    fi
done

# YAML 파일들로 생성된 작업들 정리
for scheduler_type in colo k8s spot gangbinpack gangk8s vol; do
    for yaml_file in ${TFPATH}/net_script/*_${scheduler_type}.yaml; do
        if [ -f "$yaml_file" ]; then
            echo "YAML 파일 $yaml_file 기반 작업 삭제 중..."
            kubectl delete -f "$yaml_file" --ignore-not-found=true
        fi
    done
done

echo "실행 중인 작업 정리 완료"

echo "7. 시스템 상태 확인 중..."
echo "현재 실행 중인 포드:"
kubectl get pods

echo "노드 상태:"
kubectl get nodes

echo "스케줄러 상태:"
kubectl get pods -n kube-system | grep scheduler

ROLLBACK_END_TIME=`date "+%H:%M:%S.%N"`
echo "롤백 완료 시간: $ROLLBACK_END_TIME"
echo "=== 실험 롤백 스크립트 완료 ===" 