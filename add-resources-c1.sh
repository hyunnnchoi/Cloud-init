#!/bin/bash

# 기본 대역폭 값 설정
BANDWIDTH="4000"

# 사용법 함수
usage() {
  echo "사용법: $0 [-b 대역폭]"
  echo "옵션:"
  echo "  -b 대역폭    설정할 대역폭 값 (기본값: 1000)"
  exit 1
}

# 명령줄 인자 처리
while getopts ":b:h" opt; do
  case ${opt} in
    b )
      BANDWIDTH="$OPTARG"
      ;;
    h )
      usage
      ;;
    \? )
      echo "알 수 없는 옵션: -$OPTARG"
      usage
      ;;
    : )
      echo "옵션 -$OPTARG에 인자가 필요합니다."
      usage
      ;;
  esac
done

echo "대역폭 값: $BANDWIDTH"

# 프록시 시작 (백그라운드에서 실행)
echo "쿠버네티스 API 서버 프록시를 시작합니다..."
kubectl proxy &
PROXY_PID=$!

# 프록시가 시작될 때까지 잠시 대기
sleep 3

# 노드 리스트 - 클러스터1
NODES=("xsailor-master" "xsailor-worker1")
# 추가할 리소스 유형
RESOURCES=("internet" "externet")
# 리소스 값 (명령줄에서 입력받은 값)
VALUE="$BANDWIDTH"

echo "클러스터1 노드에 리소스를 추가합니다..."

# 각 노드에 리소스 추가
for NODE in "${NODES[@]}"; do
  for RESOURCE in "${RESOURCES[@]}"; do
    echo "노드 $NODE에 $RESOURCE 리소스를 추가합니다..."
    
    # JSON 패치 적용
    curl --silent --header "Content-Type: application/json-patch+json" \
      --request PATCH \
      --data "[{\"op\": \"add\", \"path\": \"/status/capacity/example.com~1$RESOURCE\", \"value\": \"$VALUE\"}]" \
      http://localhost:8001/api/v1/nodes/$NODE/status
    
    # 결과 코드 확인
    if [ $? -eq 0 ]; then
      echo "✅ $NODE 노드에 $RESOURCE 리소스 추가 완료"
    else
      echo "❌ $NODE 노드에 $RESOURCE 리소스 추가 실패"
    fi
  done
done

# 프록시 종료
echo "프록시를 종료합니다..."
kill $PROXY_PID

echo "모든 작업이 완료되었습니다!"
