#!/bin/bash
TFPATH="/home/tensorspot/Cloud-init"
MAX_RETRY_PER_JOB=5  # 각 작업당 최대 재시도 횟수

echo "$(date '+%Y-%m-%d %H:%M:%S') - YAML 기반 Pod 정리 스크립트 시작됨"

# 실패한 작업들을 추적하는 연관배열
declare -A FAILED_JOBS
declare -A RETRY_COUNTS

# YAML 기반 삭제 함수
try_delete_job() {
    local job_name=$1
    local yaml_file="${TFPATH}/net_script/${job_name}_spot.yaml"
    
    if [ ! -f "$yaml_file" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - 경고: YAML 파일 없음 - $yaml_file"
        return 1
    fi
    
    # 현재 재시도 횟수 증가
    RETRY_COUNTS[$job_name]=$((${RETRY_COUNTS[$job_name]:-0} + 1))
    local current_retry=${RETRY_COUNTS[$job_name]}
    
    echo "$(date '+%Y-%m-%d %H:%M:%S') - 작업 $job_name YAML 삭제 시도 $current_retry/$MAX_RETRY_PER_JOB: $yaml_file"
    
    # YAML 파일로 삭제
    kubectl delete -f "$yaml_file" --timeout=10s
    local delete_result=$?
    
    # 삭제 후 잠시 대기
    sleep 1
    
    # 관련 Pod가 모두 사라졌는지 확인
    local remaining_pods=$(kubectl get pod 2>/dev/null | grep -E "${job_name}" | grep -E "(controller-|chief-|worker-)" | wc -l)
    
    if [ $delete_result -eq 0 ] && [ $remaining_pods -eq 0 ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - 작업 $job_name 삭제 성공 (시도: $current_retry)"
        # 성공하면 추적에서 제거
        unset FAILED_JOBS[$job_name]
        unset RETRY_COUNTS[$job_name]
        return 0
    elif [ $remaining_pods -eq 0 ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - 작업 $job_name Pod 정리 완료 (시도: $current_retry)"
        # 성공하면 추적에서 제거
        unset FAILED_JOBS[$job_name]
        unset RETRY_COUNTS[$job_name]
        return 0
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') - 작업 $job_name 삭제 미완료, 남은 Pod: $remaining_pods개 (시도: $current_retry)"
        
        if [ $current_retry -ge $MAX_RETRY_PER_JOB ]; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') - 작업 $job_name 최대 재시도 초과, 추적에서 제거"
            unset FAILED_JOBS[$job_name]
            unset RETRY_COUNTS[$job_name]
            return 1
        else
            # 실패한 작업으로 등록
            FAILED_JOBS[$job_name]=1
            return 1
        fi
    fi
}

while true; do
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Completed 상태 Pod 확인 중..."
    
    # 새로 발견한 Completed Pod들
    COMPLETED_PODS=$(kubectl get pod 2>/dev/null | grep -E "(controller-|chief-|worker-)" | grep Completed | awk '{print $1}')
    
    # 처리할 작업 목록 (새로운 것 + 이전 실패한 것들)
    JOBS_TO_PROCESS=""
    
    # 새로 발견한 Completed Pod에서 작업 이름 추출
    if [ -n "$COMPLETED_PODS" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - 새로운 Completed 상태 Pod 발견: $(echo $COMPLETED_PODS | wc -w)개"
        
        for pod in $COMPLETED_PODS; do
            # 작업 이름 추출
            JOB_NAME=$(echo $pod | awk -F '-' '{
                jobname = $1
                for (i = 2; i <= NF - 2; i++) {
                    jobname = jobname "_" $i
                }
                print jobname
            }')
            
            # 중복 방지하며 추가
            if [[ ! " $JOBS_TO_PROCESS " =~ " $JOB_NAME " ]]; then
                JOBS_TO_PROCESS="$JOBS_TO_PROCESS $JOB_NAME"
            fi
        done
    fi
    
    # 이전에 실패한 작업들도 추가
    for failed_job in "${!FAILED_JOBS[@]}"; do
        if [[ ! " $JOBS_TO_PROCESS " =~ " $failed_job " ]]; then
            JOBS_TO_PROCESS="$JOBS_TO_PROCESS $failed_job"
        fi
    done
    
    # 처리할 작업이 있는 경우
    if [ -n "$JOBS_TO_PROCESS" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - 처리할 작업: $(echo $JOBS_TO_PROCESS | wc -w)개"
        
        for job_name in $JOBS_TO_PROCESS; do
            if [ -n "$job_name" ]; then
                try_delete_job "$job_name"
            fi
        done
        
        # 현재 추적 중인 실패 작업 수 출력
        local failed_count=${#FAILED_JOBS[@]}
        if [ $failed_count -gt 0 ]; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') - 추적 중인 실패 작업: $failed_count개 ($(echo ${!FAILED_JOBS[@]}))"
        fi
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Completed 상태 Pod 및 실패 작업 없음"
    fi
    
    echo "$(date '+%Y-%m-%d %H:%M:%S') - 3초 후 다시 확인"
    sleep 3
done
