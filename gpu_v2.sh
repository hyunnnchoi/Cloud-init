#!/bin/bash
# gpu_screen_fg.sh
HOSTNAME=$(hostname)
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_DIR="/home/tensorspot/tfjob"
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

# screen 설치 확인 및 설치
if ! command -v screen &> /dev/null; then
    echo "Installing screen..."
    sudo apt-get update
    sudo apt-get install -y screen
fi

# screen 세션에서 NVML 실행
SCREEN_NAME="nvml_monitor"

# 이미 실행 중인 세션 확인 및 종료
if screen -list | grep -q "$SCREEN_NAME"; then
    echo "Existing screen session found. Terminating..."
    screen -S $SCREEN_NAME -X quit
    sleep 1
fi

# 로그 시작 메시지
echo "[$(date '+%Y-%m-%d %H:%M:%S')] NVML monitoring started in screen session" | sudo tee $LOG_FILE > /dev/null

# screen 세션 생성 및 NVML 실행 (바로 접속)
echo "Starting NVML in a screen session..."
echo "To detach from screen session: Press Ctrl+A, then D"
echo "To reattach later: screen -r $SCREEN_NAME"
sleep 2

# 포그라운드로 screen 세션 시작하고 그 안에서 NVML 실행
screen -S $SCREEN_NAME bash -c "echo 'NVML is running. Press Ctrl+A, then D to detach.'; sudo /home/tensorspot/Cloud-init/NVML/NVML | sudo tee -a $LOG_FILE"
