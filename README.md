# DSO202 – Assignment 01 & 02

Task Tracker (frontend + backend + PostgreSQL) deployed to a local `kind` cluster.
Assignment 02 improves it with Unit 2 concepts: StatefulSet, RBAC, CRD and Ingress.

## Reports

| Assignment | Report |
|---|---|
| 01 | [Reports/Assignment-01.md](Reports/Assignment-01.md) |
| 02 | [Reports/Assignment-02.md](Reports/Assignment-02.md) |

## Repository layout

```
backend/ db/ frontend/        application source and Dockerfiles
k8s/                          Assignment 01 manifests
  00-namespace.yaml ... 03-secret.yaml
  database/ backend/ frontend/
  assignment02/               Assignment 02 manifests (01 to 08)
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
```

Open http://localhost:30080.

## Run Assignment 02

Runs on top of Assignment 01. Full steps are in [Reports/Assignment-02.md](Reports/Assignment-02.md#5-reproducing).
Then open http://tasktracker.local:8081 (needs the hosts entry and the Ingress port-forward).