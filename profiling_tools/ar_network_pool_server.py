"""
This script converts network packet capture files (.pcap) to CSV format for server environment.
Modified to run on cluster nodes with proper output path handling.
"""

import os
import argparse
import multiprocessing
from functools import partial
import subprocess
import glob
import re
import socket

def get_node_name():
    """Get the current node name"""
    return socket.gethostname()

def parse_network_filename(filename):
    """
    Parse network pcap filename to extract worker_type, index, and IP
    Expected formats:
    - worker_0_10.244.1.6_network.pcap
    - chief_0_10.244.1.7_network.pcap
    """
    try:
        # Remove .pcap extension
        base_name = filename.replace('.pcap', '')
        
        # Use regex to parse: (worker|chief)_(\d+)_(IP_ADDRESS)_network
        pattern = r'(worker|chief)_(\d+)_(\d+\.\d+\.\d+\.\d+)_network'
        match = re.match(pattern, base_name)
        
        if match:
            worker_type = match.group(1)  # worker or chief
            index = match.group(2)        # 0, 1, 2, etc.
            ip = match.group(3)          # 10.244.1.6
            return worker_type, index, ip
        else:
            print(f"Warning: Filename doesn't match expected pattern: {filename}")
            # Fallback: try original parsing but fix IP extraction
            parts = base_name.split('_')
            if len(parts) >= 5 and parts[-1] == 'network':
                worker_type = parts[0]
                index = parts[1]
                # IP is everything between index and 'network'
                ip_parts = parts[2:-1]
                ip = '.'.join(ip_parts)
                return worker_type, index, ip
            
            return None, None, None
            
    except Exception as e:
        print(f"Error parsing filename {filename}: {e}")
        return None, None, None

def make_csv(job_name, data_path):
    """Convert pcap files to CSV format"""
    job_dir = os.path.join(data_path, job_name)
    
    # Check if directory exists
    if not os.path.exists(job_dir):
        print(f"Error: Directory does not exist - {job_dir}")
        return
    
    # Find network.pcap files in the directory
    file_list = os.listdir(job_dir)
    net_file_list = [file for file in file_list if file.endswith("network.pcap")]
    print(f'Network files for job {job_name}: {net_file_list}')
    
    if not net_file_list:
        print(f"No network.pcap files found in {job_dir}")
        return
    
    # Create output directory inside the job directory
    output_dir = job_dir
    
    node_name = get_node_name()
    print(f"Processing on node: {node_name}")
    
    for file in net_file_list:
        # Parse filename using improved function
        worker_type, index, ip = parse_network_filename(file)
        
        if not all([worker_type, index, ip]):
            print(f"Skipping file due to parsing error: {file}")
            continue
            
        input_file = os.path.join(job_dir, file)
        output_file = os.path.join(output_dir, f"{job_name}_{worker_type}_{index}_{ip}_network.csv")
        
        # Check if file is not empty
        try:
            file_size = os.path.getsize(input_file)
            if file_size == 0:
                print(f"Warning: Empty file - {input_file}")
                continue
        except OSError as e:
            print(f"Error accessing file {input_file}: {e}")
            continue
        
        print(f"Processing: {input_file}")
        print(f"Parsed - Type: {worker_type}, Index: {index}, IP: {ip}")
        
        # Method 1: Check file duration and process accordingly
        try:
            # First check total duration of PCAP file
            duration_cmd = f"""tshark -r "{input_file}" -T fields -e frame.time_epoch | sort -n | awk 'NR==1{{first=$1}} END{{print $1-first}}' """
            duration_result = subprocess.run(duration_cmd, shell=True, check=True, text=True, capture_output=True)
            duration_seconds = float(duration_result.stdout.strip())
            print(f"File duration: {duration_seconds:.2f} seconds")
            
            # Calculate needed lines for 0.01s intervals (add buffer)
            needed_lines = int(duration_seconds / 0.01) + 100
            
            # Original command with increased -A value
            command = f"""tshark -r "{input_file}" -qz io,stat,0.01,"BYTES()ip.src=={ip}","BYTES()ip.dst=={ip}" | \
            grep "Interval" -A {needed_lines} | \
            tr -d " " | tr "|" "," | \
            sed -E 's/<>/,/g; s/(^,|,$)//g; s/Interval/Time0,Time/g' | \
            cut -d, -f2- > "{output_file}" """
            
            print(f"Command: {command}")
            
            # Run the command
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
                result = subprocess.run(command, shell=True, check=True, text=True)
                print(f"File created: {output_file}")
            except subprocess.CalledProcessError as e:
                print(f"Error occurred: {e}")
                print("Please check if tshark is installed.")

def process_job_name(job_name, data_path):
    """Process a single job"""
    print(f'Processing: {job_name} (location: {data_path})')
    make_csv(job_name, data_path)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--path', type=str, default='/home/tensorspot/data')
    parser.add_argument('--jobs', type=str, nargs='+', help='Specific job names to process (process all if not specified)')
    args = parser.parse_args()
    
    data_path = args.path
    
    # Check if specific jobs are specified
    if args.jobs:
        job_names = args.jobs
    else:
        # Find all job directories directly in data_path
        job_names = []
        try:
            job_names = [d for d in os.listdir(data_path) if os.path.isdir(os.path.join(data_path, d))]
            job_names.sort()
        except Exception as e:
            print(f"Error getting directory list: {e}")
            return
    
    print(f"Jobs to process: {job_names}")
    print(f"Running on node: {get_node_name()}")
    
    # Use multiprocessing (limit CPU cores)
    with multiprocessing.Pool(processes=min(multiprocessing.cpu_count(), 32)) as pool:
        process_job_name_partial = partial(process_job_name, data_path=data_path)
        pool.map(process_job_name_partial, job_names)

if __name__ == '__main__':
    main() 
