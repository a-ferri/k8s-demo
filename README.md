# K8s demo session

## Before you begin:

#### Checkout this repo to your home folder:
```
cd ~
git clone git@githib.com:a-ferri/k8s-demo
```

#### Create these environment variables:
```
export IP="MY_IP"
export ING_ADDR="${IP}.xip.io"
```

#### Kind
Please refer to [this](https://kind.sigs.k8s.io/docs/user/quick-start/#installation) link for installing `kind`

## Creating & configuring the cluster

#### Install kind cluster

```
kind create cluster --config=${HOME}/k8s-demo/kind/config.yaml
```

#### Install Calido CNI

```
kubectl apply -f https://projectcalico.docs.tigera.io/manifests/calico.yaml
```

#### Install CSR Approver
```
helm repo add kubelet-csr-approver https://postfinance.github.io/kubelet-csr-approver
helm install kubelet-csr-approver kubelet-csr-approver/kubelet-csr-approver -n kube-system \
  --set maxExpirationSeconds='86400' \
  --set bypassDnsResolution='false'
```

> Note: Never ever use it on production! :)

#### Install metrics-server
```
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

#### Install ingress controller

```
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
```

Wait for the ingress to be available:
```
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s
```

#### Ingress TLS Certs & Secret

```
cd ${HOME}/k8s-demo/certs && sh create-certs.sh && cd -
```

## Deploy sample apps
