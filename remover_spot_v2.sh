#!/bin/bash
TFPATH="/home/tensorspot/Cloud-init"
DELETION_TIMEOUT=30  # 삭제 대기 시간 (초)

echo "$(date '+%Y-%m-%d %H:%M:%S') - Pod 정리 스크립트 시작됨"

# TFJob이 완전히 삭제될 때까지 대기하는 함수
wait_for_tfjob_deletion() {
    local job_name=$1
    local timeout=$2
    local start_time=$(date +%s)
    
    echo "$(date '+%Y-%m-%d %H:%M:%S') - TFJob $job_name 삭제 완료 대기 중..."
    
    while true; do
        # TFJob 존재 여부 확인
        if ! kubectl get tfjob $job_name >/dev/null 2>&1; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') - TFJob $job_name 삭제 완료 확인"
            return 0
        fi
        
        # 해당 TFJob의 모든 Pod 확인
        local remaining_pods=$(kubectl get pod -l tf-job-name=$job_name 2>/dev/null | grep -v NAME | wc -l)
        if [ "$remaining_pods" -eq 0 ]; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') - TFJob $job_name 의 모든 Pod 삭제 완료"
            return 0
        fi
        
        # 타임아웃 확인
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        if [ $elapsed -ge $timeout ]; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') - TFJob $job_name 삭제 대기 시간 초과 (${timeout}초)"
            return 1
        fi
        
        echo "$(date '+%Y-%m-%d %H:%M:%S') - TFJob $job_name 삭제 대기 중... (남은 Pod: $remaining_pods개, 경과시간: ${elapsed}초)"
        sleep 2
    done
}



# TFJob을 즉시 삭제하는 함수
safe_delete_tfjob() {
    local job_name=$1
    
    echo "$(date '+%Y-%m-%d %H:%M:%S') - TFJob $job_name 삭제 시작"
    
    # TFJob 존재 여부 확인
    if ! kubectl get tfjob $job_name >/dev/null 2>&1; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - TFJob $job_name 이미 존재하지 않음"
        return 0
    fi
    
    # 삭제 전 관련 Pod 수 확인
    local initial_pod_count=$(kubectl get pod -l tf-job-name=$job_name 2>/dev/null | grep -v NAME | wc -l)
    echo "$(date '+%Y-%m-%d %H:%M:%S') - TFJob $job_name 관련 Pod 수: $initial_pod_count개"
    
    # Completed 상태 Pod는 바로 강제 삭제 (grace period 0)
    echo "$(date '+%Y-%m-%d %H:%M:%S') - TFJob $job_name 즉시 삭제 시도 (grace-period=0)"
    kubectl delete tfjob $job_name --force --grace-period=0 >/dev/null 2>&1
    
    # 삭제 완료 대기
    if wait_for_tfjob_deletion $job_name $DELETION_TIMEOUT; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - TFJob $job_name 삭제 성공"
        return 0
    fi
    
    # 실패 시 개별 Pod 정리
    echo "$(date '+%Y-%m-%d %H:%M:%S') - TFJob $job_name 삭제 실패, 개별 Pod 정리 시도"
    local remaining_pods=$(kubectl get pod -l tf-job-name=$job_name -o name 2>/dev/null)
    if [ -n "$remaining_pods" ]; then
        echo "$remaining_pods" | while read pod; do
            echo "$(date '+%Y-%m-%d %H:%M:%S') - $pod 개별 삭제 시도"
            kubectl delete $pod --force --grace-period=0 >/dev/null 2>&1
        done
    fi
    
    # 최종 확인
    sleep 3
    local final_pod_count=$(kubectl get pod -l tf-job-name=$job_name 2>/dev/null | grep -v NAME | wc -l)
    if [ "$final_pod_count" -eq 0 ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - TFJob $job_name 관련 모든 Pod 정리 완료"
        return 0
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') - 경고: TFJob $job_name 일부 Pod($final_pod_count개) 정리 실패"
        kubectl get pod -l tf-job-name=$job_name 2>/dev/null | grep -v NAME
        return 1
    fi
}

while true; do
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Completed 상태 Pod 확인 중..."
    
    # Completed 상태의 controller, chief, worker Pod 찾기
    COMPLETED_PODS=$(kubectl get pod | grep -E "(controller-|chief-|worker-)" | grep Completed | awk '{print $1}')
    
    if [ -n "$COMPLETED_PODS" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Completed 상태 Pod 발견: $(echo $COMPLETED_PODS | wc -w)개"
        
        # 중복 제거를 위해 TFJob 이름 추출
        TFJOB_NAMES=""
        for pod in $COMPLETED_PODS; do
            # TFJob 이름 추출 (Pod 라벨에서 확인)
            TFJOB_NAME=$(kubectl get pod $pod -o jsonpath='{.metadata.labels.tf-job-name}' 2>/dev/null)
            
            if [ -z "$TFJOB_NAME" ]; then
                # 라벨이 없는 경우 Pod 이름에서 추출
                TFJOB_NAME=$(echo $pod | awk -F '-' '{
                    jobname = $1
                    for (i = 2; i <= NF - 2; i++) {
                        jobname = jobname "_" $i
                    }
                    print jobname
                }')
            fi
            
            # 중복 제거
            if [[ ! " $TFJOB_NAMES " =~ " $TFJOB_NAME " ]]; then
                TFJOB_NAMES="$TFJOB_NAMES $TFJOB_NAME"
            fi
        done
        
        # 각 TFJob 삭제
        for tfjob_name in $TFJOB_NAMES; do
            if [ -n "$tfjob_name" ]; then
                safe_delete_tfjob "$tfjob_name"
            fi
        done
        
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Completed 상태 Pod 없음"
    fi
    
    echo "$(date '+%Y-%m-%d %H:%M:%S') - 3초 후 다시 확인"
    sleep 3
done
