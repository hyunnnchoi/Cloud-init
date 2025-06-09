#!/bin/bash
# gpu_off.sh - NVML 모니터링 중단 스크립트
HOSTNAME=$(hostname)
LOG_DIR="/home/tensorspot/logging"
LOG_FILE="${LOG_DIR}/gpu_${HOSTNAME}.txt"
SCREEN_NAME="nvml_monitor"

echo "NVML 모니터링을 중단합니다..."

# 실행 중인 screen 세션 확인
if screen -list | grep -q "$SCREEN_NAME"; then
    echo "실행 중인 screen 세션을 발견했습니다. 종료 중..."
    
    # 로그 파일에 종료 메시지 기록
    if [ -f "$LOG_FILE" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] NVML monitoring stopped" | sudo tee -a $LOG_FILE > /dev/null
    fi
    
    # screen 세션 종료
    screen -S $SCREEN_NAME -X quit
    sleep 2
    
    # 종료 확인
    if screen -list | grep -q "$SCREEN_NAME"; then
        echo "경고: screen 세션이 완전히 종료되지 않았습니다."
        echo "수동으로 종료하려면: screen -S $SCREEN_NAME -X quit"
    else
        echo "NVML 모니터링이 성공적으로 중단되었습니다."
    fi
else
    echo "실행 중인 NVML 모니터링 세션을 찾을 수 없습니다."
fi

# NVML 관련 프로세스 정리 (추가 안전 조치)
echo "NVML 관련 프로세스를 확인합니다..."
NVML_PIDS=$(pgrep -f "NVML" 2>/dev/null)
if [ ! -z "$NVML_PIDS" ]; then
    echo "발견된 NVML 프로세스들을 종료합니다: $NVML_PIDS"
    sudo kill $NVML_PIDS 2>/dev/null
    sleep 1
    
    # 강제 종료가 필요한지 확인
    REMAINING_PIDS=$(pgrep -f "NVML" 2>/dev/null)
    if [ ! -z "$REMAINING_PIDS" ]; then
        echo "일부 프로세스가 남아있어 강제 종료합니다: $REMAINING_PIDS"
        sudo kill -9 $REMAINING_PIDS 2>/dev/null
    fi
fi

echo "정리 완료!"
echo ""
echo "새로운 모니터링을 시작하려면 gpu_v2.sh를 실행하세요."