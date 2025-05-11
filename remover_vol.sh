#!/bin/bash

TFPATH="/home/tensorspot/Cloud-init"
echo "$(date '+%Y-%m-%d %H:%M:%S') - Pod 정리 스크립트 시작됨"

while true; do
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Completed 상태 Pod 확인 중..."
  
  # Completed 상태의 controller 또는 chief Pod 찾기
  COMPLETED_PODS=$(kubectl get pod | grep -e "controller-" -e "chief-" | grep Completed | awk '{print $1}')
  
  if [ -n "$COMPLETED_PODS" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Completed 상태 Pod 발견: $(echo $COMPLETED_PODS | wc -w)개"
    
    for pod in $COMPLETED_PODS; do
      # 작업 이름 추출
      JOB_NAME=$(echo $pod | awk -F '-' '{
        jobname = $1
        for (i = 2; i <= NF - 2; i++) {
          jobname = jobname "_" $i
        }
        print jobname
      }')
      
      echo "$(date '+%Y-%m-%d %H:%M:%S') - 작업 $JOB_NAME (Pod: $pod) 삭제 시도"
      
      # 작업 삭제
      kubectl delete -f ${TFPATH}/net_script/${JOB_NAME}_vol.yaml
      
      # 삭제 확인
      if [ $? -eq 0 ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - 작업 $JOB_NAME 삭제 성공"
      else
        echo "$(date '+%Y-%m-%d %H:%M:%S') - 작업 $JOB_NAME YAML 삭제 실패, Pod 직접 삭제 시도"
        
        # YAML 파일로 삭제가 실패한 경우 Pod 직접 삭제
        JOB_NAME_DASH=$(echo $JOB_NAME | tr '_' '-')
        kubectl delete pod -l app=$JOB_NAME_DASH
        
        if [ $? -eq 0 ]; then
          echo "$(date '+%Y-%m-%d %H:%M:%S') - Pod 직접 삭제 성공"
        else
          echo "$(date '+%Y-%m-%d %H:%M:%S') - Pod 직접 삭제 실패, 다음 실행에서 다시 시도"
        fi
      fi
    done
  else
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Completed 상태 Pod 없음"
  fi
  
  echo "$(date '+%Y-%m-%d %H:%M:%S') - 10초 후 다시 확인"
  # 10초마다 확인
  sleep 10
done
