#!/bin/bash

# kube-scheduler 로그 수집 스크립트
# 사용법: ./scheduler-log-collector.sh

LOG_DIR="/home/tensorspot/logging"
POD_NAME="kube-scheduler-xsailor-master"
NAMESPACE="kube-system"
LOG_FILE_PREFIX="kube-scheduler"

# 로그 디렉토리 확인 및 생성
if [ ! -d "$LOG_DIR" ]; then
    echo "로그 디렉토리가 존재하지 않습니다: $LOG_DIR"
    exit 1
fi

cd "$LOG_DIR"

echo "kube-scheduler 로그 수집을 시작합니다..."
echo "로그 저장 위치: $LOG_DIR"
echo "Pod: $POD_NAME"
echo "Namespace: $NAMESPACE"

# 하나의 로그 파일로 통합
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="${LOG_FILE_PREFIX}_${TIMESTAMP}.log"

echo "=== kube-scheduler 로그 수집 시작 ===" | tee "$LOG_FILE"
echo "수집 시작 시간: $(date)" | tee -a "$LOG_FILE"
echo "Pod 시작 시점부터 현재까지 + 실시간 로그" | tee -a "$LOG_FILE"
echo "=========================================" | tee -a "$LOG_FILE"

# Pod 시작 시점부터 현재까지의 모든 로그 수집
echo ">> 기존 로그 수집 중..." | tee -a "$LOG_FILE"
kubectl logs -n "$NAMESPACE" "$POD_NAME" --since-time="$(kubectl get pod -n "$NAMESPACE" "$POD_NAME" -o jsonpath='{.status.startTime}')" >> "$LOG_FILE"

echo "" >> "$LOG_FILE"
echo "=== 실시간 로그 수집 시작 ($(date)) ===" >> "$LOG_FILE"
echo "=======================================" >> "$LOG_FILE"

echo "기존 로그 수집 완료. 실시간 수집을 시작합니다..."
echo "로그 파일: $LOG_FILE"
echo "중지하려면 Ctrl+C를 누르세요"

# 신호 처리 함수
cleanup() {
    echo -e "\n로그 수집을 중지합니다..."
    echo "수집 종료 시간: $(date)" >> "$LOG_FILE"
    exit 0
}

# SIGINT (Ctrl+C) 신호 처리
trap cleanup SIGINT

# 실시간 로그 스트리밍 (같은 파일에 계속 추가)
kubectl logs -n "$NAMESPACE" "$POD_NAME" -f --since=1s >> "$LOG_FILE"
