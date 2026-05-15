# HELEP — Submission

**Hybrid Emergency & Localization Emergency Platform**
SEN3244 Software Architecture — May 2026

---

## Folder layout

```
helep-final/
├── services/
│   ├── user-service/        Dockerfile  app/  requirements.txt
│   ├── sos-service/         Dockerfile  app/  requirements.txt
│   ├── dispatch-service/    Dockerfile  app/  requirements.txt
│   ├── notification-service/ Dockerfile  app/  requirements.txt
│   └── analytics-service/   Dockerfile  app/  requirements.txt
├── charts/helep/
│   ├── Chart.yaml  values.yaml
│   ├── templates/   configmap  secret  ingress
│   └── charts/      5 sub-charts, each with Deployment/Service/HPA/PVC
├── manifests/
│   ├── namespace.yaml  storageclass.yaml
│   ├── kafka-cluster.yaml      Strimzi Kafka CR + PodDisruptionBudget
│   ├── kafka-topics.yaml       7 KafkaTopic CRDs
│   ├── netpol-deny-all.yaml
│   ├── netpol-allow-dns.yaml
│   ├── netpol-allow-kafka.yaml
│   ├── netpol-allow-<svc>.yaml  (one per service)
│   ├── prometheus-values.yaml
│   └── grafana-dashboard-cm.yaml
├── ci/
│   └── Jenkinsfile
├── dashboards/
│   └── helep-overview.json
├── design.pdf
├── patterns.pdf
└── docker-compose.dev.yml
```

## Code changes to starter

| File | What changed |
|------|-------------|
| `services/*/app/events.py` | CircuitBreaker class completed (CLOSED/OPEN/HALF_OPEN) |
| `services/dispatch-service/app/matching.py` | RoundRobinMatcher added + factory updated |

## Local dev

```bash
docker compose -f docker-compose.dev.yml up --build

# register
curl -X POST localhost:8001/signup \
  -H 'content-type: application/json' \
  -d '{"phone":"+237600000001","password":"pass123","role":"citizen"}'

# trigger SOS
curl -X POST localhost:8002/sos \
  -H "authorization: Bearer <TOKEN>" \
  -H 'content-type: application/json' \
  -d '{"lat":4.05,"lon":9.77,"mode":"online"}'

# watch the saga
docker compose -f docker-compose.dev.yml logs -f notification-service
curl localhost:8005/stats/events
```

## Kubernetes deploy

```bash
kubectl create namespace kafka
kubectl create namespace helep
kubectl create namespace observability
kubectl apply -f manifests/namespace.yaml

# strimzi
helm install strimzi oci://quay.io/strimzi-helm/strimzi-kafka-operator \
  -n kafka --set watchNamespaces="{kafka}"

# kafka
kubectl apply -f manifests/kafka-cluster.yaml
kubectl apply -f manifests/kafka-topics.yaml

# network
kubectl apply -f manifests/netpol-deny-all.yaml
kubectl apply -f manifests/netpol-allow-dns.yaml
kubectl apply -f manifests/netpol-allow-kafka.yaml
kubectl apply -f manifests/netpol-allow-user-service.yaml
kubectl apply -f manifests/netpol-allow-sos-service.yaml
kubectl apply -f manifests/netpol-allow-dispatch-service.yaml
kubectl apply -f manifests/netpol-allow-notification-service.yaml
kubectl apply -f manifests/netpol-allow-analytics-service.yaml

# services
helm upgrade --install helep ./charts/helep -n helep \
  --set global.tag=0.1.0 \
  --set global.jwtSecret=$(openssl rand -base64 32)

# monitoring
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm upgrade --install prom prometheus-community/kube-prometheus-stack \
  -n observability -f manifests/prometheus-values.yaml
```

Submission form: https://forms.gle/9QCvLTMV3CSZpxPc8
