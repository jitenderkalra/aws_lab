# Kubernetes

Core practices for running workloads on Kubernetes.

## Foundations
- Namespaces per env/team; least-privilege RBAC and restricted PodSecurity standards.
- Use ServiceAccounts with imagePullSecrets and IAM roles (IRSA/Workload Identity) instead of node credentials.
- Separate concerns with Deployments/StatefulSets, Services, Ingress/IngressClass, ConfigMaps/Secrets.

## Basic objects (examples)
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello-devops
  namespace: devops
spec:
  replicas: 2
  selector:
    matchLabels:
      app: hello-devops
  template:
    metadata:
      labels:
        app: hello-devops
    spec:
      serviceAccountName: default
      containers:
        - name: hello
          image: 123456789012.dkr.ecr.us-east-1.amazonaws.com/hello-devops:1
          ports:
            - containerPort: 8081
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              cpu: 500m
              memory: 256Mi
---
apiVersion: v1
kind: Service
metadata:
  name: hello-devops
  namespace: devops
spec:
  type: NodePort
  selector:
    app: hello-devops
  ports:
    - port: 80
      targetPort: 8081
      nodePort: 30080
```

## kubectl essentials
```
kubectl get ns
kubectl get pods -n devops -o wide
kubectl describe pod <name> -n devops
kubectl logs -n devops <pod> [-c container]
kubectl exec -n devops -it <pod> -- sh
kubectl apply -f manifest.yaml
kubectl rollout status deploy/hello-devops -n devops
kubectl rollout undo deploy/hello-devops -n devops
```

## Config and Secrets
- Use ConfigMaps for non-secret config, Secrets for sensitive data; mount or env inject.
- Avoid large binaries in ConfigMaps; use volumes or images.
- Keep secrets out of git; use sealed-secrets or external secret stores where possible.

## Security and Policies
- PodSecurity (restricted), NetworkPolicies to limit traffic, resource requests/limits for all pods.
- Liveness/readiness probes to ensure healthy rollouts.
- Image policies: signed images, vulnerability scanning, and pinned tags/digests.

## Packaging with Helm
- Use Helm charts for repeatable deployments; pin chart versions.
- Values per environment; use `helm upgrade --install` with `--namespace` and `--create-namespace`.

## Observability
- Logs: send to centralized logging (Fluent Bit/Fluentd).
- Metrics: Prometheus scraping; use serviceMonitor/podMonitor if available.
- Traces: OpenTelemetry collector for app traces.
