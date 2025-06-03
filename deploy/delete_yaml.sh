#!/bin/bash
# Lee, Hyunho
# July 27, 2023
kubectl delete -f tensorspot.yaml
kubectl delete -k training-operator/overlays/standalone
# kubectl delete -f volcano/volcano-development.yaml
# kubectl delete -f https://raw.githubusercontent.com/volcano-sh/volcano/master/installer/volcano-development.yaml
