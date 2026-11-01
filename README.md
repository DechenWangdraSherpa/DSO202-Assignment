# DSO202 Assignments 01, 02 & 03: Task Tracker on Kubernetes

Dechen Wangdra Sherpa (02230281), College of Science and Technology, Royal University of Bhutan
Module: DSO202 Scaling, Orchestration, Monitoring & Observability

A three-tier Task Tracker (frontend, backend, PostgreSQL) deployed to a local kind cluster. Each assignment builds on the one before it.

## Reports

| # | Topic | Report |
|---|---|---|
| 01 | Three-tier deployment with plain manifests | [Reports/Assignment-01.md](Reports/Assignment-01.md) |
| 02 | Unit 2: StatefulSet, RBAC, CRD, Ingress | [Reports/Assignment-02.md](Reports/Assignment-02.md) |
| 03 | Kustomize and Helm packaging | [Reports/Assignment-03.md](Reports/Assignment-03.md) |

## Layout

```
.
├── README.md
├── docker-compose.yml
├── backend/                         Backend source and Dockerfile
├── db/                              Database image and seed data
├── frontend/                        Frontend source and Dockerfile
├── k8s/                             Assignment 01 manifests
│   ├── assignment02/                Assignment 02 manifests
│   └── assignment03/                Assignment 03
│       ├── kustomize/               base/ and overlays/ (dev, prod)
│       └── helm/                    task-tracker chart and environments/ values
├── Reports/                         Assignment-01.md, Assignment-02.md, Assignment-03.md
└── evidence/screenshots/
    ├── assignment01/
    ├── assignment02/
    └── assignment03/
```

## Images

The images are public on Docker Hub (amd64):

- `dwangshers/dso202-amd64-db:1.0`
- `dwangshers/dso202-amd64-backend:1.0`
- `dwangshers/dso202-amd64-frontend:1.0`

## Run Assignment 01

Create the kind cluster and apply the manifests in `k8s/` in order. The full steps are in the "Reproducing" section of [Reports/Assignment-01.md](Reports/Assignment-01.md).

## Run Assignment 02

Apply the manifests in `k8s/assignment02/` on top of Assignment 01. The commands are in section 5 of [Reports/Assignment-02.md](Reports/Assignment-02.md).

## Run Assignment 03

Render, apply and test the Kustomize overlays and the Helm chart in `k8s/assignment03/`. The commands are in section 6 of [Reports/Assignment-03.md](Reports/Assignment-03.md).