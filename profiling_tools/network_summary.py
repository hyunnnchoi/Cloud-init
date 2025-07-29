import pandas as pd
import os
import re
import io

# True for PS, False for AR
is_PS = False
# is_PS = False

def find_max_tx_rx(file_path):
    # CSV 파일 읽기
    with open(file_path, 'r') as file:
        content = file.read()

    # 'Dur' 행을 찾아서 그 이전까지의 내용만 사용
    dur_index = content.find('Dur,')
    if dur_index != -1:
        content = content[:dur_index]

    # StringIO를 사용하여 문자열을 파일처럼 읽기
    df = pd.read_csv(io.StringIO(content), header=0)

    # 'Time' 열을 숫자로 변환
    df['Time'] = pd.to_numeric(df['Time'], errors='coerce')

    # tx와 rx 열 이름 가져오기
    tx_column = [col for col in df.columns if col.endswith('_tx')][0]
    rx_column = [col for col in df.columns if col.endswith('_rx')][0]

    # 'tx+rx' 열 추가
    df['tx+rx'] = df[tx_column].astype(int) + df[rx_column].astype(int)

    # 'tx+rx' 열의 최댓값 찾기
    max_tx_rx = df['tx+rx'].max()

    return max_tx_rx

# Start Here
if is_PS:
    dir_path = './ps_csv'
    num_jobs = 40
else:
    dir_path = './ar_csv'
    num_jobs = 48

df_summary =  pd.DataFrame(columns=['Job ID', 'Data Set', 'Model', 'Sync/Async', 'Batch Size', 'Sum of Max TX+RX (B/s)', 'Sum of Max TX+RX (MB/s)'])

file_list = [file for file in os.listdir(dir_path) if file.endswith('_network.csv')]
print(file_list)

for job_id in range(num_jobs):

    if is_PS:
        pattern = f'id{job_id}_.*_ps_.*_network\.csv$' # ps
    else:
        pattern = f'id{job_id}_.*_network\.csv$' # ar

    task_file_list = [file for file in file_list if re.match(pattern, file)]
    print(f'id{job_id} list: {task_file_list}')
    # e.g. id0_cifar10_densenet100_k12_sync_batch32_controller_0_10.244.1.140_network.csv
    max_tx_rxs = [find_max_tx_rx(os.path.join(dir_path, task_file)) for task_file in task_file_list]
    max_tx_rx = sum(max_tx_rxs)

    if len(task_file_list):
        file = task_file_list[0]
    else:
        print(f'{job_id} is single job')
        continue
    parts = file.split('_')
    #job_id = parts[0].lstrip('id')          # 0
    dataset = parts[1]                      # cifar10
    #ip = parts[-2]                          # 10.244.1.140
    #index = parts[-3]                       # 0
    #task = parts[-4]                        # controller
    batch_size = parts[-5].lstrip('batch')  # 32
    sync_async = parts[-6]                  # sync
    model = '_'.join(parts[2:-6])                     # densenet100_k12

    new_row = {
                'Job ID': job_id,
                'Data Set': dataset,
                'Model': model,
                'Sync/Async': sync_async,
                'Batch Size': batch_size,
                'Sum of Max TX+RX (B/s)': max_tx_rx,
                'Sum of Max TX+RX (MB/s)': max_tx_rx / 1024 / 1024
            }
    df_summary = pd.concat([df_summary, pd.DataFrame([new_row])], ignore_index=True)

if is_PS:
    df_summary.to_csv('./ps_network_summary.csv', index=False)
else:
    df_summary.to_csv('./ar_network_summary.csv', index=False)
