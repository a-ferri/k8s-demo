# K8s demo session

## Before you begin:

#### Requirements
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installation)
- [kustomize](https://kustomize.io/)

#### Nice to have
- [stern](https://github.com/wercker/stern/releases)

#### Checkout this repo to your home folder:
```
cd ~
git clone git@github.com:a-ferri/k8s-demo.git
```

#### Create these environment variables:
```
export IP="MY_IP"
export ING_ADDR="${IP}.nip.io"
```

## Environment
For this demo I'm using a laptop with 8 cores and 16Gb of memory.

As our K8s nodes are running on containers, each node will consider the whole amount of resources available on the host!

After your cluster is running, this command should show you the allocatable resources for your nodes:

```
kubectl get node <NODE_NAME> -o=jsonpath='CPU:{"\t"}{.status.allocatable.cpu}{"\n"}MEM:{"\t"}{.status.allocatable.memory}{"\n"}'
```

This information is important for the PDB tests as we have to assign enough resources to each pod of our StatefulSet so they cannot be schedule at the same node.

## Creating & configuring the cluster

#### Install kind cluster

Kind Clusters are a very easy way to deploy a K8s cluster.

Instead of provisioning multiple VMs to act as nodes, kind clusters uses their nodes as containers.

```
kind create cluster --config=${HOME}/k8s-demo/kind/config.yaml
```

There are some customizations for our cluster - you can find them at `~/k8s-demo/kind/config.yaml`

#### Install CNI Plugin

We have disabled the default CNI plugin in our cluster.

The nodes will remain unavailable until we deploy a CNI Plugin.

Calico is known to work well with Kind Clusters, so that is our choice.

```
kubectl apply -f https://projectcalico.docs.tigera.io/manifests/calico.yaml
```

#### Install metrics-server

Kind cluster do not assign certificates to nodes.

Metrics Server uses nodes' FQDN to connect, so it will fail. Due to that, we have to patch the metrics-server manifest to allow `insecure-tls-connections`.
```
kustomize build ${HOME}/k8s-demo/metrics-server/ |kubectl apply -f -
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
The `siege` app is a HTTP loading test tool and it's configured to start 5 concurrent threads during 5 minutes.

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
> While Deployments are a good fit for *stateless* applications, as the name suggests, StatefulSets are great for *Stateful* applications.
> We could say that the main difference is that StatefulSets maintains a stick identity for each one of their pods.

#### Draining nodes

Let's start draining one node:
```
kubectl drain demo-cluster-worker --ignore-daemonsets
```

This should work, even if the evicted pod cannot be scheduled on another node.

Now let's see if we can drain another node:

```
kubectl drain demo-cluster-worker2 --ignore-daemonsets
```

It should also work!

Check the nodes:
```
kubectl get node -o wide
```

> The `--ignore-daemonsets` is needed if we have any DaemonSet running at the node we're trying to drain!

#### PDB

Before creating the PDB, lets put our drained nodes back to work:
```
kubectl uncordon demo-cluster-worker
kubectl uncordon demo-cluster-worker2
```

Check if all pods are running:
```
kubectl get pod -l app=sample-app -o wide
```

Now we can apply the PDB manifest:
```
kubectl apply -f ${HOME}/app/sample-pdb.yaml
```

Our PDB is configured to allow only ONE unavailable pod in our StatefulSet sample-app.

Let's start draining one node:
```
kubectl drain demo-cluster-worker --ignore-daemonsets
```

It works, as we only have one pod unavailable.

Now let's try draining another node:

```
kubectl drain demo-cluster-worker2 --ignore-daemonsets
```

If we did things right, it should fail!

As we already have an unavailable pod, PDB won't let we evict another one if K8s is unable to schedule a new pod.
