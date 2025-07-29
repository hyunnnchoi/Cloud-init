import os
import re
import csv
import glob

def time_to_seconds(time_str):
    """
    시간 문자열(HH:MM:SS.microseconds)을 초 단위로 변환합니다.
    """
    try:
        # 'HH:MM:SS.fraction' 형식 파싱
        parts = time_str.strip().split(':')
        
        if len(parts) != 3:
            print(f"예상치 못한 시간 형식: {time_str}")
            return None
            
        hours = int(parts[0])
        minutes = int(parts[1])
        
        # 초와 마이크로초 부분 처리
        if '.' in parts[2]:
            sec_parts = parts[2].split('.')
            seconds = int(sec_parts[0])
            # 마이크로초를 초 단위로 변환
            microseconds = float('0.' + sec_parts[1])
        else:
            seconds = int(parts[2])
            microseconds = 0
            
        # 총 초 계산
        total_seconds = hours * 3600 + minutes * 60 + seconds + microseconds
        return total_seconds
        
    except Exception as e:
        print(f"시간 변환 오류 ({time_str}): {e}")
        return None

def format_seconds(seconds):
    """
    초를 HH:MM:SS 형식으로 변환합니다.
    """
    hours = int(seconds // 3600)
    minutes = int((seconds % 3600) // 60)
    secs = seconds % 60
    
    if isinstance(secs, int) or secs.is_integer():
        return f"{hours:02d}:{minutes:02d}:{int(secs):02d}"
    else:
        return f"{hours:02d}:{minutes:02d}:{secs:.6f}"

def natural_sort_key(s):
    """
    자연스러운 정렬을 위한 키 함수입니다.
    'id10'이 'id2' 뒤에 오도록 합니다.
    """
    return [int(text) if text.isdigit() else text.lower() for text in re.split(r'(\d+)', s)]

def calculate_jct():
    """
    각 Job의 JCT를 계산합니다.
    """
    data_dir = "data"
    results = []

    # 모든 폴더 찾기
    job_dirs = [d for d in os.listdir(data_dir) if os.path.isdir(os.path.join(data_dir, d))]
    
    # ID로 정렬
    job_dirs.sort(key=natural_sort_key)
    
    for job_dir in job_dirs:
        job_id_match = re.search(r'id(\d+)', job_dir)
        if job_id_match:
            job_id = f"id{job_id_match.group(1)}"
        else:
            job_id = job_dir
            
        print(f"처리 중: {job_id}")
        job_path = os.path.join(data_dir, job_dir)
        
        # worker start time 파일 찾기
        start_time_files = glob.glob(os.path.join(job_path, "*worker*start_time.txt"))
        
        # end time 파일 찾기 - controller/chief 우선, 없으면 worker end time 사용
        end_time_files = glob.glob(os.path.join(job_path, "*controller*end_time.txt")) + \
                         glob.glob(os.path.join(job_path, "*chief*end_time.txt"))
        
        # controller/chief end time 파일이 없으면 worker end time 파일 사용 (1-GPU job 대응)
        if not end_time_files:
            end_time_files = glob.glob(os.path.join(job_path, "*worker*end_time.txt"))
            print(f"  controller/chief end time 파일이 없어서 worker end time 파일을 사용합니다.")
        
        if not start_time_files or not end_time_files:
            print(f"경고: {job_id}에 필요한 시간 파일이 없습니다.")
            print(f"  start_time_files: {start_time_files}")
            print(f"  end_time_files: {end_time_files}")
            continue
        
        # 모든 worker의 시작 시간 중 가장 빠른 시간 찾기
        earliest_start_seconds = None
        earliest_file = None
        
        for start_file in start_time_files:
            try:
                with open(start_file, 'r') as f:
                    time_str = f.read().strip()
                    start_seconds = time_to_seconds(time_str)
                    if start_seconds is not None and (earliest_start_seconds is None or start_seconds < earliest_start_seconds):
                        earliest_start_seconds = start_seconds
                        earliest_file = start_file
            except Exception as e:
                print(f"파일 읽기 오류 ({start_file}): {e}")
        
        # end time 찾기 (controller/chief 또는 worker)
        end_seconds = None
        end_file = None
        
        for end_file_path in end_time_files:
            try:
                with open(end_file_path, 'r') as f:
                    time_str = f.read().strip()
                    parsed_end_seconds = time_to_seconds(time_str)
                    if parsed_end_seconds is not None:
                        end_seconds = parsed_end_seconds
                        end_file = end_file_path
                        break
            except Exception as e:
                print(f"파일 읽기 오류 ({end_file_path}): {e}")
        
        if earliest_start_seconds is not None and end_seconds is not None:
            # JCT 계산 (종료 시간 - 시작 시간)
            jct_seconds = end_seconds - earliest_start_seconds
            
            # 디버깅용 출력
            print(f"  시작 시간(초): {earliest_start_seconds} (파일: {earliest_file})")
            print(f"  종료 시간(초): {end_seconds} (파일: {end_file})")
            print(f"  JCT(초): {jct_seconds}")
            
            # 결과 저장
            results.append({
                'job_id': job_id,
                'start_time_seconds': earliest_start_seconds,
                'end_time_seconds': end_seconds,
                'jct_seconds': jct_seconds,
                'jct_formatted': format_seconds(jct_seconds)
            })
        else:
            print(f"경고: {job_id}의 시작 또는 종료 시간을 파싱할 수 없습니다.")
            if earliest_start_seconds is not None:
                print(f"  시작 시간(초): {earliest_start_seconds}")
            else:
                print(f"  시작 시간: 파싱 실패")
            
            if end_seconds is not None:
                print(f"  종료 시간(초): {end_seconds}")
            else:
                print(f"  종료 시간: 파싱 실패")
    
    return results

def save_to_csv(results, output_file="job_results.csv"):
    """
    결과를 CSV 파일로 저장합니다.
    """
    if not results:
        print("저장할 결과가 없습니다.")
        return
    
    with open(output_file, 'w', newline='') as csvfile:
        fieldnames = ['job_id', 'start_time_seconds', 'end_time_seconds', 'jct_seconds', 'jct_formatted']
        writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
        
        writer.writeheader()
        for result in results:
            writer.writerow(result)
    
    print(f"결과가 {output_file}에 저장되었습니다.")

def main():
    print("실험 결과 정리를 시작합니다...")
    results = calculate_jct()
    
    if results:
        # 결과를 job_id로 정렬
        results.sort(key=lambda x: natural_sort_key(x['job_id']))
        
        save_to_csv(results)
        
        # 결과 출력
        print("\n계산된 JCT 결과:")
        print(f"{'Job ID':<10} {'Start Time(s)':<15} {'End Time(s)':<15} {'JCT (seconds)':<15} {'JCT (hh:mm:ss)'}")
        print("-" * 80)
        for result in results:
            print(f"{result['job_id']:<10} {result['start_time_seconds']:<15.3f} {result['end_time_seconds']:<15.3f} "
                f"{result['jct_seconds']:<15.3f} {result['jct_formatted']}")

if __name__ == "__main__":
    main()