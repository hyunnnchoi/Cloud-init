#!/bin/bash
# Lee, Hyunho
# July 27, 2023
kubectl apply -k "github.com/kubeflow/training-operator/manifests/overlays/standalone"
#kubectl apply -k training-operator/overlays/standalone
kubectl apply -f tensorspot.yaml

#kubectl apply -k volcano/overlays/standalone
#kubectl apply -f volcano/volcano-development.yaml
# kubectl apply -f volcano/default_volcano.yaml
# kubectl create -f https://raw.githubusercontent.com/volcano-sh/volcano/master/installer/volcano-development.yaml
