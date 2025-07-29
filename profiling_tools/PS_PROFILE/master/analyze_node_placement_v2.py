#!/usr/bin/env python3
import os
import re
import csv
from pathlib import Path

def extract_workers_from_logs(directory_path):
    """
    주어진 디렉토리에서 로그 파일들을 스캔하여 chief와 worker 정보를 추출
    """
    workers = []
    
    if not os.path.exists(directory_path):
        return workers
    
    # 파일 목록이 없거나 접근이 불가능한 경우를 대비
    try:
        files = os.listdir(directory_path)
    except OSError:
        return workers

    for file in files:
        if file.endswith('_log.txt'):
            # chief_0_log.txt는 c0로 매핑
            if 'chief_0' in file:
                workers.append('c0')
            # controller는 일반적으로 TF 작업 관리자이므로 분석에서 제외
            elif 'controller' in file:
                continue
            # worker_N_log.txt는 wN으로 매핑
            elif re.match(r'.*worker_(\d+).*log\.txt', file):
                worker_match = re.search(r'worker_(\d+)', file)
                if worker_match:
                    worker_num = worker_match.group(1)
                    workers.append(f'w{worker_num}')
    
    return sorted(workers)

def analyze_single_folder(base_folder):
    """
    단일 폴더 (예: 0712_spot_v2)를 분석하여 노드 배치 정보 생성
    """
    results = []
    
    if not os.path.isdir(base_folder):
        print(f"오류: '{base_folder}' 폴더를 찾을 수 없습니다.")
        return results, []

    # base_folder 아래의 노드 디렉토리들 (master, worker1, worker2 등)을 동적으로 찾기
    node_dirs = sorted([d for d in os.listdir(base_folder) if os.path.isdir(os.path.join(base_folder, d))])
    
    if not node_dirs:
        print(f"오류: '{base_folder}' 폴더 아래에 노드 디렉토리가 없습니다.")
        return results, []

    # 모든 job_id 수집
    all_job_ids = set()
    for node in node_dirs:
        data_path = os.path.join(base_folder, node, 'data')
        if os.path.exists(data_path):
            for folder in os.listdir(data_path):
                if folder.startswith('id') and os.path.isdir(os.path.join(data_path, folder)):
                    job_id_match = re.match(r'id(\d+)_', folder)
                    if job_id_match:
                        all_job_ids.add(int(job_id_match.group(1)))

    # 각 job_id에 대해 노드 배치 분석
    for job_id in sorted(list(all_job_ids)):
        result_row = {'job_id': job_id}
        
        for node in node_dirs:
            node_workers = []
            data_path = os.path.join(base_folder, node, 'data')
            if os.path.exists(data_path):
                # 해당 job_id를 포함하는 폴더 찾기 (예: id10_...)
                job_folder_name = next((f for f in os.listdir(data_path) if f.startswith(f'id{job_id}_')), None)
                
                if job_folder_name:
                    folder_path = os.path.join(data_path, job_folder_name)
                    workers = extract_workers_from_logs(folder_path)
                    node_workers.extend(workers)
            
            result_row[node] = ','.join(sorted(node_workers)) if node_workers else ''
        
        results.append(result_row)
    
    return results, node_dirs

def main():
    """
    지정된 폴더를 분석하여 CSV 파일 생성
    """
    # 분석할 폴더를 '0712_spot_v2'로 고정
    folder_to_analyze = '_separated'
    
    print(f"=== '{folder_to_analyze}' 폴더 분석 중... ===")
    
    results, node_dirs = analyze_single_folder(folder_to_analyze)
    
    if results:
        # CSV 파일명 생성
        csv_filename = f"{folder_to_analyze}_node_allocation.csv"
        
        # CSV 파일 작성
        # 필드 이름은 job_id와 동적으로 찾은 노드 디렉토리 이름으로 구성
        fieldnames = ['job_id'] + node_dirs
        
        with open(csv_filename, 'w', newline='', encoding='utf-8') as csvfile:
            writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
            
            writer.writeheader()
            for row in results:
                writer.writerow(row)
        
        print(f"\n결과가 '{csv_filename}'에 저장되었습니다.")
        print(f"총 {len(results)}개의 job_id가 분석되었습니다.")
        
        # 간단한 미리보기 출력
        print("\n미리보기 (처음 5개):")
        for i, row in enumerate(results[:5]):
            preview = f"  Job {row['job_id']}: "
            node_previews = []
            for node in node_dirs:
                if row.get(node):
                    node_previews.append(f"{node}=[{row[node]}]")
            preview += ', '.join(node_previews)
            print(preview)
            
        if len(results) > 5:
            print(f"  ... (총 {len(results)}개)")
    else:
        print(f"'{folder_to_analyze}'에서 분석할 데이터를 찾을 수 없습니다.")

if __name__ == "__main__":
    main()
