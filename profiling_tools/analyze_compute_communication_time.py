import pandas as pd
import os
import glob
from typing import Tuple

def analyze_single_csv(file_path: str) -> Tuple[float, float, float]:
    """
    단일 CSV 파일을 분석하여 연산 시간과 통신 시간을 계산
    
    Args:
        file_path: CSV 파일 경로
        
    Returns:
        (연산_시간, 통신_시간, 전체_시간)
    """
    try:
        # CSV 파일 읽기 - 헤더 정보 건너뛰기
        with open(file_path, 'r') as f:
            lines = f.readlines()
        
        # 실제 데이터가 시작하는 라인 찾기 (Time,BYTES,BYTES 이후)
        data_start_idx = None
        for i, line in enumerate(lines):
            if line.strip() == "Time,BYTES,BYTES":
                data_start_idx = i + 1
                break
        
        if data_start_idx is None:
            print(f"Warning: 데이터 시작점을 찾을 수 없습니다: {file_path}")
            return 0.0, 0.0, 0.0
        
        # 데이터 파싱
        compute_time = 0.0
        communication_time = 0.0
        time_interval = 0.01  # 0.01초 단위
        
        for line in lines[data_start_idx:]:
            line = line.strip()
            if not line:
                continue
                
            try:
                parts = line.split(',')
                if len(parts) != 3:
                    continue
                    
                time_val = float(parts[0])
                bytes_sent = int(parts[1])
                bytes_received = int(parts[2])
                
                # 통신량이 0,0인 경우 연산 시간으로 분류
                if bytes_sent == 0 and bytes_received == 0:
                    compute_time += time_interval
                else:
                    communication_time += time_interval
                    
            except (ValueError, IndexError):
                continue
        
        total_time = compute_time + communication_time
        return compute_time, communication_time, total_time
        
    except Exception as e:
        print(f"Error processing {file_path}: {e}")
        return 0.0, 0.0, 0.0

def extract_job_info(filename: str) -> Tuple[str, int]:
    """
    파일명에서 job 정보와 id 추출
    예: id28_cifar10_densenet40_k12_sync_batch8192_worker_0_10.244.0.186_network.csv
    -> ("id28_cifar10_densenet40_k12_sync_batch8192_worker_0", 28)
    """
    # .csv 제거하고 _network 제거
    base_name = filename.replace('_network.csv', '')
    # IP 주소 부분 제거 (마지막 _10.244.x.x 패턴)
    parts = base_name.split('_')
    # IP 주소는 보통 마지막 4개 부분 (10, 244, x, x)
    if len(parts) >= 4 and parts[-4] == '10' and parts[-3] == '244':
        job_info = '_'.join(parts[:-4])
    else:
        job_info = base_name
    
    # id 번호 추출 (예: id28 -> 28)
    id_num = 0
    if job_info.startswith('id'):
        try:
            # id 다음에 오는 숫자 찾기
            id_part = job_info.split('_')[0]  # id28
            id_num = int(id_part[2:])  # 28
        except (ValueError, IndexError):
            id_num = 0
    
    return job_info, id_num

def main():
    """
    메인 함수: 모든 CSV 파일을 분석하고 결과를 집계
    """
    # 현재 디렉토리에서 CSV 파일 찾기
    csv_dir = "."
    csv_files = glob.glob(os.path.join(csv_dir, "*.csv"))
    
    print(f"발견된 CSV 파일 수: {len(csv_files)}")
    
    results = []
    
    for csv_file in csv_files:
        filename = os.path.basename(csv_file)
        print(f"처리 중: {filename}")
        
        compute_time, communication_time, total_time = analyze_single_csv(csv_file)
        
        job_info, id_num = extract_job_info(filename)
        
        results.append({
            'id': id_num,
            'job_info': job_info,
            'compute_time': compute_time,
            'communication_time': communication_time,
            'total_time': total_time,
            'compute_ratio': compute_time / total_time if total_time > 0 else 0,
            'communication_ratio': communication_time / total_time if total_time > 0 else 0
        })
        
        print(f"  ID: {id_num}, 연산 시간: {compute_time:.2f}초, 통신 시간: {communication_time:.2f}초, 전체: {total_time:.2f}초")
    
    # 결과를 DataFrame으로 변환
    df = pd.DataFrame(results)
    
    # 결과 정렬 (id 기준으로 먼저, 그다음 job_info 기준)
    df = df.sort_values(['id', 'job_info'])
    
    # CSV로 저장
    output_file = "compute_communication_analysis.csv"
    df.to_csv(output_file, index=False)
    
    print(f"\n분석 완료! 결과가 {output_file}에 저장되었습니다.")
    print(f"\n요약 통계:")
    print(f"총 분석된 파일 수: {len(results)}")
    print(f"평균 연산 시간: {df['compute_time'].mean():.2f}초")
    print(f"평균 통신 시간: {df['communication_time'].mean():.2f}초")
    print(f"평균 연산 비율: {df['compute_ratio'].mean():.3f}")
    print(f"평균 통신 비율: {df['communication_ratio'].mean():.3f}")
    
    # 상위 5개 결과 출력
    print(f"\n상위 5개 결과:")
    print(df.head().to_string(index=False))

if __name__ == "__main__":
    main() 
