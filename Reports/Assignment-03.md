# Assignment 3: Applying Unit 4 Concepts (Kustomize and Helm) to the Task Tracker

Submitted by Dechen Wangdra Sherpa (02230281)
Repository: https://github.com/DechenWangdraSherpa/DSO202-Assignment.git

---

## 1. Objective

Assignment 3 continues from Assignment 1. I took the same three-tier Task Tracker and packaged it with the two tools from Unit 4:

| Tool | What I did |
|---|---|
| Kustomize | One shared `base/` made from my Assignment 1 manifests, plus a `dev` and a `prod` overlay |
| Helm | One chart, `task-tracker`, with values files for `dev` and `prod`, a values schema, and a full release lifecycle (install, upgrade, rollback, uninstall) |

The application code and images did not change (`dwangshers/dso202-amd64-{db,backend,frontend}:1.0`). All the work is in configuration.

## 2. Environment

- Kali Linux (x86_64), kind cluster `dso202` (1 control-plane, 2 workers), Kubernetes v1.36.1
- Helm v4.3.1, kubectl v1.36.5 with Kustomize v5.8.1

![Tools check](../evidence/screenshots/assignment03/A3-01-tools-check.png)

Everything new is in `k8s/assignment03/`. The Assignment 1 manifests in `k8s/` and the Assignment 2 app in `dso202-assignment-01` were not touched.

| Path | Purpose |
|---|---|
| `kustomize/base/` | Shared Deployments, Services and PVC from Assignment 1, plus `config.env` and `secret.env` for the generators |
| `kustomize/overlays/dev/` | Namespace `a3-kustomize-dev` and the environment label |
| `kustomize/overlays/prod/` | Namespace `a3-kustomize-prod`, replicas, resource patch, `BACKEND_URL` merge, JSON 6902 patch |
| `helm/task-tracker/` | The chart: `Chart.yaml`, `values.yaml`, `values.schema.json`, `templates/` |
| `helm/environments/` | `dev.yaml` and `prod.yaml` values files |

**Namespaces.** Each environment has its own namespace (`a3-kustomize-dev`, `a3-kustomize-prod`, `a3-helm-dev`, `a3-helm-prod`) so nothing clashes with the Assignment 2 app, which is still running.

## 3. Implementation and verification

### 3.1 Kustomize base

The lecture rule is: the base stores what is shared. I copied the Assignment 1 Deployments, Services and PVC into `base/`. The ConfigMap and Secret became generators (`configMapGenerator` and `secretGenerator`) that read `config.env` and `secret.env`, so I did not copy them as YAML files.

![Base files](../evidence/screenshots/assignment03/A3-02-base-files.png)

![Base kustomization.yaml](../evidence/screenshots/assignment03/A3-03-base-kustomization.png)

Rendering the base with `kubectl kustomize .` showed the generated names with a content hash, `app-config-m2gfc99fb6` and `app-secret-g54k576c5g`. The first render had a problem, which is described in section 5. After the fix, every `configMapKeyRef` and `secretKeyRef` in the Deployments pointed at the hashed names:

![References not rewritten (before the fix)](../evidence/screenshots/assignment03/A3-04a-refs-not-rewritten.png)

![References rewritten (after the fix)](../evidence/screenshots/assignment03/A3-04b-refs-rewritten.png)

### 3.2 Overlays for dev and prod

An overlay stores only what is different. Dev is almost empty, and prod holds the changes:

| | dev | prod |
|---|---|---|
| Namespace | `a3-kustomize-dev` | `a3-kustomize-prod` |
| Label `dso202/environment` | dev | prod |
| Replicas | base values | backend 2, frontend 2 (`replicas:` field) |
| `BACKEND_URL` | `localhost:8081` | `localhost:8082` (generator `behavior: merge`) |
| Backend resources | base values | larger, with a strategic-merge patch |
| Frontend env | base values | extra `ENV_NAME=prod`, with a JSON 6902 patch |

I used `includeSelectors: false` on the labels so no selector changes. I did not use `namePrefix`, because the app finds the database by the name `db-svc` and Kustomize does not rewrite env values.

![Overlay files](../evidence/screenshots/assignment03/A3-05-overlay-files.png)

Rendered YAML is the truth, so I rendered both overlays and compared them with `diff`. The differences were exactly the ones in the table, and the ConfigMap hash changed from `m2gfc99fb6` to `7cf2bc788c`:

![Dev vs prod diff, part 1](../evidence/screenshots/assignment03/A3-06a-diff.png)

![Dev vs prod diff, part 2](../evidence/screenshots/assignment03/A3-06b-diff.png)

![Dev vs prod diff, part 3](../evidence/screenshots/assignment03/A3-06c-diff.png)

### 3.3 Applying dev and the generated-name hash

`kubectl apply -k overlays/dev` created everything except the frontend Service, which failed (section 5):

![NodePort conflict](../evidence/screenshots/assignment03/A3-07a-nodeport-conflict.png)

![Dev pods before the fix](../evidence/screenshots/assignment03/A3-08a-dev-pods-before-fix.png)

After the fix, the apply worked, and the dev environment was complete:

![Dev applied after the fix](../evidence/screenshots/assignment03/A3-07b-dev-apply-fixed.png)

![Dev services and deployments](../evidence/screenshots/assignment03/A3-08b-dev-services.png)

I used port-forward to test it. The backend reported the database as connected, and the Task Tracker UI worked and saved a new task:

![Dev curl](../evidence/screenshots/assignment03/A3-09-dev-curl.png)

![Dev UI](../evidence/screenshots/assignment03/A3-10-dev-ui.png)

**The hash demo.** I changed `CORS_ORIGIN` in `config.env`. `kubectl diff -k` showed the new ConfigMap name `app-config-8bdd28c44k` and every Deployment moving from the old name to the new one:

![Hash diff](../evidence/screenshots/assignment03/A3-11-hash-diff.png)

After `kubectl apply -k`, all three Deployments rolled out new pods. This is the chain from the lecture: content changes, the hash changes, the references change, the pod template changes, and a rollout follows. The old ConfigMap stays until it is deleted, because `apply` does not prune:

![Hash rollout](../evidence/screenshots/assignment03/A3-12-hash-rollout.png)

### 3.4 Applying prod

The same base with the prod overlay gave backend 2/2, frontend 2/2 and database 1/1, all labelled `prod`:

![Prod running](../evidence/screenshots/assignment03/A3-13-prod-running.png)

The three prod techniques each showed in the live objects: the larger backend limits (strategic merge), `ENV_NAME` in the frontend env (JSON 6902), and `BACKEND_URL` of 8082 (generator merge):

![Prod checks](../evidence/screenshots/assignment03/A3-14-prod-checks.png)

I removed both environments with `kubectl delete -k`. Because each overlay includes its Namespace, deleting the overlay removed the whole environment. The Assignment 2 namespace was not touched:

![Kustomize cleanup](../evidence/screenshots/assignment03/A3-15-kustomize-cleanup.png)

### 3.5 Helm chart

I wrote the chart by hand from my own manifests, not with `helm create`. It has:

- `Chart.yaml` with `version: 0.1.0` (the chart) and `appVersion: "1.0"` (the image tag, used as the default tag)
- `values.yaml` as the configuration interface: image, config, credentials, and resources and replicas per tier
- `templates/` with a ConfigMap, a Secret, and the database (PVC, Deployment, headless Service), backend and frontend files
- `_helpers.tpl` with named templates for labels and a required `environment`
- checksum annotations on the pods, so a config change restarts them (the Helm version of the Kustomize hash)

![Chart skeleton](../evidence/screenshots/assignment03/A3-16-chart-skeleton.png)

![Chart templates and lint](../evidence/screenshots/assignment03/A3-17-chart-templates.png)

### 3.6 Validating the chart

I followed the lecture and made each kind of error visible before installing:

- **No environment chosen.** `helm template` stopped with `environment must be set (dev, staging or prod)` and exit code 1.
- **A good render.** The dev render produced all the objects, with images `dwangshers/...:1.0` taken from `appVersion`.
- **Wrong values.** `values.schema.json` rejected `backend.replicaCount=0` (`minimum: got 0, want 1`) and `config.dbPort=abc` (`got string, want integer`).
- **All environments.** A loop of `helm lint` and `helm template` passed for `dev` and `prod`.

![Required value fails](../evidence/screenshots/assignment03/A3-18-required-fails.png)

![Dev render](../evidence/screenshots/assignment03/A3-19-dev-render.png)

![Schema errors and checks](../evidence/screenshots/assignment03/A3-20-schema-and-checks.png)

### 3.7 Install, upgrade, rollback

**Install.** `helm install tt-dev` created revision 1. Helm also stored the release record as a Secret, `sh.helm.release.v1.tt-dev.v1`:

![Helm install dev](../evidence/screenshots/assignment03/A3-21-helm-install-dev.png)

![Helm dev running](../evidence/screenshots/assignment03/A3-22-helm-dev-running.png)

The app worked the same way as in Assignment 1:

![Helm dev curl](../evidence/screenshots/assignment03/A3-23-helm-dev-curl.png)

![Helm dev UI](../evidence/screenshots/assignment03/A3-24-helm-dev-ui.png)

**Upgrade.** First I ran an upgrade with only a `--set` flag. It started again from the chart defaults, lost the environment, and was refused with exit code 1. This is the values-loss trap from the lecture:

![Upgrade values lost](../evidence/screenshots/assignment03/A3-25-upgrade-values-lost.png)

The correct upgrade passed the values file again with the one change. This made revision 2, and the frontend went to 2/2:

![Helm upgrade](../evidence/screenshots/assignment03/A3-26-helm-upgrade.png)

**Rollback.** `helm rollback tt-dev 1` returned the frontend to 1/1. It did not go back to revision 1, because it created a new revision 3 that copies revision 1. Revisions 1 and 2 stay in the history:

![Helm rollback](../evidence/screenshots/assignment03/A3-27-helm-rollback.png)

### 3.8 Prod release and uninstall

The same chart with `prod.yaml` gave a separate release, `tt-prod`, in `a3-helm-prod`. `helm get values` showed exactly what the file supplied:

![Helm prod install](../evidence/screenshots/assignment03/A3-28-helm-prod-install.png)

![Helm prod checks](../evidence/screenshots/assignment03/A3-29-helm-prod-checks.png)

`helm uninstall` removed every object and release record of each release as one unit. The namespaces stay after an uninstall, because `--create-namespace` does not make them part of the release, so I deleted them separately. The Assignment 2 pods were still Running afterwards:

![Helm uninstall](../evidence/screenshots/assignment03/A3-30-helm-uninstall.png)

Final files for this assignment:

![Final files](../evidence/screenshots/assignment03/A3-31-final-files.png)

## 4. Kustomize and Helm compared

| | Kustomize | Helm |
|---|---|---|
| Method | Patches plain YAML: a base plus overlays | Renders templates with values |
| My input files | Valid Kubernetes YAML | Templates, which are not valid YAML until rendered |
| Built into kubectl | Yes (`kubectl apply -k`) | No, a separate binary |
| Records what was installed | No | Yes, one Secret per revision |
| Rollback | Revert the Git commit and apply again | `helm rollback` |
| Config change restarts pods | Generated-name hash | Checksum annotation |
| Bad input caught early | Render and `kubectl diff -k` | Required values, schema, lint, template |

For my own app and its environments, Kustomize was simpler because the base is real YAML that I already had. Helm gave me release history, a rollback, a typed values interface and one-step removal, which is useful when the app is installed by other people.

## 5. Problems I met

| Problem | Cause | Fix |
|---|---|---|
| In the base render, the generated ConfigMap and Secret had hashed names but the Deployments still referenced `app-config` and `app-secret` | My copied Assignment 1 manifests had `namespace: dso202-assignment-01` hard-coded, while the generated objects had no namespace, so Kustomize did not match them for renaming | Removed the hard-coded namespace from the base copies. Evidence: `A3-04a`, then `A3-04b` |
| `kubectl apply -k overlays/dev` failed on `frontend-svc` with "nodePort 30080 already allocated" | The Assignment 2 frontend Service already holds NodePort 30080, and a host port can be held once | Changed the base frontend Service to `ClusterIP` and used `kubectl port-forward`. Evidence: `A3-07a`, then `A3-07b` |
| An upgrade with only `--set` was refused | `helm upgrade` with a value flag starts again from the chart defaults, so the environment was empty | Pass the values file with `-f` on every upgrade. Evidence: `A3-25`, then `A3-26` |

## 6. Reproducing

Run these from the repository root.

```bash
# Kustomize: render, apply, test, delete
kubectl kustomize k8s/assignment03/kustomize/overlays/dev
kubectl apply -k k8s/assignment03/kustomize/overlays/dev
kubectl wait --for=condition=available deploy --all -n a3-kustomize-dev --timeout=240s
kubectl port-forward -n a3-kustomize-dev svc/backend-svc 8081:8080 &
kubectl port-forward -n a3-kustomize-dev svc/frontend-svc 8080:80 &
# open http://localhost:8080
pkill -f "kubectl port-forward"
kubectl delete -k k8s/assignment03/kustomize/overlays/dev
# prod: the same commands with overlays/prod and namespace a3-kustomize-prod

# Helm: lint, render, install, upgrade, rollback, uninstall
cd k8s/assignment03/helm
helm lint task-tracker -f environments/dev.yaml
helm template tt-dev task-tracker -f environments/dev.yaml -n a3-helm-dev
helm install tt-dev task-tracker -f environments/dev.yaml -n a3-helm-dev --create-namespace --wait
helm upgrade tt-dev task-tracker -f environments/dev.yaml --set frontend.replicaCount=2 -n a3-helm-dev --wait
helm history tt-dev -n a3-helm-dev
helm rollback tt-dev 1 -n a3-helm-dev --wait
helm uninstall tt-dev -n a3-helm-dev
kubectl delete ns a3-helm-dev
```

The Kustomize and Helm dev environments both use the forwards `8081:8080` (backend) and `8080:80` (frontend), so test one at a time. I checked prod with `kubectl` and `helm get values`, not through the UI.

## 7. Limitations

- Credentials are demo values in plain files (`secret.env`, `values.yaml`). Kustomize and Helm do not make them safe: Helm also stores them in the release record Secret.
- I changed `CORS_ORIGIN` in the base `config.env` for the hash demo, and left it as `http://localhost:8080`.
- Object names are fixed (`db-svc`, `app-config` and so on), as in Assignment 1, so there is one release per namespace.
- This assignment packages Assignment 1 only. The Assignment 2 additions (StatefulSet, RBAC, Ingress, CRD) are not in the chart or the overlays.
- The app is reached with `kubectl port-forward`, because NodePort 30080 is used by the Assignment 2 app.
- `kubectl apply -k` does not remove the old generated ConfigMap, and I did not add Helm tests.

## 8. Conclusion

The Task Tracker from Assignment 1 is now packaged two ways. With Kustomize, one base and two thin overlays give the dev and prod environments, and generated hashes restart the pods when configuration changes. With Helm, one chart with validated values gives the same environments as releases with history, rollback and one-step removal. In both, I checked the rendered output before touching the cluster, and I ran the working app from each.