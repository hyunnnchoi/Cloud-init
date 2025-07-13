#!/bin/bash

# Network profiling script runner for cluster nodes
# This script runs network profiling on all cluster nodes simultaneously

STARTTIME=`date "+%H:%M:%S.%N"`
echo "Starting network profiling at: $STARTTIME"

# Configuration
TFPATH="/home/tensorspot/Cloud-init"
DATAPATH="/home/tensorspot/data"
PEM_KEY="/home/ubuntu/tethys-v/tethys.pem"

# Node names
NODES=("xsailor-master" "xsailor-worker1" "xsailor-worker2" "xsailor-worker3")

# Parse command line arguments
JOBS_ARG=""
if [ "$#" -gt 0 ]; then
    JOBS_ARG="--jobs $*"
fi

echo "Nodes to process: ${NODES[*]}"
echo "Data path: $DATAPATH"
echo "Jobs argument: $JOBS_ARG"

# Create log directory for this run
LOG_DIR="/home/tensorspot/profiling_logs/$(date +%Y%m%d_%H%M%S)"
mkdir -p $LOG_DIR
echo "Log directory: $LOG_DIR"

# Function to run profiling on a single node
run_profiling_on_node() {
    local node=$1
    local log_file="$LOG_DIR/${node}_profiling.log"
    
    echo "Starting profiling on node: $node"
    
    # SSH command to run the profiling script on the node
    ssh -i ${PEM_KEY} -o StrictHostKeyChecking=no ubuntu@$node "
        cd $TFPATH && 
        python3 profiling_tools/ar_network_pool_server.py --path $DATAPATH $JOBS_ARG
    " > $log_file 2>&1 &
    
    # Store the PID for this background job
    local pid=$!
    echo "Started profiling on $node with PID: $pid"
    echo $pid > "$LOG_DIR/${node}_pid.txt"
}

# Start profiling on all nodes simultaneously
echo "Starting profiling on all nodes..."
for node in "${NODES[@]}"; do
    run_profiling_on_node $node
done

echo "All profiling jobs started. Waiting for completion..."

# Wait for all background jobs to complete
wait

ENDTIME=`date "+%H:%M:%S.%N"`
echo "All profiling jobs completed at: $ENDTIME"

# Show status of all log files
echo "=== Profiling Results ==="
for node in "${NODES[@]}"; do
    log_file="$LOG_DIR/${node}_profiling.log"
    if [ -f "$log_file" ]; then
        echo "Node $node log file: $log_file"
        echo "Last 10 lines of $node log:"
        tail -10 "$log_file"
        echo "---"
    else
        echo "No log file found for node $node"
    fi
done

echo "=== Summary ==="
echo "Start time: $STARTTIME"
echo "End time: $ENDTIME"
echo "Log directory: $LOG_DIR"
echo "Network profiling completed on all nodes." 