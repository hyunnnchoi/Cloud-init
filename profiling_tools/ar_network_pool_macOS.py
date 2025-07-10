"""
This script converts network packet capture files (.pcap) to CSV format.
Memory-optimized version with dynamic process allocation based on file sizes.
"""

import os
import argparse
import multiprocessing
from functools import partial
import subprocess
import glob
import re
import gc
from collections import defaultdict

def get_file_size_gb(filepath):
    """Get file size in GB"""
    try:
        size_bytes = os.path.getsize(filepath)
        return size_bytes / (1024**3)  # Convert to GB
    except:
        return 0

def categorize_jobs_by_size(job_names, sched_path):
    """Categorize jobs by their largest file size"""
    job_categories = {
        'huge': [],      # >10GB files
        'large': [],     # 5-10GB files  
        'medium': [],    # 2-5GB files
        'small': []      # <2GB files
    }
    
    for job_name in job_names:
        job_dir = os.path.join(sched_path, job_name)
        if not os.path.exists(job_dir):
            continue
            
        # Find largest pcap file in this job
        pcap_files = [f for f in os.listdir(job_dir) if f.endswith("network.pcap")]
        max_size = 0
        
        for pcap_file in pcap_files:
            file_path = os.path.join(job_dir, pcap_file)
            size_gb = get_file_size_gb(file_path)
            max_size = max(max_size, size_gb)
        
        # Categorize based on largest file in job
        if max_size > 10:
            job_categories['huge'].append(job_name)
            print(f"Job {job_name}: HUGE ({max_size:.1f}GB) - will process sequentially")
        elif max_size > 5:
            job_categories['large'].append(job_name)
            print(f"Job {job_name}: LARGE ({max_size:.1f}GB) - max 2 parallel")
        elif max_size > 2:
            job_categories['medium'].append(job_name)
            print(f"Job {job_name}: MEDIUM ({max_size:.1f}GB) - max 3 parallel")
        else:
            job_categories['small'].append(job_name)
            print(f"Job {job_name}: SMALL ({max_size:.1f}GB) - max 4 parallel")
    
    return job_categories

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
    
    for file in net_file_list:
        # Parse filename using improved function
        worker_type, index, ip = parse_network_filename(file)
        
        if not all([worker_type, index, ip]):
            print(f"Skipping file due to parsing error: {file}")
            continue
            
        input_file = os.path.join(job_dir, file)
        output_file = os.path.join(output_dir, f"{job_name}_{worker_type}_{index}_{ip}_network.csv")
        
        # Check if output file already exists
        if os.path.exists(output_file):
            print(f"Output file already exists, skipping: {output_file}")
            continue
        
        # Check if file is not empty
        try:
            file_size = os.path.getsize(input_file)
            if file_size == 0:
                print(f"Warning: Empty file - {input_file}")
                continue
        except OSError as e:
            print(f"Error accessing file {input_file}: {e}")
            continue
        
        file_size_gb = file_size / (1024**3)
        print(f"Processing: {input_file} ({file_size_gb:.1f}GB)")
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
        
        # Force garbage collection after each large file
        if file_size_gb > 5:
            gc.collect()

def process_job_name(job_name, sched_path):
    print(f'Processing: {job_name} (location: {sched_path})')
    make_csv(job_name, sched_path)
    
    # Force garbage collection after each job
    gc.collect()

def process_jobs_with_memory_management(job_categories, sched_path):
    """Process jobs with memory-aware parallelization"""
    
    print("\n=== PROCESSING HUGE FILES (>10GB) SEQUENTIALLY ===")
    if job_categories['huge']:
        for job_name in job_categories['huge']:
            print(f"\nProcessing HUGE job: {job_name}")
            process_job_name(job_name, sched_path)
    
    print("\n=== PROCESSING LARGE FILES (5-10GB) - MAX 2 PARALLEL ===")
    if job_categories['large']:
        with multiprocessing.Pool(processes=2) as pool:
            process_job_name_partial = partial(process_job_name, sched_path=sched_path)
            pool.map(process_job_name_partial, job_categories['large'])
    
    print("\n=== PROCESSING MEDIUM FILES (2-5GB) - MAX 3 PARALLEL ===")
    if job_categories['medium']:
        with multiprocessing.Pool(processes=3) as pool:
            process_job_name_partial = partial(process_job_name, sched_path=sched_path)
            pool.map(process_job_name_partial, job_categories['medium'])
    
    print("\n=== PROCESSING SMALL FILES (<2GB) - MAX 4 PARALLEL ===")
    if job_categories['small']:
        with multiprocessing.Pool(processes=4) as pool:
            process_job_name_partial = partial(process_job_name, sched_path=sched_path)
            pool.map(process_job_name_partial, job_categories['small'])

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--path', type=str, default='./')
    parser.add_argument('--jobs', type=str, nargs='+', help='Specific job names to process (process all if not specified)')
    parser.add_argument('--force-parallel', type=int, help='Force specific number of parallel processes (ignores size-based optimization)')
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
            job_names = [d for d in os.listdir(sched_path) if os.path.isdir(os.path.join(sched_path, d))]
            job_names.sort()
        except Exception as e:
            print(f"Error getting directory list: {e}")
            return
    
    print(f"Jobs to process: {job_names}")
    
    if args.force_parallel:
        print(f"Using forced parallel processing with {args.force_parallel} processes")
        with multiprocessing.Pool(processes=args.force_parallel) as pool:
            process_job_name_partial = partial(process_job_name, sched_path=sched_path)
            pool.map(process_job_name_partial, job_names)
    else:
        # Use memory-aware processing
        print("Analyzing file sizes for memory-optimized processing...")
        job_categories = categorize_jobs_by_size(job_names, sched_path)
        
        print(f"\nJob distribution:")
        print(f"  HUGE (>10GB): {len(job_categories['huge'])} jobs")
        print(f"  LARGE (5-10GB): {len(job_categories['large'])} jobs") 
        print(f"  MEDIUM (2-5GB): {len(job_categories['medium'])} jobs")
        print(f"  SMALL (<2GB): {len(job_categories['small'])} jobs")
        
        process_jobs_with_memory_management(job_categories, sched_path)

if __name__ == '__main__':
    main()
