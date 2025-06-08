#!/bin/bash

echo "=== Calico Pod 간 통신 문제 해결 스크립트 ==="

# 1. 현재 상태 진단
echo "1. 현재 클러스터 상태 확인..."
kubectl get nodes -o wide
kubectl get pods -n calico-system
kubectl get pods -n tigera-operator

# 2. Calico 파드 재시작
echo "2. Calico 파드들 재시작..."
kubectl delete pods -n calico-system --all
kubectl delete pods -n tigera-operator --all

# 3. Calico 파드가 다시 시작될 때까지 대기
echo "3. Calico 파드 재시작 대기..."
sleep 30
kubectl wait --for=condition=Ready pod -l k8s-app=calico-node -n calico-system --timeout=300s
kubectl wait --for=condition=Ready pod -l k8s-app=calico-kube-controllers -n calico-system --timeout=300s

# 4. Calico API 서버가 준비될 때까지 대기
echo "4. Calico API 서버 준비 대기..."
while ! kubectl get caliconodestatus 2>/dev/null; do
    echo "Calico API 서버 대기 중..."
    sleep 10
done

# 5. BGP 및 Felix 설정 적용 (API 서버 준비 후)
echo "5. Calico 성능 최적화 설정 적용..."

# BGP 설정
cat <<EOF | kubectl apply -f -
apiVersion: projectcalico.org/v3
kind: BGPConfiguration
metadata:
  name: default
spec:
  logSeverityScreen: Info
  nodeToNodeMeshEnabled: true
  asNumber: 64512
  serviceClusterIPs:
  - cidr: 10.96.0.0/12
EOF

# Felix 설정 (간소화된 버전)
cat <<EOF | kubectl apply -f -
apiVersion: projectcalico.org/v3
kind: FelixConfiguration
metadata:
  name: default
spec:
  healthEnabled: true
  healthHost: localhost
  healthPort: 9099
  logSeverityScreen: Info
  reportingInterval: 30s
  defaultEndpointToHostAction: ACCEPT
EOF

# 6. IP Pool 확인 및 수정 (필요한 경우)
echo "6. IP Pool 설정 확인..."
kubectl get ippools -o yaml

# 7. 네트워크 정책 확인
echo "7. 네트워크 정책 확인..."
kubectl get networkpolicies --all-namespaces

# 8. 테스트 파드 생성하여 연결 테스트
echo "8. 연결 테스트용 파드 생성..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-pod-1
  labels:
    app: test
spec:
  containers:
  - name: test
    image: busybox
    command: ['sleep', '3600']
---
apiVersion: v1
kind: Pod
metadata:
  name: test-pod-2
  labels:
    app: test
spec:
  containers:
  - name: test
    image: busybox
    command: ['sleep', '3600']
EOF

# 9. 테스트 파드 준비 대기
echo "9. 테스트 파드 준비 대기..."
kubectl wait --for=condition=Ready pod test-pod-1 --timeout=120s
kubectl wait --for=condition=Ready pod test-pod-2 --timeout=120s

# 10. Pod IP 확인 및 ping 테스트
echo "10. Pod 간 연결 테스트..."
POD1_IP=$(kubectl get pod test-pod-1 -o jsonpath='{.status.podIP}')
POD2_IP=$(kubectl get pod test-pod-2 -o jsonpath='{.status.podIP}')

echo "Pod 1 IP: $POD1_IP"
echo "Pod 2 IP: $POD2_IP"

echo "Pod 1에서 Pod 2로 ping 테스트:"
kubectl exec test-pod-1 -- ping -c 3 $POD2_IP

echo "Pod 2에서 Pod 1로 ping 테스트:"
kubectl exec test-pod-2 -- ping -c 3 $POD1_IP

# 11. 정리
echo "11. 테스트 파드 정리..."
kubectl delete pod test-pod-1 test-pod-2

echo "=== 해결 스크립트 완료 ==="
