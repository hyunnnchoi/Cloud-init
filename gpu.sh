#!/bin/bash
HOSTNAME=$(hostname)

/home/tensorspot/Cloud-init/NVML/NVML > /home/tensorspot/tfjob/gpu_${HOSTNAME}.txt
