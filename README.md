# DSO202 – Assignment 01 & 02

Task Tracker (frontend + backend + PostgreSQL) deployed to a local `kind` cluster.

## Reports

| Assignment | Report |
|---|---|
| 01 | [Reports/Assignment-01.md](Reports/Assignment-01.md) |
| 02 | [Reports/Assignment-02.md](Reports/Assignment-02.md) |

## Repository layout

```
backend/ db/ frontend/        application source and Dockerfiles
k8s/                          Kubernetes manifests
  00-namespace.yaml ... 03-secret.yaml
  database/ backend/ frontend/
evidence/screenshots/
  assignment01/  assignment02/
Reports/                      reports in markdown
docker-compose.yml
```

## Images (linux/amd64)

- `dwangshers/dso202-amd64-db:1.0`
- `dwangshers/dso202-amd64-backend:1.0`
- `dwangshers/dso202-amd64-frontend:1.0`

## Run Assignment 01

Needs the `dso202` kind cluster from Practical 1 (port 30080 mapped).

```bash
kubectl apply -f k8s/00-namespace.yaml
kubectl apply -f k8s/01-quota-and-limits.yaml
kubectl apply -f k8s/02-configmap.yaml -f k8s/03-secret.yaml
kubectl apply -f k8s/database/
kubectl apply -f k8s/backend/
kubectl apply -f k8s/frontend/
kubectl get all -n dso202-assignment-01
```

Open http://localhost:30080.
