"""
This script converts network packet capture files (.pcap) to CSV format.
Memory-optimized version to handle low memory situations.
"""

import os
import argparse
import gc
import subprocess
import glob
import re
import time

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

def check_available_memory():
    """Check available memory in GB"""
    try:
        with open('/proc/meminfo', 'r') as f:
            for line in f:
                if line.startswith('MemAvailable:'):
                    # Extract available memory in KB and convert to GB
                    available_kb = int(line.split()[1])
                    available_gb = available_kb / (1024 * 1024)
                    return available_gb
    except:
        return 0
    return 0

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
    
    if not net_file_list:
        print(f"No network.pcap files found in {job_dir}")
        return
    
    # Create output directory
    output_dir = './ar_csv'
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)
    
    for i, file in enumerate(net_file_list):
        # Check memory before processing each file
        available_memory = check_available_memory()
        print(f"Available memory: {available_memory:.2f} GB")
        
        if available_memory < 0.5:  # Less than 500MB available
            print(f"Warning: Low memory ({available_memory:.2f} GB). Waiting 5 seconds...")
            time.sleep(5)
            gc.collect()  # Force garbage collection
            
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
                
            # Check file size and warn if too large
            file_size_mb = file_size / (1024 * 1024)
            print(f"Processing file size: {file_size_mb:.2f} MB")
            
            if file_size_mb > 100:  # Files larger than 100MB
                print(f"Warning: Large file ({file_size_mb:.2f} MB). Processing may take longer...")
                
        except OSError as e:
            print(f"Error accessing file {input_file}: {e}")
            continue
        
        print(f"Processing ({i+1}/{len(net_file_list)}): {input_file}")
        print(f"Parsed - Type: {worker_type}, Index: {index}, IP: {ip}")
        
        # Method 1: Check file duration and process accordingly
        try:
            # First check total duration of PCAP file with memory limit
            duration_cmd = f"""tshark -r "{input_file}" -T fields -e frame.time_epoch -R '' | head -1000 | tail -1"""
            # Alternative: Use tshark with memory limitations
            try:
                # Get approximate duration more efficiently
                duration_cmd = f"""tshark -r "{input_file}" -T fields -e frame.time_epoch -c 1"""
                first_result = subprocess.run(duration_cmd, shell=True, check=True, text=True, capture_output=True)
                first_time = float(first_result.stdout.strip())
                
                duration_cmd = f"""tshark -r "{input_file}" -T fields -e frame.time_epoch | tail -1"""
                last_result = subprocess.run(duration_cmd, shell=True, check=True, text=True, capture_output=True)
                last_time = float(last_result.stdout.strip())
                
                duration_seconds = last_time - first_time
            except:
                duration_seconds = 60  # Default assumption if calculation fails
            print(f"File duration: {duration_seconds:.2f} seconds")
            
            # Calculate needed lines for 0.01s intervals (reduced buffer for memory optimization)
            needed_lines = int(duration_seconds / 0.01) + 50  # Reduced from 100 to 50
            
            # Use smaller buffer size for memory optimization
            if needed_lines > 100000:  # If too many lines expected
                needed_lines = 100000
                print(f"Warning: Large file detected. Using maximum buffer size of {needed_lines}")
            
            # Original command with calculated -A value
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
            
            # Method 2: Use conservative buffer size if error occurs
            command = f"""tshark -r "{input_file}" -qz io,stat,0.01,"BYTES()ip.src=={ip}","BYTES()ip.dst=={ip}" | \
            grep "Interval" -A 50000 | \
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
        
        # Force garbage collection after each file
        gc.collect()
        
        # Small delay to allow system to recover
        time.sleep(1)

def process_job_name(job_name, sched_path):
    print(f'Processing: {job_name} (location: {sched_path})')
    make_csv(job_name, sched_path)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--path', type=str, default='./')
    parser.add_argument('--jobs', type=str, nargs='+', help='Specific job names to process (process all if not specified)')
    parser.add_argument('--sequential', action='store_true', help='Process jobs sequentially (recommended for low memory)')
    args = parser.parse_args()
    path = args.path
    
    strategy = 'allreduce'
    sched_path = os.path.join(path, strategy)
    
    # Check available memory
    available_memory = check_available_memory()
    print(f"Available memory: {available_memory:.2f} GB")
    
    if available_memory < 2.0:
        print("Warning: Low memory detected. Forcing sequential processing.")
        args.sequential = True
    
    # Check if specific jobs are specified
    if args.jobs:
        job_names = args.jobs
    else:
        # Find all job directories
        job_names = []
        try:
            job_names = [d for d in os.listdir(sched_path) if os.path.isdir(os.path.join(sched_path, d))]
            job_names.sort()
        except Exception as e:
            print(f"Error getting directory list: {e}")
            return
    
    print(f"Jobs to process: {job_names}")
    
    if args.sequential or available_memory < 2.0:
        # Sequential processing for low memory situations
        print("Using sequential processing to conserve memory...")
        for job_name in job_names:
            process_job_name(job_name, sched_path)
    else:
        # Use limited multiprocessing (max 2 processes for memory conservation)
        import multiprocessing
        from functools import partial
        
        max_processes = min(2, multiprocessing.cpu_count())  # Limit to 2 processes
        print(f"Using multiprocessing with {max_processes} processes...")
        
        with multiprocessing.Pool(processes=max_processes) as pool:
            process_job_name_partial = partial(process_job_name, sched_path=sched_path)
            pool.map(process_job_name_partial, job_names)

if __name__ == '__main__':
    main()
