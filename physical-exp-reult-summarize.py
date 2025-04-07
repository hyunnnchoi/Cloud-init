import pandas as pd
import numpy as np
import os
import re
import cProfile
import pstats

# Define the schedulers
schedulers = ["k8s", "spot", "colo", "vol", "binpack"]
path_dir = './data'  # 새 데이터 디렉토리 경로

# 모델 정의 업데이트
models = (
    "densenet40_k12", "densenet100_k12", "densenet100_k24",
    "resnet20", "resnet20_v2", "resnet32", "resnet32_v2", "resnet44", "resnet44_v2",
    "resnet56", "resnet56_v2", "resnet110", "resnet110_v2",
    "alexnet", "overfeat", "inception3", "inception4",
    "resnet50", "resnet50_v2", "resnet101", "resnet101_v2", "resnet152", "resnet152_v2",
    "googlenet", "vgg11", "vgg16", "vgg19", "bert", "gpt2", "gpt2m", "gpt2l", "gpt2xl", "bertl"
)

# 하이퍼파라미터 패턴 업데이트
param_pattern = re.compile(r'(batch\d+|use_fp16|optMomentum|optRmsprop|dataFormat|winograd|xla)')
model_pattern = re.compile(r'(densenet40_k12|densenet100_k12|densenet100_k24|resnet20(_v2)?|resnet32(_v2)?|resnet44(_v2)?|resnet56(_v2)?|resnet110(_v2)?|alexnet|overfeat|inception3|inception4|resnet50(_v2)?|resnet101(_v2)?|resnet152(_v2)?|googlenet|vgg11|vgg16|vgg19|bert|gpt2|gpt2m|gpt2l|gpt2xl|bertl)')

def extract_model_from_folder(folder_name):
    """폴더 이름에서 모델명 추출"""
    for model in models:
        if model in folder_name:
            return model
    return None

def extract_dataset_from_folder(folder_name):
    """폴더 이름에서 데이터셋 추출"""
    datasets = ["cifar10", "imagenet", "squad", "imdb"]
    for dataset in datasets:
        if dataset in folder_name:
            return dataset
    return None

def extract_sync_async_and_hparam(folder_name):
    """폴더 이름에서 동기/비동기 방식과 하이퍼파라미터 추출"""
    if "sync" in folder_name:
        sync_async = "sync"
    elif "async" in folder_name:
        sync_async = "async"
    else:
        sync_async = None

    h_param = re.search(r'batch\d+', folder_name)
    if h_param:
        h_param = h_param.group(0)
    else:
        h_param = None

    return sync_async, h_param

def get_job_info_from_folder(folder_name):
    """폴더 이름에서 작업 정보 추출"""
    parts = folder_name.split('_')
    job_id = parts[0]
    dataset = extract_dataset_from_folder(folder_name)
    model = extract_model_from_folder(folder_name)
    sync_async, h_param = extract_sync_async_and_hparam(folder_name)

    return {
        'job_id': job_id,
        'dataset': dataset,
        'model': model,
        'sync_async': sync_async,
        'h_param': h_param
    }

def parse_timestamp_file(file_path):
    """타임스탬프 파일 파싱"""
    try:
        with open(file_path, 'r') as f:
            timestamp_str = f.read().strip()
            if ':' in timestamp_str:  # HH:MM:SS 형식
                return sum(float(x) * 60 ** i for i, x in enumerate(reversed(timestamp_str.split(":"))))
            else:  # 유닉스 타임스탬프 형식
                return float(timestamp_str)
    except Exception as e:
        print(f"Error parsing timestamp file {file_path}: {e}")
        return None

def parse_cpu_file(file_path):
    """CPU 파일 파싱"""
    try:
        if os.path.getsize(file_path) == 0:
            return None

        df = pd.read_csv(file_path, delim_whitespace=True, header=None)
        if df.empty:
            return None

        # 적절한 CPU 사용량 컬럼 선택 (일반적으로 8번 컬럼)
        cpu_col = 8 if len(df.columns) > 8 else len(df.columns) - 1
        avg_cpu = df[cpu_col].mean()
        max_cpu = df[cpu_col].max()

        return {
            'avg_cpu': avg_cpu,
            'max_cpu': max_cpu
        }
    except Exception as e:
        print(f"Error parsing CPU file {file_path}: {e}")
        return None

def parse_gpu_file(file_path):
    """GPU 파일 파싱"""
    try:
        gpu_utilization = []
        with open(file_path, 'r') as f:
            lines = f.readlines()
            for line in lines:
                if 'GPU Util' in line:
                    matches = re.findall(r'GPU Util: (\d+)', line)
                    for match in matches:
                        gpu_utilization.append(int(match))

        if gpu_utilization:
            return {
                'avg_gpu': np.mean(gpu_utilization),
                'max_gpu': np.max(gpu_utilization)
            }
        return None
    except Exception as e:
        print(f"Error parsing GPU file {file_path}: {e}")
        return None

def parse_log_file(file_path):
    """로그 파일 파싱"""
    try:
        with open(file_path, 'r') as f:
            content = f.read()

        # 필요한 정보 추출 로직 (프로젝트별로 다를 수 있음)
        # 예: 훈련 속도, 손실 값 등

        return {
            # 추출된 메트릭 저장
        }
    except Exception as e:
        print(f"Error parsing log file {file_path}: {e}")
        return None

def analyze_job_folder(folder_path, job_info):
    """작업 폴더 분석"""
    results = {
        'job_id': job_info['job_id'],
        'dataset': job_info['dataset'],
        'model': job_info['model'],
        'sync_async': job_info['sync_async'],
        'h_param': job_info['h_param']
    }

    files = os.listdir(folder_path)

    # 시작/종료 시간 파일 탐색
    start_time_files = [f for f in files if 'start_time' in f]
    end_time_files = [f for f in files if 'end_time' in f]

    # 작업 시작 시간 (가장 빠른 시작 시간 선택)
    start_times = []
    for start_file in start_time_files:
        start_time = parse_timestamp_file(os.path.join(folder_path, start_file))
        if start_time:
            start_times.append(start_time)

    if start_times:
        results['start_time'] = min(start_times)

    # 작업 종료 시간 (가장 늦은 종료 시간 선택)
    end_times = []
    for end_file in end_time_files:
        end_time = parse_timestamp_file(os.path.join(folder_path, end_file))
        if end_time:
            end_times.append(end_time)

    if end_times:
        results['end_time'] = max(end_times)

    # JCT (Job Completion Time) 계산
    if 'start_time' in results and 'end_time' in results:
        results['jct'] = results['end_time'] - results['start_time']

    # CPU 사용량 파일 분석
    cpu_files = [f for f in files if 'cpu.txt' in f]
    cpu_metrics = []

    for cpu_file in cpu_files:
        cpu_data = parse_cpu_file(os.path.join(folder_path, cpu_file))
        if cpu_data:
            cpu_metrics.append(cpu_data)

    if cpu_metrics:
        results['avg_cpu'] = np.mean([m['avg_cpu'] for m in cpu_metrics])
        results['max_cpu'] = np.max([m['max_cpu'] for m in cpu_metrics])

    # GPU 사용량 파일 분석
    gpu_files = [f for f in files if 'gpu.txt' in f]
    gpu_metrics = []

    for gpu_file in gpu_files:
        gpu_data = parse_gpu_file(os.path.join(folder_path, gpu_file))
        if gpu_data:
            gpu_metrics.append(gpu_data)

    if gpu_metrics:
        results['avg_gpu'] = np.mean([m['avg_gpu'] for m in gpu_metrics])
        results['max_gpu'] = np.max([m['max_gpu'] for m in gpu_metrics])

    return results

def main():
    # 최종 결과 저장할 디렉토리 생성
    final_dir = os.path.join(os.path.dirname(path_dir), 'results')
    if not os.path.exists(final_dir):
        os.makedirs(final_dir)

    # 데이터 폴더 내 모든 작업 폴더 분석
    job_folders = [f for f in os.listdir(path_dir) if os.path.isdir(os.path.join(path_dir, f)) and f.startswith('id')]

    # 결과 저장할 DataFrame 초기화
    df_jobs = pd.DataFrame(columns=[
        'job_id', 'dataset', 'model', 'sync_async', 'h_param',
        'start_time', 'end_time', 'jct', 'avg_cpu', 'max_cpu', 'avg_gpu', 'max_gpu'
    ])

    # 각 작업 폴더 분석
    for job_folder in job_folders:
        folder_path = os.path.join(path_dir, job_folder)
        job_info = get_job_info_from_folder(job_folder)

        job_results = analyze_job_folder(folder_path, job_info)
        df_jobs = pd.concat([df_jobs, pd.DataFrame([job_results])], ignore_index=True)

    # 결과 저장
    df_jobs.to_csv(os.path.join(final_dir, 'job_analysis.csv'), index=False)

    # 모델별 성능 분석
    df_model_perf = df_jobs.groupby(['model', 'h_param']).agg({
        'jct': ['mean', 'min', 'max'],
        'avg_cpu': 'mean',
        'max_cpu': 'max',
        'avg_gpu': 'mean',
        'max_gpu': 'max'
    }).reset_index()

    df_model_perf.columns = ['model', 'h_param',
                            'avg_jct', 'min_jct', 'max_jct',
                            'avg_cpu', 'max_cpu', 'avg_gpu', 'max_gpu']

    df_model_perf.to_csv(os.path.join(final_dir, 'model_performance.csv'), index=False)

    # 데이터셋별 성능 분석
    df_dataset_perf = df_jobs.groupby(['dataset', 'model']).agg({
        'jct': ['mean', 'min', 'max']
    }).reset_index()

    df_dataset_perf.columns = ['dataset', 'model', 'avg_jct', 'min_jct', 'max_jct']
    df_dataset_perf.to_csv(os.path.join(final_dir, 'dataset_performance.csv'), index=False)

    print(f"Analysis complete. Results saved to {final_dir}")

if __name__ == '__main__':
    main()
