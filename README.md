# K8s demo session

## Before you begin:

#### Checkout this repo to your home folder:
```
cd ~
git clone git@github.com:a-ferri/k8s-demo.git
```

#### Create these environment variables:
```
export IP="MY_IP"
export ING_ADDR="${IP}.xip.io"
```

#### Kind
Please refer to [this](https://kind.sigs.k8s.io/docs/user/quick-start/#installation) link for installing `kind`

#### Useful stuff
- [stern](https://github.com/wercker/stern/releases)

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

Now that the cluster is ready, let's deploy some apps!

#### Deployment

The first one is a simple python app installed as a Deployment (AKA ReplicaSet).

This app calculates the square root of a random number between 100-10000
```
kubectl apply -f ${HOME}/app/sample-deploy.yaml
```

#### Ingress

We also can install a ingress for our app so we can test it:
```
sed "s/{{nip}}/$ING_ADDR/g" ${HOME}/app/sample-ingress.yaml |kubectl apply -f -
```

You should now be able to make requests:
```
curl -i $ING_ADDR
```

Although we are using a TLS certificate, it's not a trusted one, but you still can test it by using the `-k` curl flag:
```
curl -i https://$ING_ADDR -k
```

#### Load Test

Now that our sample app is up & running, let's add some traffic to it:
```
kubectl apply -f ${HOME}/app/sample-job.yaml
```
The `siege` app is a HTTP loading test tool and it's configured to start concurrent 5 threads during 5 minutes.

You can monitor the resource consumption with:
```
watch kubectl top pod -l app=sample-deploy 
```
(leave it running for the next step)

#### HPA

While our app is being "attacked" by `siege`, let's configure the Horizontal Pod Autoscaling:
```
kubectl apply -f ${HOME}/app/sample-hpa.yaml
```
Wait a few seconds and our app should scale to 4 pods.

If you have `stern`, then you can get logs from all pods:
```
stern -l app=sample-deploy
```

#### Statefulset

We're going to deploy a StatefulSet nginx to demonstrate how the Pod Disruption Budget can affect our cluster behavior.
```
kubectl apply -f ${HOME}/app/sample-statefulset.yaml
```
> Side note: 
> A StatefulSet have pretty much the same container spec of a Deployment. 
> While Deployments are a good fit for *stateless* applications, as the name suggests, StatefulSets are great for Stateful applications.
> We could say that the main difference is that StatefulSets maintains a stick identifies for each one of their pods.

#### PDB

To be continued...
```
kubectl apply -f ${HOME}/app/sample-pdb.yaml
```