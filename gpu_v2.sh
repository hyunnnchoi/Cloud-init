#!/bin/bash
# gpu.sh - 시간 포맷 개선 버전
HOSTNAME=$(hostname)
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_DIR="/home/tensorspot/tfjob"  # 이미 존재함
LOG_FILE="${LOG_DIR}/gpu_${HOSTNAME}.txt"
BACKUP_DIR="${LOG_DIR}/backups"

# 백업 디렉토리만 생성 (필요시)
sudo mkdir -p $BACKUP_DIR

# 권한 설정 (로그 파일 쓰기 문제 해결)
sudo chmod -R 777 $LOG_DIR
sudo chmod -R 777 $BACKUP_DIR

# 이미 실행 중인지 확인
NVML_RUNNING=$(ps aux | grep -v grep | grep "/home/tensorspot/Cloud-init/NVML/NVML" | wc -l)
if [ "$NVML_RUNNING" -gt 0 ]; then
    echo "NVML is already running. Stopping current process."
    sudo pkill -f "/home/tensorspot/Cloud-init/NVML/NVML"
    sleep 1
fi

# 기존 로그 파일 백업
if [ -f "$LOG_FILE" ]; then
    BACKUP_FILE="${BACKUP_DIR}/gpu_${HOSTNAME}_${TIMESTAMP}.bak"
    sudo cp "$LOG_FILE" "$BACKUP_FILE"
    echo "Previous log backed up to $BACKUP_FILE"
fi

# 실행 전 로그 기록 (날짜와 시간 모두 상세히 기록)
echo "[$(date '+%Y-%m-%d %H:%M:%S')] NVML monitoring started" | sudo tee $LOG_FILE > /dev/null

# NVML 실행 - 백그라운드로 실행하고 PID 저장
sudo /home/tensorspot/Cloud-init/NVML/NVML >> $LOG_FILE 2>&1 &
NVML_PID=$!
echo "[$(date '+%Y-%m-%d %H:%M:%S')] NVML started with PID $NVML_PID"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Logging to $LOG_FILE"

# PID 파일 생성 (나중에 상태 확인용)
echo $NVML_PID | sudo tee "${LOG_DIR}/nvml.pid" > /dev/null
