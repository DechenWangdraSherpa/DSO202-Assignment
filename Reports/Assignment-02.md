# Assignment 2: Applying Unit 2 Concepts to the Task Tracker

Submitted by Dechen Wangdra Sherpa (02230281)
Repository: https://github.com/DechenWangdraSherpa/DSO202-Assignment.git

---

## 1. Objective

Assignment 2 continues from Assignment 1. I took the three-tier Task Tracker that was already running in the `dso202-assignment-01` namespace and improved it using the Unit 2 lecture topics:

| Unit 2 topic | What I did in the Task Tracker |
|---|---|
| 2.1 StatefulSets | Moved the database from a Deployment to a StatefulSet |
| 2.2 Ingress | Replaced the NodePort entry point with an Ingress |
| 2.3 RBAC | Gave each workload its own ServiceAccount and added least-privilege Roles |
| 2.4 Operators | Added a CustomResourceDefinition for the database and created one custom resource |

The application code and images did not change. All the work is in Kubernetes configuration.

## 2. Environment

- Kali Linux (x86_64), kind cluster `dso202` (1 control-plane, 2 workers), Kubernetes v1.36.1
- Same namespace, quota and amd64 images as Assignment 1
- Assignment 1 manifests in `k8s/` are untouched. Everything new is in `k8s/assignment02/`.

| File | Purpose |
|---|---|
| `01-db-statefulset.yaml` | Database StatefulSet |
| `02-rbac.yaml` | ServiceAccounts, Roles, RoleBindings |
| `03-backend-deployment.yaml`, `04-frontend-deployment.yaml` | Workloads using their ServiceAccounts |
| `05-taskdatabase-crd.yaml`, `06-taskdatabase-cr.yaml` | CRD and custom resource |
| `07-ingress.yaml` | Ingress rules |
| `08-configmap.yaml` | `app-config` with the new `BACKEND_URL` |

## 3. Implementation and verification

### 3.1 StatefulSet for the database (2.1)

In Assignment 1 the database was a Deployment with a separate PVC. A Deployment gives its pod a random name, so nothing about the database's identity is stable. I replaced it with a StatefulSet named `database`:

- `serviceName: db-svc` reuses the existing headless Service, so the pod gets a stable DNS name.
- `volumeClaimTemplates` creates the PVC `db-data-database-0` automatically for the pod.
- `persistentVolumeClaimRetentionPolicy` is set to `Retain` so the data is never deleted by accident.
- `replicas: 1`. PostgreSQL replication is not configured, so extra replicas would just be separate empty databases.

The pod labels must match the `db-svc` selector (`app=task-tracker`, `tier=database`). My first attempt used different labels, which is covered in section 4.

After the fix, `db-svc` has an endpoint and the StatefulSet, pod `database-0` and its PVC are running:

![StatefulSet, pod and PVC](../evidence/screenshots/assignment02/A2-02-statefulset.png)

**Stable identity.** The pod name and its DNS name are fixed:

![Stable DNS name and hostname](../evidence/screenshots/assignment02/A2-03-stable-identity.png)

**Persistence test.** I created a task, deleted the pod, and checked the task was still there.

Before the delete (tasks 1-3 are the seed data, 5 is my new task):

![Before deleting the pod](../evidence/screenshots/assignment02/A2-04a-before-delete.png)

The pod comes back with the same name, `database-0`:

![Pod recreated](../evidence/screenshots/assignment02/A2-04b-pod-recreated.png)

After the delete, the task is still there and the PVC is the same volume:

![After deleting the pod](../evidence/screenshots/assignment02/A2-04c-after-delete.png)

### 3.2 RBAC (2.3)

By default every pod uses the namespace's `default` ServiceAccount. The backend and frontend never call the Kubernetes API, so I gave them their own ServiceAccounts with no permissions and with the token not mounted. I also created two identities with narrow permissions:

| ServiceAccount | Role | Allowed |
|---|---|---|
| `backend-sa`, `frontend-sa` | none | nothing, no API token |
| `app-viewer` | `pod-and-service-reader` | get, list, watch pods and services |
| `deployer` | `deployer-role` | create, update, patch deployments, services, configmaps (no delete, no Secrets) |

The Role for `deployer` includes `patch` because `kubectl apply` on an existing object sends a `patch` request, not `update`.

![RBAC objects](../evidence/screenshots/assignment02/A2-05-rbac-objects.png)

I checked the permissions with `kubectl auth can-i`:

| Check | Result |
|---|---|
| viewer: list pods | yes |
| viewer: delete pods | no |
| viewer: get secrets | no |
| viewer: list pods in `kube-system` | no |
| deployer: patch deployments | yes |
| deployer: delete deployments | no |
| deployer: get secrets | no |

![can-i checks](../evidence/screenshots/assignment02/A2-06-can-i-checks.png)

Then I switched the backend and frontend Deployments to their ServiceAccounts:

![Workloads using their ServiceAccounts](../evidence/screenshots/assignment02/A2-07-workload-serviceaccounts.png)

No token exists inside the backend pod any more, and the app still works:

![No token mounted, app still healthy](../evidence/screenshots/assignment02/A2-08-no-token-app-ok.png)

### 3.3 CRD and the Operator pattern (2.4)

I defined a new resource type, `TaskDatabase`, that describes the database in simple terms (PostgreSQL version, replicas, storage size), and created one object of it, `task-db`.

![CRD installed](../evidence/screenshots/assignment02/A2-09-crd-installed.png)

The API server accepts and stores `task-db`, but nothing new is created. There is no new StatefulSet or pod, and the `status` is empty:

![Custom resource created, nothing happens](../evidence/screenshots/assignment02/A2-10-custom-resource.png)

This is the point of the Operator pattern: a CRD only teaches Kubernetes a new noun. An Operator (a controller that watches `TaskDatabase` objects) is what would create the StatefulSet, handle failover and take backups. I did not install a real Operator such as CloudNativePG, because it is heavy for a laptop cluster.

### 3.4 Ingress (2.2)

In Assignment 1 the frontend was exposed with a NodePort, and the browser called the backend directly. I replaced this with one Ingress that routes by path:

- `/` goes to `frontend-svc:80`
- `/api` goes to `backend-svc:8080`

**Installing the controller.** An Ingress does nothing without an Ingress controller. I labelled the control-plane node `ingress-ready=true` and installed the ingress-nginx manifest for kind.

![Ingress controller running](../evidence/screenshots/assignment02/A2-11-ingress-controller.png)

**The rules.** I did not use a `rewrite-target` annotation, because the backend routes already start with `/api` and a rewrite would strip it.

![Ingress rules](../evidence/screenshots/assignment02/A2-12-ingress-rules.png)

**Routing test.** My cluster only publishes port 30080, so I reached the controller with `kubectl port-forward` on port 8081. `/api/status` works, `/` returns 200, and a request for a different host returns 404, which shows routing is by hostname:

![Routing test](../evidence/screenshots/assignment02/A2-13-ingress-routing-test.png)

**Making the browser work.** The frontend calls whatever `BACKEND_URL` says. I set it to `http://tasktracker.local:8081` in the ConfigMap, added `127.0.0.1 tasktracker.local` to `/etc/hosts`, and restarted the frontend so it picked up the new value:

![ConfigMap updated](../evidence/screenshots/assignment02/A2-14-configmap-updated.png)

The Task Tracker now works end to end through the Ingress, including the task created before the database pod was deleted:

![Task Tracker through the Ingress](../evidence/screenshots/assignment02/A2-15-ui-via-ingress.png)

### 3.5 Final state

![Workloads](../evidence/screenshots/assignment02/A2-16a-final-workloads.png)

![Custom resource and RBAC objects](../evidence/screenshots/assignment02/A2-16b-final-rbac-crd.png)

## 4. Problems I met

| Problem | Cause | Fix |
|---|---|---|
| `db-svc` had no endpoints after my first StatefulSet | Its pods were labelled `app=db`, but `db-svc` selects `app=task-tracker,tier=database` | Matched the labels and recreated the StatefulSet. Evidence: `A2-01-selector-mismatch.png`, then `A2-02` |
| `nslookup database-0.db-svc` returned NXDOMAIN | The BusyBox `nslookup` in the Alpine image does not expand short names through the search domains | Used the full name `database-0.db-svc.dso202-assignment-01.svc.cluster.local` |
| `can-i list pods` for the viewer wrongly said `no` | In zsh, `$NS:app-viewer` treats `:a` as a path modifier, so the identity name was wrong | Wrote the variable as `${NS}` and re-ran all checks |
| Browser showed "backend unreachable" | In Assignment 1 `BACKEND_URL` was `http://backend-svc:8080`, which only worked with a hosts entry plus a running port-forward | Routed the browser through the Ingress with one hostname |

![Selector mismatch](../evidence/screenshots/assignment02/A2-01-selector-mismatch.png)

## 5. Reproducing

Start from the Assignment 1 setup (steps in `Reports/Assignment-01.md`), then:

```bash
# 2.1 database: replace the Deployment and PVC with the StatefulSet
kubectl delete -f k8s/database/01-deployment.yaml -f k8s/database/00-pvc.yaml
kubectl apply  -f k8s/assignment02/01-db-statefulset.yaml

# 2.3 RBAC and workloads
kubectl apply -f k8s/assignment02/02-rbac.yaml
kubectl apply -f k8s/assignment02/03-backend-deployment.yaml -f k8s/assignment02/04-frontend-deployment.yaml

# 2.4 CRD
kubectl apply -f k8s/assignment02/05-taskdatabase-crd.yaml
kubectl apply -f k8s/assignment02/06-taskdatabase-cr.yaml

# 2.2 Ingress
kubectl label node control-plane ingress-ready=true
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
kubectl wait -n ingress-nginx --for=condition=ready pod -l app.kubernetes.io/component=controller --timeout=300s
kubectl apply -f k8s/assignment02/07-ingress.yaml
kubectl apply -f k8s/assignment02/08-configmap.yaml
kubectl rollout restart deploy/frontend -n dso202-assignment-01

echo "127.0.0.1 tasktracker.local" | sudo tee -a /etc/hosts
kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8081:80
```

Then open http://tasktracker.local:8081. Note that applying Assignment 1's `k8s/02-configmap.yaml` again would reset `BACKEND_URL` to its old value.

## 6. Limitations

- The database pod still uses the `default` ServiceAccount. Only the backend and frontend have their own.
- The StatefulSet has one replica, and no Operator is running, so the `TaskDatabase` object does nothing yet.
- The Ingress uses plain HTTP. TLS termination (with a Secret) was not set up.
- ingress-nginx was retired in March 2026. I used it because the lecture practical does, but a real project should plan a move to another controller or the Gateway API.
- The Ingress is reached through `kubectl port-forward`, because the kind cluster only publishes port 30080.

## 7. Conclusion

The Task Tracker from Assignment 1 now uses the Unit 2 concepts. The database has a stable identity and its own storage as a StatefulSet and survived a pod delete. The workloads run with their own ServiceAccounts, and the permissions were checked with `can-i`. A CRD describes the database in its own terms, and one Ingress replaces the NodePort as the single entry point.