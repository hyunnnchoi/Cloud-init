#!/bin/bash
# Job 파일들이 있는 경로 설정
JOB_DIR="./"
# Job 파일들의 이름 패턴 (id*.yaml 순서대로 실행)
JOB_FILES=($(ls ${JOB_DIR}id*.yaml | sort -V))
# 모든 Job 파일 순서대로 실행
for job_file in "${JOB_FILES[@]}"; do
    # 현재 실행 중인 Job의 이름 출력
    echo "Running job: ${job_file}"
    # 현재 Job 실행
    kubectl create -f "${job_file}"
    # Job 번호 추출 (id{번호} 부분만 가져옴)
    job_number=$(basename "${job_file}" .yaml | grep -oE '^id[0-9]+')
    # controller Pod가 Completed 상태가 될 때까지 대기
    while true; do
        # 디버깅: 현재 Job 관련 모든 Pod 상태 출력
        echo "Debug: Checking all pods related to job ${job_number}"
        kubectl get pods --no-headers | grep "${job_number}"
        # Completed 상태의 controller 또는 chief Pod 확인
        COMPLETED_CONTROLLERS=$(kubectl get pods --no-headers | grep "${job_number}" | grep -E "(controller|chief)" | grep "Completed" | wc -l)
        TOTAL_CONTROLLERS=$(kubectl get pods --no-headers | grep "${job_number}" | grep -E "(controller|chief)" | wc -l)
        echo "Debug: Completed controllers/chiefs: ${COMPLETED_CONTROLLERS} / Total controllers/chiefs: ${TOTAL_CONTROLLERS}"
        # controller 또는 chief Pod가 Completed 상태인지 확인
        if [ "${COMPLETED_CONTROLLERS}" -eq "${TOTAL_CONTROLLERS}" ] && [ "${TOTAL_CONTROLLERS}" -gt 0 ]; then
            echo "Controller or chief pod for job ${job_number} is Completed."
            # 현재 Job 삭제
            echo "Deleting job: ${job_file}"
            kubectl delete -f "${job_file}"
            # 다음 Job 실행 전 30초 대기
            echo "Waiting 30 seconds before next job..."
            sleep 30
            break
        fi
        # 대기
        echo "Waiting for controller or chief pod of job ${job_number} to complete..."
        sleep 5
    done
done
