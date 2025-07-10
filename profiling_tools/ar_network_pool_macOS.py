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
import time
from datetime import datetime, timedelta
try:
    from tqdm import tqdm
    TQDM_AVAILABLE = True
except ImportError:
    TQDM_AVAILABLE = False
    print("Warning: tqdm not available. Install with 'pip install tqdm' for progress bars.")

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
    
    print("Analyzing job sizes...")
    if TQDM_AVAILABLE:
        iterator = tqdm(job_names, desc="Analyzing jobs")
    else:
        iterator = job_names
        
    for i, job_name in enumerate(iterator):
        if not TQDM_AVAILABLE:
            print(f"Analyzing job {i+1}/{len(job_names)}: {job_name}")
            
        job_dir = os.path.join(sched_path, job_name)
        if not os.path.exists(job_dir):
            continue
            
        # Find largest pcap file in this job
        pcap_files = [f for f in os.listdir(job_dir) if f.endswith("network.pcap")]
        max_size = 0
        total_files = len(pcap_files)
        
        for pcap_file in pcap_files:
            file_path = os.path.join(job_dir, pcap_file)
            size_gb = get_file_size_gb(file_path)
            max_size = max(max_size, size_gb)
        
        # Categorize based on largest file in job
        if max_size > 10:
            job_categories['huge'].append(job_name)
            print(f"Job {job_name}: HUGE ({max_size:.1f}GB, {total_files} files) - will process sequentially")
        elif max_size > 5:
            job_categories['large'].append(job_name)
            print(f"Job {job_name}: LARGE ({max_size:.1f}GB, {total_files} files) - max 2 parallel")
        elif max_size > 2:
            job_categories['medium'].append(job_name)
            print(f"Job {job_name}: MEDIUM ({max_size:.1f}GB, {total_files} files) - max 3 parallel")
        else:
            job_categories['small'].append(job_name)
            print(f"Job {job_name}: SMALL ({max_size:.1f}GB, {total_files} files) - max 4 parallel")
    
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
    start_time = time.time()
    job_dir = os.path.join(path, job_name)
    
    # Check if directory exists
    if not os.path.exists(job_dir):
        print(f"Error: Directory does not exist - {job_dir}")
        return
    
    # Find network.pcap files in the directory
    file_list = os.listdir(job_dir)
    net_file_list = [file for file in file_list if file.endswith("network.pcap")]
    print(f'\n[{datetime.now().strftime("%H:%M:%S")}] Job {job_name}: Found {len(net_file_list)} network files')
    
    if not net_file_list:
        print(f"No network.pcap files found in {job_dir}")
        return
    
    # Create output directory
    output_dir = './ar_csv'
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)
    
    # Progress tracking
    total_files = len(net_file_list)
    processed_files = 0
    skipped_files = 0
    
    if TQDM_AVAILABLE:
        file_iterator = tqdm(net_file_list, desc=f"Processing {job_name}", leave=False)
    else:
        file_iterator = net_file_list
    
    for file_idx, file in enumerate(file_iterator):
        if not TQDM_AVAILABLE:
            print(f"\n[{datetime.now().strftime('%H:%M:%S')}] Processing file {file_idx+1}/{total_files}: {file}")
        
        # Parse filename using improved function
        worker_type, index, ip = parse_network_filename(file)
        
        if not all([worker_type, index, ip]):
            print(f"Skipping file due to parsing error: {file}")
            skipped_files += 1
            continue
            
        input_file = os.path.join(job_dir, file)
        output_file = os.path.join(output_dir, f"{job_name}_{worker_type}_{index}_{ip}_network.csv")
        
        # Check if output file already exists
        if os.path.exists(output_file):
            if TQDM_AVAILABLE:
                file_iterator.set_postfix({"status": "skipped (exists)"})
            else:
                print(f"  → Output file already exists, skipping")
            skipped_files += 1
            continue
        
        # Check if file is not empty
        try:
            file_size = os.path.getsize(input_file)
            if file_size == 0:
                print(f"Warning: Empty file - {input_file}")
                skipped_files += 1
                continue
        except OSError as e:
            print(f"Error accessing file {input_file}: {e}")
            skipped_files += 1
            continue
        
        file_size_gb = file_size / (1024**3)
        if TQDM_AVAILABLE:
            file_iterator.set_postfix({"size": f"{file_size_gb:.1f}GB", "status": "processing"})
        else:
            print(f"  → Size: {file_size_gb:.1f}GB, Type: {worker_type}, Index: {index}, IP: {ip}")
        
        file_start_time = time.time()
        
        # Method 1: Check file duration and process accordingly
        try:
            # First check total duration of PCAP file
            duration_cmd = f"""tshark -r "{input_file}" -T fields -e frame.time_epoch | sort -n | awk 'NR==1{{first=$1}} END{{print $1-first}}' """
            duration_result = subprocess.run(duration_cmd, shell=True, check=True, text=True, capture_output=True)
            duration_seconds = float(duration_result.stdout.strip())
            
            if not TQDM_AVAILABLE:
                print(f"  → Duration: {duration_seconds:.2f} seconds")
            
            # Calculate needed lines for 0.01s intervals (add buffer)
            needed_lines = int(duration_seconds / 0.01) + 100
            
            # Original command with increased -A value
            command = f"""tshark -r "{input_file}" -qz io,stat,0.01,"BYTES()ip.src=={ip}","BYTES()ip.dst=={ip}" | \
            grep "Interval" -A {needed_lines} | \
            tr -d " " | tr "|" "," | \
            sed -E 's/<>/,/g; s/(^,|,$)//g; s/Interval/Time0,Time/g' | \
            cut -d, -f2- > "{output_file}" """
            
            # Run the command
            result = subprocess.run(command, shell=True, check=True, text=True)
            
            # Check number of lines in output file
            wc_cmd = f"wc -l {output_file}"
            wc_result = subprocess.run(wc_cmd, shell=True, check=True, text=True, capture_output=True)
            output_lines = wc_result.stdout.strip()
            
            file_end_time = time.time()
            processing_time = file_end_time - file_start_time
            
            if TQDM_AVAILABLE:
                file_iterator.set_postfix({"status": "completed", "lines": output_lines, "time": f"{processing_time:.1f}s"})
            else:
                print(f"  → Completed in {processing_time:.1f}s, {output_lines} lines")
            
            processed_files += 1
            
        except Exception as e:
            print(f"Error occurred: {e}")
            
            # Method 2: Use very large -A value if error occurs
            command = f"""tshark -r "{input_file}" -qz io,stat,0.01,"BYTES()ip.src=={ip}","BYTES()ip.dst=={ip}" | \
            grep "Interval" -A 1000000 | \
            tr -d " " | tr "|" "," | \
            sed -E 's/<>/,/g; s/(^,|,$)//g; s/Interval/Time0,Time/g' | \
            cut -d, -f2- > "{output_file}" """
            
            if not TQDM_AVAILABLE:
                print(f"  → Trying alternative method...")
            
            try:
                result = subprocess.run(command, shell=True, check=True, text=True)
                file_end_time = time.time()
                processing_time = file_end_time - file_start_time
                
                if TQDM_AVAILABLE:
                    file_iterator.set_postfix({"status": "completed (alt)", "time": f"{processing_time:.1f}s"})
                else:
                    print(f"  → Completed (alternative method) in {processing_time:.1f}s")
                
                processed_files += 1
            except subprocess.CalledProcessError as e:
                print(f"Error occurred: {e}")
                print("Please check if tshark is installed.")
                skipped_files += 1
        
        # Force garbage collection after each large file
        if file_size_gb > 5:
            gc.collect()
    
    total_time = time.time() - start_time
    print(f"\n[{datetime.now().strftime('%H:%M:%S')}] Job {job_name} completed:")
    print(f"  ✓ Processed: {processed_files} files")
    print(f"  ⊘ Skipped: {skipped_files} files") 
    print(f"  ⏱ Total time: {total_time:.1f}s")
    if processed_files > 0:
        print(f"  ⚡ Avg time per file: {total_time/processed_files:.1f}s")

def process_job_name(job_name, sched_path):
    print(f'\n🚀 Starting job: {job_name} (PID: {os.getpid()})')
    start_time = time.time()
    
    make_csv(job_name, sched_path)
    
    end_time = time.time()
    duration = end_time - start_time
    print(f'✅ Completed job: {job_name} (took {duration:.1f}s)')
    
    # Force garbage collection after each job
    gc.collect()

def process_jobs_with_memory_management(job_categories, sched_path):
    """Process jobs with memory-aware parallelization"""
    
    overall_start = time.time()
    total_jobs = sum(len(jobs) for jobs in job_categories.values())
    completed_jobs = 0
    
    def update_overall_progress():
        nonlocal completed_jobs
        elapsed = time.time() - overall_start
        if completed_jobs > 0:
            eta = (elapsed / completed_jobs) * (total_jobs - completed_jobs)
            eta_str = str(timedelta(seconds=int(eta)))
            print(f"\n📊 Overall Progress: {completed_jobs}/{total_jobs} jobs completed. ETA: {eta_str}")
    
    print(f"\n🎯 Starting processing of {total_jobs} jobs...")
    
    if job_categories['huge']:
        print(f"\n=== 🐘 PROCESSING HUGE FILES (>10GB) SEQUENTIALLY ({len(job_categories['huge'])} jobs) ===")
        for i, job_name in enumerate(job_categories['huge']):
            print(f"\n[HUGE {i+1}/{len(job_categories['huge'])}] Processing: {job_name}")
            process_job_name(job_name, sched_path)
            completed_jobs += 1
            update_overall_progress()
    
    if job_categories['large']:
        print(f"\n=== 🔥 PROCESSING LARGE FILES (5-10GB) - MAX 2 PARALLEL ({len(job_categories['large'])} jobs) ===")
        with multiprocessing.Pool(processes=2) as pool:
            process_job_name_partial = partial(process_job_name, sched_path=sched_path)
            
            if TQDM_AVAILABLE:
                for _ in tqdm(pool.imap(process_job_name_partial, job_categories['large']), 
                             total=len(job_categories['large']), desc="Large files"):
                    completed_jobs += 1
                    update_overall_progress()
            else:
                pool.map(process_job_name_partial, job_categories['large'])
                completed_jobs += len(job_categories['large'])
    
    if job_categories['medium']:
        print(f"\n=== 📦 PROCESSING MEDIUM FILES (2-5GB) - MAX 3 PARALLEL ({len(job_categories['medium'])} jobs) ===")
        with multiprocessing.Pool(processes=3) as pool:
            process_job_name_partial = partial(process_job_name, sched_path=sched_path)
            
            if TQDM_AVAILABLE:
                for _ in tqdm(pool.imap(process_job_name_partial, job_categories['medium']), 
                             total=len(job_categories['medium']), desc="Medium files"):
                    completed_jobs += 1
                    update_overall_progress()
            else:
                pool.map(process_job_name_partial, job_categories['medium'])
                completed_jobs += len(job_categories['medium'])
    
    if job_categories['small']:
        print(f"\n=== ⚡ PROCESSING SMALL FILES (<2GB) - MAX 4 PARALLEL ({len(job_categories['small'])} jobs) ===")
        with multiprocessing.Pool(processes=4) as pool:
            process_job_name_partial = partial(process_job_name, sched_path=sched_path)
            
            if TQDM_AVAILABLE:
                for _ in tqdm(pool.imap(process_job_name_partial, job_categories['small']), 
                             total=len(job_categories['small']), desc="Small files"):
                    completed_jobs += 1
                    update_overall_progress()
            else:
                pool.map(process_job_name_partial, job_categories['small'])
                completed_jobs += len(job_categories['small'])
    
    total_duration = time.time() - overall_start
    print(f"\n🎉 ALL JOBS COMPLETED!")
    print(f"📊 Total jobs processed: {completed_jobs}")
    print(f"⏱  Total time: {str(timedelta(seconds=int(total_duration)))}")
    print(f"⚡ Average time per job: {total_duration/completed_jobs:.1f}s")

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--path', type=str, default='./')
    parser.add_argument('--jobs', type=str, nargs='+', help='Specific job names to process (process all if not specified)')
    parser.add_argument('--force-parallel', type=int, help='Force specific number of parallel processes (ignores size-based optimization)')
    parser.add_argument('--install-tqdm', action='store_true', help='Install tqdm for progress bars')
    args = parser.parse_args()
    
    if args.install_tqdm:
        try:
            import subprocess
            subprocess.check_call(['pip', 'install', 'tqdm'])
            print("tqdm installed successfully! Please run the script again.")
            return
        except Exception as e:
            print(f"Failed to install tqdm: {e}")
            return
    
    path = args.path
    
    strategy = 'allreduce'
    sched_path = os.path.join(path, strategy)
    
    print(f"🔍 Scanning directory: {sched_path}")
    
    # Check if specific jobs are specified
    if args.jobs:
        job_names = args.jobs
        print(f"📝 Processing specific jobs: {job_names}")
    else:
        # Find all job directories
        job_names = []
        try:
            job_names = [d for d in os.listdir(sched_path) if os.path.isdir(os.path.join(sched_path, d))]
            job_names.sort()
            print(f"📁 Found {len(job_names)} job directories")
        except Exception as e:
            print(f"❌ Error getting directory list: {e}")
            return
    
    if not job_names:
        print("❌ No jobs found to process")
        return
    
    if args.force_parallel:
        print(f"⚠️  Using forced parallel processing with {args.force_parallel} processes")
        start_time = time.time()
        
        with multiprocessing.Pool(processes=args.force_parallel) as pool:
            process_job_name_partial = partial(process_job_name, sched_path=sched_path)
            
            if TQDM_AVAILABLE:
                for _ in tqdm(pool.imap(process_job_name_partial, job_names), 
                             total=len(job_names), desc="Processing jobs"):
                    pass
            else:
                pool.map(process_job_name_partial, job_names)
        
        total_time = time.time() - start_time
        print(f"\n🎉 Completed all {len(job_names)} jobs in {str(timedelta(seconds=int(total_time)))}")
    else:
        # Use memory-aware processing
        print("🧠 Analyzing file sizes for memory-optimized processing...")
        job_categories = categorize_jobs_by_size(job_names, sched_path)
        
        print(f"\n📊 Job distribution:")
        print(f"  🐘 HUGE (>10GB): {len(job_categories['huge'])} jobs")
        print(f"  🔥 LARGE (5-10GB): {len(job_categories['large'])} jobs") 
        print(f"  📦 MEDIUM (2-5GB): {len(job_categories['medium'])} jobs")
        print(f"  ⚡ SMALL (<2GB): {len(job_categories['small'])} jobs")
        
        process_jobs_with_memory_management(job_categories, sched_path)

if __name__ == '__main__':
    main()
