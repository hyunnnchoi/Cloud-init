"""
This script converts network packet capture files (.pcap) to CSV format on macOS.

Main features:
- Finds and processes network.pcap files in specified directories
- Converts each pcap file to CSV with 0.01 second sampling intervals
- Records bytes sent/received per IP address over time
- Uses multiprocessing for parallel processing

Usage:
python ar_network_pool_macOS_v2.py [--path path] [--jobs jobname1 jobname2 ...]

Dependencies:
- tshark (Wireshark CLI tool, install on macOS with: brew install wireshark)
- Optimized for macOS environment (multiprocessing related)
"""

import os
import argparse
import multiprocessing
from functools import partial
import subprocess
import glob

def make_csv(job_name, path):
    job_dir = os.path.join(path, job_name)
    
    # Check if directory exists
    if not os.path.exists(job_dir):
        print(f"Error: Directory does not exist - {job_dir}")
        return
    
    # Find network.pcap files in the directory
    file_list = os.listdir(job_dir)
    net_file_list = [file for file in file_list if file.endswith("network.pcap")]
    print(f'Network files for job {job_name}: {net_file_list}')
    
    # Create output directory
    output_dir = './ar_csv'
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)
    
    for file in net_file_list:
        # Extract info from filename format: worker_0_10.244.0.54_network.pcap
        parts = file.split('_')
        if len(parts) >= 3:
            worker_type = parts[0]  # worker or chief
            index = parts[1]  # 0, 1, 2 etc
            ip = parts[2]  # IP address
            
            input_file = os.path.join(job_dir, file)
            output_file = os.path.join(output_dir, f"{job_name}_{worker_type}_{index}_{ip}_network.csv")
            
            # Method 1: Check file duration and process accordingly
            try:
                # First check total duration of PCAP file
                duration_cmd = f"""tshark -r "{input_file}" -T fields -e frame.time_epoch | sort -n | awk 'NR==1{{first=$1}} END{{print $1-first}}' """
                duration_result = subprocess.run(duration_cmd, shell=True, check=True, text=True, capture_output=True)
                duration_seconds = float(duration_result.stdout.strip())
                print(f"File duration: {duration_seconds:.2f} seconds")
                
                # Calculate needed lines for 0.01s intervals (add buffer)
                needed_lines = int(duration_seconds / 0.01) + 100
                
                # Original command with increased -A value (no duration parameter)
                command = f"""tshark -r "{input_file}" -qz io,stat,0.01,"BYTES()ip.src=={ip}","BYTES()ip.dst=={ip}" | \
                grep "Interval" -A {needed_lines} | \
                tr -d " " | tr "|" "," | \
                sed -E 's/<>/,/g; s/(^,|,$)//g; s/Interval/Time0,Time/g' | \
                cut -d, -f2- > "{output_file}" """
                
                print(f"Processing: {input_file}")
                print(f"Command: {command}")
                
                # Run on macOS
                result = subprocess.run(command, shell=True, check=True, text=True)
                print(f"File created: {output_file}")
                
                # Check number of lines in output file
                wc_cmd = f"wc -l {output_file}"
                wc_result = subprocess.run(wc_cmd, shell=True, check=True, text=True, capture_output=True)
                print(f"Output file line count: {wc_result.stdout.strip()}")
                
            except Exception as e:
                print(f"Error occurred: {e}")
                
                # Method 2: Use very large -A value if error occurs
                command = f"""tshark -r "{input_file}" -qz io,stat,0.01,"BYTES()ip.src=={ip}","BYTES()ip.dst=={ip}" | \
                grep "Interval" -A 1000000 | \
                tr -d " " | tr "|" "," | \
                sed -E 's/<>/,/g; s/(^,|,$)//g; s/Interval/Time0,Time/g' | \
                cut -d, -f2- > "{output_file}" """
                
                print(f"Trying alternative command: {command}")
                
                try:
                    # Run on macOS
                    result = subprocess.run(command, shell=True, check=True, text=True)
                    print(f"File created: {output_file}")
                except subprocess.CalledProcessError as e:
                    print(f"Error occurred: {e}")
                    print("Please check if tshark is installed. You can install it with: brew install wireshark")

def process_job_name(job_name, sched_path):
    print(f'Processing: {job_name} (location: {sched_path})')
    make_csv(job_name, sched_path)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--path', type=str, default='./')
    parser.add_argument('--jobs', type=str, nargs='+', help='Specific job names to process (process all if not specified)')
    args = parser.parse_args()
    path = args.path
    
    strategy = 'allreduce'
    sched_path = os.path.join(path, strategy)
    
    # Check if specific jobs are specified
    if args.jobs:
        job_names = args.jobs
    else:
        # Find all job directories
        job_names = []
        try:
            # Consider all folders in allreduce directory as jobs
            job_names = [d for d in os.listdir(sched_path) if os.path.isdir(os.path.join(sched_path, d))]
            job_names.sort()  # Sort job names
        except Exception as e:
            print(f"Error getting directory list: {e}")
            return
    
    print(f"Jobs to process: {job_names}")
    
    # Set multiprocessing start method for macOS
    try:
        multiprocessing.set_start_method('fork', force=True)
    except RuntimeError:
        pass  # Ignore if already set
    
    # Use multiprocessing (limit CPU cores)
    with multiprocessing.Pool(processes=min(multiprocessing.cpu_count(), 4)) as pool:
        process_job_name_partial = partial(process_job_name, sched_path=sched_path)
        pool.map(process_job_name_partial, job_names)

if __name__ == '__main__':
    main()