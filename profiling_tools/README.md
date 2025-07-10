## packet capture based compute time : network time profiling script

### prerequisites
- Place the measured `wireshark(.pcap)` files in the `/allreduce` directory
- The file structure should be as follows:

```tree
├── allreduce
│   ├── id0_cifar10_alexnet_sync_batch8192
│   │   ├── worker_0_10.244.0.54_network.pcap
│   │   └── worker_1_10.244.0.53_network.pcap
│   ├── id1_cifar10_alexnet_sync_batch16384
│   │   ├── worker_0_10.244.0.55_network.pcap
│   │   ├── worker_1_10.244.0.57_network.pcap
│   │   ├── worker_2_10.244.0.59_network.pcap
│   │   └── worker_3_10.244.0.58_network.pcap
│   ...
└── ar_csv
```

### usage

#### 1. `.pcap` parsing
```bash
python3 ar_network_pool_macOS.py
```

- CSV files corresponding to the pcap files will be generated in the `ar_csv` folder
- Currently, only pcap files corresponding to `worker_0` are analyzed to prevent duplicate calculations
- Output example:
  - `id0_cifar10_alexnet_sync_batch8192_worker_0_10.244.0.54_network.csv`
  - `id1_cifar10_alexnet_sync_batch16384_worker_0_10.244.0.17_network.csv`
- The generated CSV files aggregate communication volume in 0.01-second intervals
- **Note**: The command for multiprocessing is written for macOS. For other operating systems, please modify accordingly.

#### 2. CSV-based compute: network time analysis
```bash
python3 commtime_v3.py
```

- Outputs avg compute time and network time based on the CSV files
- Based on the set threshold:
  - Intervals (0.01-second units) above the threshold are classified as network time
  - Intervals below the threshold are classified as compute time
- Calculates cumulative sum and divides by the number of iterations to return avg compute time and network time
- Results are saved in the `comm_time_v3.csv` file

### notes
- The `comm_time_v3.csv` file cannot be used directly as simulator profiling input
- Parse GPU count, model name, etc., according to the format and convert it to simulator profiling input

---

## packet capture 기반 compute time : network time 프로파일링 스크립트

### Prerequisite
- `/allreduce` 디렉토리에 측정된 `wireshark(.pcap)` 파일을 넣어주세요
- 파일 구조는 다음과 같습니다:

```tree
├── allreduce
│   ├── id0_cifar10_alexnet_sync_batch8192
│   │   ├── worker_0_10.244.0.54_network.pcap
│   │   └── worker_1_10.244.0.53_network.pcap
│   ├── id1_cifar10_alexnet_sync_batch16384
│   │   ├── worker_0_10.244.0.55_network.pcap
│   │   ├── worker_1_10.244.0.57_network.pcap
│   │   ├── worker_2_10.244.0.59_network.pcap
│   │   └── worker_3_10.244.0.58_network.pcap
│   ...
└── ar_csv
```

### 사용 방법

#### 1. `.pcap` 파싱
```bash
python3 ar_network_pool_macOS.py
```

- `ar_csv` 폴더에 해당 pcap 파일에 대응하는 csv 파일이 생성됩니다
- 현재는 중복 계산을 방지하기 위해 `worker_0`에 해당하는 pcap 파일만 분석합니다
- 출력 예시: 
  - `id0_cifar10_alexnet_sync_batch8192_worker_0_10.244.0.54_network.csv`
  - `id1_cifar10_alexnet_sync_batch16384_worker_0_10.244.0.17_network.csv`
- 생성된 csv 파일은 0.01초 단위로 통신량을 집계합니다
- **Note**: 현재 멀티프로세싱을 위한 명령어는 macOS를 기준으로 작성되었습니다. 다른 운영체제를 사용하는 경우, 알맞게 변환하여 사용해주세요.

#### 2. CSV 파일 기반 Compute: Network Time 분석
```bash
python3 commtime_v3.py
```

- 해당 csv 파일을 기반으로 avg compute time과 avg network time을 출력합니다
- 설정된 threshold를 기준으로:
  - threshold 이상인 구간(0.01초 단위)은 network time으로 분류
  - threshold 미만인 구간은 compute time으로 분류
- 누적합을 계산한 후, iteration 수로 나누어 평균 compute time과 network time을 반환합니다
- 결과는 `comm_time_v3.csv` 파일로 저장됩니다

### 주의사항
- `comm_time_v3.csv` 파일은 시뮬레이터의 profiling input으로 바로 사용할 수 없습니다
- GPU 개수, 모델명 등을 양식에 맞게 파싱한 후 시뮬레이터의 profiling input으로 변환해주세요

