#!/bin/bash
# gpu_nohup_off.sh - NVML 모니터링 종료 스크립트
HOSTNAME=$(hostname)
LOG_DIR="/home/tensorspot/logging"
LOG_FILE="${LOG_DIR}/gpu_${HOSTNAME}.txt"

echo "Stopping NVML monitoring..."

# NVML 프로세스 찾기 및 종료
NVML_PIDS=$(pgrep -f "NVML")

if [ -n "$NVML_PIDS" ]; then
    echo "Found NVML processes: $NVML_PIDS"
    
    # 로그에 종료 메시지 기록
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] NVML monitoring stopped" | sudo tee -a $LOG_FILE > /dev/null
    
    # NVML 프로세스 종료
    sudo pkill -f "NVML"
    
    # 강제 종료가 필요한 경우
    sleep 2
    if pgrep -f "NVML" > /dev/null; then
        echo "Force killing remaining NVML processes..."
        sudo pkill -9 -f "NVML"
    fi
    
    echo "NVML monitoring stopped successfully"
else
    echo "No NVML processes found running"
fi

# nohup.out 파일 정리 (선택사항)
if [ -f "nohup.out" ]; then
    sudo rm -f nohup.out
    echo "Cleaned up nohup.out file"
fi

echo "GPU monitoring cleanup completed"
