#!/bin/bash
for p in $(ps -ef | grep NVML | awk '{print $2}'); do sudo kill -9 $p;done
for p in $(ps -ef | grep gpu.sh | awk '{print $2}'); do sudo kill -9 $p;done