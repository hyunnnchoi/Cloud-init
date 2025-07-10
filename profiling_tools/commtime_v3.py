"""
This script is a tool for analyzing communication and computation time in distributed learning environments.

Main features:
1. Analyzes CSV and log files to measure communication and computation time for each iteration
2. Classifies periods where network traffic exceeds a certain threshold as communication time
3. Classifies the remaining time (excluding communication time) as computation time
4. Saves results to a CSV file for analysis

Input:
- CSV file: Contains time, bytes sent, and bytes received information

Output:
- CSV file: Contains summary information including average computation time and average communication time for each task

Usage:
1. Prepare CSV files in the 'ar_csv' directory
   - CSV filename format: *_worker_0_*.csv
2. Run the script:
   python commtime_v3.py
3. Results are saved to 'comm_time_v3.csv'

Note:
- Threshold can be adjusted through the parameter in main_v2_thresh() function
- Currently set to 0, which means all communication is classified as communication time
"""

import os
import re
import numpy as np
import pandas as pd
from glob import glob

def parse_log_file(log_path):
    with open(log_path, 'r', encoding='utf-8', errors='ignore') as f:
        lines = f.readlines()

    image_sec_lines = [line for line in lines if "images/sec" in line]
    if image_sec_lines:
        durations = []
        for line in image_sec_lines:
            match = re.search(r'images/sec:\s*([0-9.]+)', line)
            if match:
                try:
                    img_sec = float(match.group(1))
                    durations.append(8192.0 / img_sec)
                except:
                    continue
        return durations

    ts_pattern = re.compile(r"Timestamp:\s*([\d.]+)\s+Step:\s*(\d+)")
    timestamps = []
    for line in lines:
        match = ts_pattern.search(line)
        if match:
            timestamps.append(float(match.group(1)))
    durations = np.diff(timestamps).tolist()
    return durations

def classify_by_threshold(df_iter, threshold=1000):
    return (df_iter['Total_Bytes'] > threshold).astype(int)

def process_file_pair_v2_thresh(csv_path, log_path, threshold=1000, debug=False):
    with open(csv_path, 'r', encoding='utf-8', errors='ignore') as f:
        lines = f.readlines()

    data = []
    for line in lines:
        parts = line.strip().split(',')
        if len(parts) == 3:
            try:
                t = float(parts[0])
                s = int(parts[1])
                r = int(parts[2])
                data.append((t, s, r))
            except:
                continue
    if not data:
        if debug:
            print(f"[SKIP] {csv_path} - no valid CSV rows")
        return None

    df = pd.DataFrame(data, columns=['Time', 'Bytes_Sent', 'Bytes_Received'])
    df['Total_Bytes'] = df['Bytes_Sent'] + df['Bytes_Received']

    # Fixed 600 iterations
    num_iters = 600
    min_time = df['Time'].min()
    max_time = df['Time'].max()
    bins = np.linspace(min_time, max_time, num_iters + 1)
    df['Iteration'] = pd.cut(df['Time'], bins=bins, labels=False, include_lowest=True)

    if debug:
        print(f"[INFO] {csv_path} - {len(df)} samples mapped to {df['Iteration'].nunique()} iterations")

    df['Is_Network'] = 0
    for i in df['Iteration'].unique():
        mask = df['Iteration'] == i
        df.loc[mask, 'Is_Network'] = classify_by_threshold(df[mask], threshold)

    iter_stats = df.groupby('Iteration')['Is_Network'].agg(['sum', 'count']).reset_index()
    iter_stats['network_time_sec'] = iter_stats['sum'] * 0.01  # 10ms per sample
    iter_stats['total_time_sec'] = (max_time - min_time) / num_iters
    iter_stats['compute_time_sec'] = iter_stats['total_time_sec'] - iter_stats['network_time_sec']
    iter_stats['compute_time_sec'] = iter_stats['compute_time_sec'].clip(lower=0)

    return {
        'filename': os.path.basename(csv_path),
        'avg_compute_time_sec': iter_stats['compute_time_sec'].mean(),
        'avg_network_time_sec': iter_stats['network_time_sec'].mean()
    }

def main_v2_thresh(ar_csv_dir, output_csv, threshold=1000):
    csv_files = glob(os.path.join(ar_csv_dir, '*_worker_0_*.csv'))
    log_files = glob(os.path.join(ar_csv_dir, '*_controller_0_log.txt'))

    results = []
    for csv_path in csv_files:
        prefix = '_'.join(os.path.basename(csv_path).split('_')[:5])
        matched_logs = [f for f in log_files if os.path.basename(f).startswith(prefix)]
        log_path = matched_logs[0] if matched_logs else None
        result = process_file_pair_v2_thresh(csv_path, log_path, threshold, debug=True)
        if result:
            results.append(result)

    df = pd.DataFrame(results)
    df['job_num'] = df['filename'].str.extract(r'id(\d+)').astype(int)
    df = df.sort_values(by='job_num').drop(columns='job_num')

    df['avg_compute_time_sec'] = df['avg_compute_time_sec'].apply(lambda x: np.floor(x * 1e5) / 1e5)
    df['avg_network_time_sec'] = df['avg_network_time_sec'].apply(lambda x: np.floor(x * 1e5) / 1e5)

    df.to_csv(output_csv, index=False)
    print(f"✅ V3 summary saved to {output_csv}")

if __name__ == "__main__":
    main_v2_thresh('./ar_csv', 'comm_time_v3.csv', threshold=0)
