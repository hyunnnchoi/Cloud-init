#!/bin/bash

echo "================= Lambda Labs Setup Script ================="
echo "[https://cloud.lambdalabs.com/instances]"
echo ""
echo "💡 Dockerhub 이미지 버전 최종 정리 (2025.04.03)"
echo "   NLP: potato4332/nlp-image:0.0.1"
echo "   CV: potato4332/tf2-cpu-docker:0.5.5x"
echo "   CV: potato4332/tf2-gpu-docker:0.4.5x"
echo ""

# 스크립트를 관리자 권한으로 실행하는지 확인
if [[ $EUID -ne 0 ]]; then
   echo "이 스크립트는 sudo로 실행해야 합니다."
   echo "사용법: sudo ./lambda_labs_setup.sh [master|worker]"
   exit 1
fi

# 마스터/워커 노드 인자 확인
if [ "$#" -ne 1 ]; then
    echo "마스터 노드인지 워커 노드인지 지정해주세요."
    echo "사용법: sudo ./lambda_labs_setup.sh [master|worker]"
    exit 1
fi

NODE_TYPE=$1

if [[ "$NODE_TYPE" != "master" && "$NODE_TYPE" != "worker" ]]; then
    echo "인자는 'master' 또는 'worker'여야 합니다."
    echo "사용법: sudo ./lambda_labs_setup.sh [master|worker]"
    exit 1
fi

echo "노드 타입: $NODE_TYPE"
echo ""

# 사용자 확인 요청
read -p "설치를 진행하시겠습니까? (y/n): " -n 1 -r
echo    # 줄바꿈
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "설치가 취소되었습니다."
    exit 1
fi

# 단계별 설치 함수
install_cuda() {
    echo "====================> CUDA 설치 중..."
    mkdir -p ~/cuda_install
    cd ~/cuda_install

    echo "현재 경로: $(pwd)"

    # CUDA 12.2 설치
    wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-ubuntu2204.pin
    mv cuda-ubuntu2204.pin /etc/apt/preferences.d/cuda-repository-pin-600
    wget https://developer.download.nvidia.com/compute/cuda/12.2.0/local_installers/cuda-repo-ubuntu2204-12-2-local_12.2.0-535.54.03-1_amd64.deb
    dpkg -i cuda-repo-ubuntu2204-12-2-local_12.2.0-535.54.03-1_amd64.deb
    cp /var/cuda-repo-ubuntu2204-12-2-local/cuda-*-keyring.gpg /usr/share/keyrings/
    apt-get update

    apt-get -y install cuda-toolkit-12-2

    echo 'export PATH=/usr/local/cuda-12.2/bin${PATH:+:${PATH}}' >> ~/.bashrc
    echo 'export LD_LIBRARY_PATH=/usr/local/cuda-12.2/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}' >> ~/.bashrc

    # 환경변수 적용
    source ~/.bashrc

    # 설치 확인
    echo "드라이버 버전:"
    cat /proc/driver/nvidia/version
    echo -e "\nGPU 정보:"
    nvidia-smi
    echo -e "\nCUDA 버전:"
    nvcc -V

    echo "CUDA 설치 완료"
}

install_cudnn() {
    echo "====================> cuDNN 설치 중..."
    # Zlib
    apt-get install -y zlib1g

    # Network Repo Installation for Ubuntu
    cd ~/cuda_install
    wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.1-1_all.deb
    dpkg -i cuda-keyring_1.1-1_all.deb

    # Refresh the repository metadata
    apt-get update
    # Install per-CUDA meta-packages
    apt-get -y install cudnn9-cuda-12

    # 확인
    echo "cuDNN 버전:"
    cat /usr/include/cudnn_version.h | grep CUDNN_MAJOR -A 2

    echo "cuDNN 설치 완료"
}

install_docker() {
    echo "====================> Docker 설치 중..."
    # Add Docker's official GPG key:
    apt-get update
    apt-get install -y ca-certificates curl
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc

    # Add the repository to Apt sources:
    echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    tee /etc/apt/sources.list.d/docker.list > /dev/null

    apt-get update

    # List the available versions:
    echo "사용 가능한 Docker 버전:"
    apt-cache madison docker-ce | awk '{ print $3 }' | head -n 5

    # Select the desired version and install:
    VERSION_STRING=5:27.3.1-1~ubuntu.22.04~jammy
    apt-get install -y docker-ce=$VERSION_STRING docker-ce-cli=$VERSION_STRING containerd.io docker-buildx-plugin docker-compose-plugin

    # 확인
    echo -e "\nDocker 설치 확인 중..."
    docker run hello-world

    echo "Docker 설치 완료"
}

install_nvidia_docker() {
    echo "====================> nvidia-docker 설치 중..."
    apt-get update
    apt-get install -y nvidia-container-toolkit

    nvidia-ctk runtime configure --runtime=docker

    # 확인
    echo "nvidia-docker 설정 확인:"
    cat /etc/docker/daemon.json

    # Docker 서비스 재시작
    systemctl restart docker

    # 버전 확인
    echo -e "\nNVIDIA Container Toolkit 버전:"
    nvidia-ctk --version

    # 컨테이너 구동 테스트
    echo "NVIDIA Docker 설치 및 테스트 완료"
}

setup_prerequisites() {
    echo "====================> 사전 설정 및 Swap 비활성화 중..."
    modprobe br_netfilter

    cat <<EOF | tee /etc/modules-load.d/k8s.conf
br_netfilter
EOF

    cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF

    sysctl --system

    # Swap 비활성화
    swapoff -a
    # 컴퓨터 껐다 켜도 다시 swapoff -a 되도록 설정
    sed -i.bak -r 's/(.+ swap .+)/#\1/' /etc/fstab

    echo "사전 설정 및 Swap 비활성화 완료"
}

install_kubernetes() {
    echo "====================> Kubernetes 설치 중..."
    cd /home

    mkdir -p tensorspot
    cd tensorspot

    # 지금 Lambda Labs에서 공유 스토리지 쓰면 충돌남.
    # 각 노드에서 로컬 Path 만들기.
    mkdir -m 777 data
    mkdir -m 777 tfjob

    git clone -b k8s https://github.com/hyunnnchoi/Cloud-init.git

    cd Cloud-init
    git checkout k8s
    chmod -R 777 /home/tensorspot

    cat apt_archives_part_* | tee merged.tar.gz > /dev/null

    mv merged.tar.gz ../archives.tar.gz

    cd ../

    tar -xzf archives.tar.gz

    mkdir -p /usr/local/mydebs
    cp -R archives/* /usr/local/mydebs

    mkdir -p ~/bin
    cd ~/bin

    cat <<EOF > update-mydebs
#! /bin/bash
 cd /usr/local/mydebs
 dpkg-scanpackages . /dev/null | gzip -9c > Packages.gz
EOF

    chmod u+x ~/bin/update-mydebs

    echo "deb [trusted=yes] file:/usr/local/mydebs ./" | tee -a /etc/apt/sources.list

    ./update-mydebs

    apt-get update

    apt-get install -y kubelet=1.21.7-00 kubeadm=1.21.7-00 kubectl=1.21.7-00
    apt-mark hold kubelet kubeadm kubectl

    echo "Kubernetes 버전 확인:"
    kubectl version --client
    kubeadm version
    kubelet --version

    echo "Kubernetes 설치 완료"
}

setup_master_node() {
    echo "====================> Master Node 설정 중..."
    # init
    kubeadm config images list
    kubeadm config images pull

    # Flannel 10.244.0.0/16 사용
    kubeadm init --pod-network-cidr=10.244.0.0/16 --node-name xsailor-master

    # 실제 일반 사용자 확인 (logname 명령이 실패하는 경우 대비)
    if NORMAL_USER=$(logname 2>/dev/null); then
        echo "일반 사용자: $NORMAL_USER"
    else
        # logname 실패시 sudo를 실행한 실제 사용자 찾기
        NORMAL_USER=$(who am i | awk '{print $1}')
        if [ -z "$NORMAL_USER" ]; then
            # 그래도 실패하면 /home 디렉토리 내의 첫 번째 일반 사용자 사용
            NORMAL_USER=$(find /home -mindepth 1 -maxdepth 1 -type d -printf "%f\n" | grep -v "lost+found" | head -n 1)
        fi
        echo "일반 사용자 감지: $NORMAL_USER"
    fi

    USER_HOME="/home/$NORMAL_USER"

    # root 사용자용 kubeconfig 설정
    echo "root 사용자 kubeconfig 설정..."
    mkdir -p /root/.kube
    cp -f /etc/kubernetes/admin.conf /root/.kube/config
    chown root:root /root/.kube/config
    export KUBECONFIG=/root/.kube/config

    # 일반 사용자용 kubeconfig 설정
    echo "일반 사용자 kubeconfig 설정..."
    mkdir -p $USER_HOME/.kube
    cp -f /etc/kubernetes/admin.conf $USER_HOME/.kube/config
    chown -R $NORMAL_USER:$NORMAL_USER $USER_HOME/.kube

    # 환경 변수 설정 (.bashrc에 추가)
    echo 'export KUBECONFIG=$HOME/.kube/config' >> $USER_HOME/.bashrc

    # 중요: 공유 스토리지에 config 파일 복사
    mkdir -p $USER_HOME/tethys-v
    cp -f /etc/kubernetes/admin.conf $USER_HOME/tethys-v/config
    chown -R $NORMAL_USER:$NORMAL_USER $USER_HOME/tethys-v

    echo "마스터 노드 kubeconfig를 공유 스토리지에 복사했습니다: ~/tethys-v/config"

    # Join 토큰 생성 및 출력
    echo -e "\n워커 노드 조인 명령어 정보:"
    JOIN_TOKEN=$(kubeadm token create)
    HASH=$(openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //')

    # 네트워크 인터페이스가 eno1이 아닐 경우 대비
    if ip -4 addr show eno1 >/dev/null 2>&1; then
        IP_ADDRESS=$(ip -4 addr show eno1 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
    else
        # 다른 인터페이스에서 IPv4 주소 찾기
        IP_ADDRESS=$(ip -4 addr show | grep -v '127.0.0.1' | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n 1)
    fi

    echo -e "\n다음 명령어를 워커 노드에서 실행하세요:\n"
    echo "sudo kubeadm join ${IP_ADDRESS}:6443 --token ${JOIN_TOKEN} --discovery-token-ca-cert-hash sha256:${HASH} --node-name xsailor-worker1"

    # 설정을 파일로 저장
    JOIN_COMMAND="sudo kubeadm join ${IP_ADDRESS}:6443 --token ${JOIN_TOKEN} --discovery-token-ca-cert-hash sha256:${HASH} --node-name xsailor-worker1"
    echo "$JOIN_COMMAND" > $USER_HOME/worker_join_command.txt
    chown $NORMAL_USER:$NORMAL_USER $USER_HOME/worker_join_command.txt
    echo "$JOIN_COMMAND" > /root/worker_join_command.txt  # root 사용자를 위한 복사본

    # Flannel 네트워크 설치
    echo "Flannel 네트워크 설치 중..."
    # root 권한으로 직접 실행
    kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

    # 마스터 노드 taint 제거 (모든 노드에서 파드 실행 가능하도록)
    kubectl taint nodes --all node-role.kubernetes.io/master- || true

    echo "Kubernetes 노드 상태:"
    kubectl get nodes

    echo "Master Node 설정 완료"
}
setup_worker_node() {
    echo "====================> Worker Node 설정 중..."
    # 일반 사용자 확인
    NORMAL_USER=$(logname)
    USER_HOME="/home/$NORMAL_USER"

    # 중요: 공유 스토리지에서 config 파일 가져오기
    mkdir -p $USER_HOME/.kube

    # tethys-v는 이미 공유 스토리지로 마운트되어 있다고 가정
    mkdir -p $HOME/.kube
    cp ~/tethys-v/config ~/.kube/config
    sudo chown $(id -u):$(id -g) $HOME/.kube/config

    # Join 명령어 안내
    echo -e "\n마스터 노드에서 출력된 join 명령어를 실행하세요."
    echo "예시: sudo kubeadm join 10.19.86.137:6443 \\"
    echo "--token wgd07r.bf72vojha3okou4d \\"
    echo "--discovery-token-ca-cert-hash sha256:ada3674485d5535aecad9ac1f2117dac3334a3e9d82822f30314b29d24007ec5 \\"
    echo "--node-name xsailor-worker1"

    echo "Worker Node 설정 안내 완료"
}

install_flannel() {
    echo "====================> Flannel 설치 중..."
    # logname 대신 직접 kubectl 사용
    kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

    # 노드 상태 확인
    echo -e "\n노드 상태 확인:"
    kubectl get nodes

    # 마스터 노드 taint 제거 (모든 노드에서 파드 실행 가능하도록)
    kubectl taint nodes --all node-role.kubernetes.io/master- || true

    echo -e "\nFlannel 설치 완료"
}

install_nvidia_device_plugin() {
    echo "====================> NVIDIA device plugin 설치 중..."
    # 직접 kubectl 사용
    kubectl create -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/v0.10.0/nvidia-device-plugin.yml

    # 노드 개수만큼 pod가 있는지 확인
    echo -e "\nNVIDIA device plugin pods:"
    kubectl get pod -n kube-system | grep nvidia

    # 각 노드별 GPU 개수 확인
    echo -e "\n각 노드별 GPU 개수:"
    kubectl get nodes "-o=custom-columns=NAME:.metadata.name,GPU:.status.allocatable.nvidia\.com/gpu"

    echo -e "\nNVIDIA device plugin 설치 완료"
}

fix_gpu_issues() {
    echo "====================> GPU 문제 해결 중..."
    # GPU가 <none>으로 표시되는 경우
    cat <<EOF | tee /etc/docker/daemon.json
{
    "default-runtime": "nvidia",
    "runtimes": {
        "nvidia": {
            "path": "nvidia-container-runtime",
            "runtimeArgs": []
        }
    }
}
EOF

    # Docker 서비스 재시작
    systemctl restart docker

    echo "Docker 설정 변경 및 재시작 완료. GPU 상태가 업데이트되는 데 몇 분 걸릴 수 있습니다."
}

setup_node_selector() {
    echo "====================> Node selector 설정 중..."
    kubectl label nodes xsailor-master twonode=worker || true
    kubectl label nodes xsailor-worker1 twonode=worker || true

    echo "Node selector 설정 완료"
}

install_training_operator() {
    echo "====================> Training Operator 설치 중..."
    kubectl apply -k "github.com/kubeflow/training-operator/manifests/overlays/standalone?ref=v1.7.0"

    echo "Training Operator 설치 완료"
}

setup_pv_pvc() {
    echo "====================> PV, PVC 설정 중..."
    cd /home/tensorspot/Cloud-init

    kubectl create -f /home/tensorspot/Cloud-init/tfjob-data-volume.yaml
    kubectl create -f /home/tensorspot/Cloud-init/tfjob-nfs-dataset-storage-volume.yaml

    echo "PV, PVC 설정 완료"
}

pull_docker_images() { # 양 쪽 노드 모두에서 실행
    echo "====================> Docker 이미지 다운로드 중..."
    docker pull potato4332/tf2-cpu-docker:0.5.5x
    docker pull potato4332/tf2-gpu-docker:0.4.5x
    docker pull potato4332/nlp-keras:0.0.1x

    echo "Docker 이미지 다운로드 완료"
}

setup_bandwidth_limit() {
    echo "====================> 대역폭 제한 설정 중..."
    # 현재 tc 상태 확인
    sh /home/tensorspot/Cloud-init/eno1_tc_10G.sh show

    # tc 시작 (대역폭 제한 시작)
    sh /home/tensorspot/Cloud-init/eno1_tc_10G.sh start

    echo "대역폭 제한 설정 완료"
}

setup_iperf() {
    echo "====================> iperf 설정 중..."
    cd /home/tensorspot/Cloud-init

    kubectl create -f /home/tensorspot/Cloud-init/iperf.yaml

    echo "iperf 서버 파드 정보:"
    kubectl get pods | grep iperf

    echo -e "\n서버 파드에 접속하여 다음 명령어 실행: /usr/bin/iperf3 -s -p 5202"
    echo "클라이언트 파드에 접속하여 다음 명령어 실행: /usr/bin/iperf3 -c [서버파드IP] -p 5202 -P 32 -t 10"
    echo -e "\n(파드에 접속하려면: kubectl exec -it [pod-name] -- /bin/bash)"
    echo -e "\n파드 IP 확인 방법: kubectl get pods -o wide"

    echo "iperf 설정 완료"
}

# 공통 설치 과정
common_setup() {
    install_cuda
    install_cudnn
    install_docker
    install_nvidia_docker
    setup_prerequisites
    install_kubernetes
    pull_docker_images
    setup_bandwidth_limit
}

if [[ "$NODE_TYPE" == "master" ]]; then
    echo "마스터 노드 설정을 시작합니다..."
    common_setup
    setup_master_node  # de 함수 대신 setup_master_node 사용
    # 이미 setup_master_node에서 flannel을 설치했으므로 아래 라인은 선택적으로 주석 처리
    # install_flannel
    install_nvidia_device_plugin
    fix_gpu_issues
    setup_node_selector
    install_training_operator
    setup_pv_pvc
    setup_iperf
    echo "마스터 노드 설정이 완료되었습니다."
    echo "워커 노드 조인 명령어를 확인하세요: ~/worker_join_command.txt"
fi

# 워커 노드 설정
if [[ "$NODE_TYPE" == "worker" ]]; then
    echo "워커 노드 설정을 시작합니다..."
    common_setup
    setup_worker_node
    fix_gpu_issues
    echo "워커 노드 설정이 완료되었습니다."
    echo "마스터 노드에서 제공한 join 명령어를 실행하세요."
fi

echo "================= Lambda Labs Setup 완료 ================="
