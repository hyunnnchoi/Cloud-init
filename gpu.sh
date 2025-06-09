#!/bin/bash
# gpu_nohup.sh - SSH 원격 실행에 최적화된 버전
HOSTNAME=$(hostname)
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_DIR="/home/tensorspot/logging"
LOG_FILE="${LOG_DIR}/gpu_${HOSTNAME}.txt"
BACKUP_DIR="${LOG_DIR}/backups"

# 백업 디렉토리 생성
sudo mkdir -p $BACKUP_DIR
sudo chmod -R 777 $LOG_DIR
sudo chmod -R 777 $BACKUP_DIR

# 기존 로그 파일 백업
if [ -f "$LOG_FILE" ]; then
    BACKUP_FILE="${BACKUP_DIR}/gpu_${HOSTNAME}_${TIMESTAMP}.bak"
    sudo cp "$LOG_FILE" "$BACKUP_FILE"
    echo "Previous log backed up to $BACKUP_FILE"
fi

# 기존 NVML 프로세스 종료
sudo pkill -f "NVML" 2>/dev/null || true

# 로그 시작 메시지
echo "[$(date '+%Y-%m-%d %H:%M:%S')] NVML monitoring started with nohup" | sudo tee $LOG_FILE > /dev/null

# nohup으로 NVML 백그라운드 실행
echo "Starting NVML with nohup..."
nohup sudo /home/tensorspot/Cloud-init/NVML/NVML >> $LOG_FILE 2>&1 &

echo "NVML started in background. Check log: $LOG_FILE" 
