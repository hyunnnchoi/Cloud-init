#!/bin/bash

# 로그 디렉토리 설정
LOG_DIR="/home/tensorspot/logging"
PID_FILE="$LOG_DIR/kubectl_monitor.pid"

# 디렉토리가 없으면 생성
mkdir -p "$LOG_DIR"

# 이미 실행 중인지 확인
if [[ -f "$PID_FILE" ]]; then
    OLD_PID=$(cat "$PID_FILE")
    if kill -0 "$OLD_PID" 2>/dev/null; then
        echo "이미 실행 중입니다 (PID: $OLD_PID)"
        echo "중지하려면: kill $OLD_PID"
        exit 1
    else
        rm -f "$PID_FILE"
    fi
fi

# 백그라운드 프로세스 함수
monitor_pods() {
    # 무한 루프로 60초마다 실행
    while true; do
        # 현재 시간을 파일명에 포함
        TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
        FILENAME="kubectl_pods_${TIMESTAMP}.log"
        FILEPATH="$LOG_DIR/$FILENAME"
        
        # 로그 파일에 헤더 추가
        echo "=== kubectl get pods -A -o wide ===" > "$FILEPATH"
        echo "실행 시간: $(date)" >> "$FILEPATH"
        echo "======================================" >> "$FILEPATH"
        echo "" >> "$FILEPATH"
        
        # kubectl 명령 실행 및 결과 저장
        if kubectl get pods -A -o wide >> "$FILEPATH" 2>&1; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') - 성공: $FILENAME" >> "$LOG_DIR/monitor.log"
        else
            echo "$(date '+%Y-%m-%d %H:%M:%S') - 오류: kubectl 명령 실패" >> "$LOG_DIR/monitor.log"
        fi
        
        # 60초 대기
        sleep 60
    done
}

# 백그라운드로 실행
monitor_pods &

# PID 저장
MONITOR_PID=$!
echo $MONITOR_PID > "$PID_FILE"

echo "kubectl pods 모니터링이 백그라운드에서 시작되었습니다"
echo "PID: $MONITOR_PID"
echo "로그 디렉토리: $LOG_DIR"
echo "중지하려면: kill $MONITOR_PID"
echo "또는: rm $PID_FILE && kill $MONITOR_PID"
