# Secure Secrets on EKS: AWS Secrets Manager → External Secrets Operator → ArgoCD

**Account:** `237974319000` &nbsp;|&nbsp; **Region:** `ap-south-1` &nbsp;|&nbsp; **Namespace:** `dev`
**Secret:** `dev/myapp/all-secrets`

---

## Architecture

```
AWS Secrets Manager (dev/myapp/all-secrets)
        │  (IAM role via IRSA)
        ▼
External Secrets Operator (in-cluster)
        │  (creates/refreshes)
        ▼
Native K8s Secrets (apigateway-secret, hotelservice-secret, ratingservice-secret,
                     registry-secret, userservice-secret)
        │  (envFrom / secretKeyRef)
        ▼
Your microservice Pods  ◄── deployed/synced by ArgoCD from your Helm chart repo
```

**Prerequisites:** an existing EKS cluster, and `kubectl`, `aws` CLI (configured with an admin/cluster-admin profile), `helm`, and `eksctl` installed locally.

---

## Step 1 — Create the secret in AWS Secrets Manager

You already have this. Run it once (use `update-secret` later if values change):

```bash
aws secretsmanager create-secret \
  --name dev/myapp/all-secrets \
  --region ap-south-1 \
  --secret-string '{
    "apigatewayservice": {
      "EUREKA_DEFAULT_ZONE": "http://serviceregistry-service:8761/registry/eureka/"
    },
    "hotelservice": {
      "MYSQL_ROOT": "actual-root-password",
      "MYSQL_PASSWORD": "actual-db-password",
      "DATABASE_URL": "jdbc:mysql://<host>:3306/hotelservice",
      "SERVER_PORT": "8082",
      "EUREKA_DEFAULT_ZONE": "http://serviceregistry-service:8761/registry/eureka/"
    },
    "ratingservice": {
      "SERVER_PORT": "8083"
    },
    "serviceregistry": {
      "CONTEXT_PATH": "/registry",
      "SERVER_PORT": "8761"
    },
    "userservice": {
      "EUREKA_DEFAULT_ZONE": "http://serviceregistry-service:8761/registry/eureka/"
    }
  }'
```

To update later without recreating:

```bash
aws secretsmanager update-secret \
  --secret-id dev/myapp/all-secrets \
  --region ap-south-1 \
  --secret-string file://all-secrets.json
```

Get the ARN — you'll need it for the IAM policy in Step 2:

```bash
aws secretsmanager describe-secret \
  --secret-id dev/myapp/all-secrets \
  --region ap-south-1 \
  --query 'ARN' --output text
```

It will look like:
`arn:aws:secretsmanager:ap-south-1:237974319000:secret:dev/myapp/all-secrets-XXXXXX`

---

## Step 2 — Create the IAM policy

This policy grants read-only access to exactly this one secret (least privilege).

```bash
cat > eso-secrets-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ReadMyAppSecret",
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ],
      "Resource": "arn:aws:secretsmanager:ap-south-1:237974319000:secret:dev/myapp/all-secrets-*"
    }
  ]
}
EOF

aws iam create-policy \
  --policy-name external-secrets-myapp-dev-policy \
  --policy-document file://eso-secrets-policy.json
```

Note the returned `Arn`, e.g.:
`arn:aws:iam::237974319000:policy/external-secrets-myapp-dev-policy`

---

## Step 3 — Confirm the OIDC provider exists on your EKS cluster

IRSA (IAM Roles for Service Accounts) requires an OIDC identity provider associated with the cluster.

```bash
CLUSTER_NAME=eks-cluster

eksctl utils associate-iam-oidc-provider \
  --cluster $CLUSTER_NAME \
  --region ap-south-1 \
  --approve
```

This is idempotent — safe to run even if it already exists.

---

## Step 4 — Create the Kubernetes ServiceAccount + IAM Role (IRSA) for External Secrets Operator

`eksctl` handles IAM role creation, the trust policy, and policy attachment in one command:

```bash
eksctl create iamserviceaccount \
  --name external-secrets-sa \
  --namespace external-secrets \
  --cluster $CLUSTER_NAME \
  --region ap-south-1 \
  --attach-policy-arn arn:aws:iam::237974319000:policy/external-secrets-myapp-dev-policy \
  --approve \
  --override-existing-serviceaccounts
```

This creates:
- A namespace-scoped ServiceAccount `external-secrets-sa` in namespace `external-secrets` (create the namespace first if `eksctl` doesn't auto-create it: `kubectl create ns external-secrets`)
- An IAM role trusted only by that ServiceAccount (via OIDC federation)
- The policy attached to that role

Verify:

```bash
kubectl get sa external-secrets-sa -n external-secrets -o yaml
```

You should see an annotation like:

```yaml
eks.amazonaws.com/role-arn: arn:aws:iam::237974319000:role/eksctl-...-external-secrets-sa
```

---

## Step 5 — Install External Secrets Operator via Helm

```bash
helm repo add external-secrets https://charts.external-secrets.io
helm repo update

helm install external-secrets external-secrets/external-secrets \
  -n external-secrets \
  --create-namespace \
  --set serviceAccount.create=false \
  --set serviceAccount.name=external-secrets-sa
```

`serviceAccount.create=false` + `serviceAccount.name` points the operator's pods at the IRSA-annotated ServiceAccount from Step 4, instead of letting Helm create a fresh one without the IAM role annotation.

Verify pods are running:

```bash
kubectl get pods -n external-secrets
```

---

## Step 6 — Create the `ClusterSecretStore`

This tells ESO *where* to pull secrets from. It's cluster-scoped, so any namespace (including `dev`) can reference it.

```yaml
# cluster-secret-store.yaml
apiVersion: external-secrets.io/v1
kind: ClusterSecretStore
metadata:
  name: aws-secretsmanager-store
spec:
  provider:
    aws:
      service: SecretsManager
      region: ap-south-1
      auth:
        jwt:
          serviceAccountRef:
            name: external-secrets-sa
            namespace: external-secrets
```

```bash
kubectl apply -f cluster-secret-store.yaml
kubectl get clustersecretstore aws-secretsmanager-store -o yaml
```

Check `status.conditions` shows `Ready: True`. If it errors, it's almost always an IAM trust policy / OIDC subject mismatch — re-run Step 4.

---

## Step 7 — Create `ExternalSecret` resources (one per microservice)

Each `ExternalSecret` pulls one top-level JSON key (`property:`) out of `dev/myapp/all-secrets` and materializes it as a real K8s `Secret` with the exact name your `values.yaml` already references (`secretName`). Template these into your Helm chart (e.g. `templates/external-secrets.yaml`, or one file per service) so they deploy alongside everything else via ArgoCD.

Add the shared config these templates reference to your chart's `values.yaml`:

```yaml
namespace: dev

externalSecrets:
  secretStoreName: aws-secretsmanager-store
  awsSecretKey: dev/myapp/all-secrets
  refreshInterval: 1h   # lower to e.g. 5m in dev for faster propagation
```

**apigatewayservice**

```yaml
{{- if .Values.apigatewayservice.secretName }}
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: {{ .Values.apigatewayservice.secretName }}
  namespace: {{ .Values.namespace }}
spec:
  refreshInterval: {{ .Values.externalSecrets.refreshInterval }}
  secretStoreRef:
    name: {{ .Values.externalSecrets.secretStoreName }}
    kind: ClusterSecretStore
  target:
    name: {{ .Values.apigatewayservice.secretName }}
    creationPolicy: Owner
  dataFrom:
    - extract:
        key: {{ .Values.externalSecrets.awsSecretKey }}
        property: apigatewayservice
{{- end }}
```

**hotelservice**

```yaml
{{- if .Values.hotelservice.secretName }}
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: {{ .Values.hotelservice.secretName }}
  namespace: {{ .Values.namespace }}
spec:
  refreshInterval: {{ .Values.externalSecrets.refreshInterval }}
  secretStoreRef:
    name: {{ .Values.externalSecrets.secretStoreName }}
    kind: ClusterSecretStore
  target:
    name: {{ .Values.hotelservice.secretName }}
    creationPolicy: Owner
  dataFrom:
    - extract:
        key: {{ .Values.externalSecrets.awsSecretKey }}
        property: hotelservice
{{- end }}
```

**ratingservice**

```yaml
{{- if .Values.ratingservice.secretName }}
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: {{ .Values.ratingservice.secretName }}
  namespace: {{ .Values.namespace }}
spec:
  refreshInterval: {{ .Values.externalSecrets.refreshInterval }}
  secretStoreRef:
    name: {{ .Values.externalSecrets.secretStoreName }}
    kind: ClusterSecretStore
  target:
    name: {{ .Values.ratingservice.secretName }}
    creationPolicy: Owner
  dataFrom:
    - extract:
        key: {{ .Values.externalSecrets.awsSecretKey }}
        property: ratingservice
{{- end }}
```

**serviceregistry**

```yaml
{{- if .Values.serviceregistry.secretName }}
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: {{ .Values.serviceregistry.secretName }}
  namespace: {{ .Values.namespace }}
spec:
  refreshInterval: {{ .Values.externalSecrets.refreshInterval }}
  secretStoreRef:
    name: {{ .Values.externalSecrets.secretStoreName }}
    kind: ClusterSecretStore
  target:
    name: {{ .Values.serviceregistry.secretName }}
    creationPolicy: Owner
  dataFrom:
    - extract:
        key: {{ .Values.externalSecrets.awsSecretKey }}
        property: serviceregistry
{{- end }}
```

**userservice**

```yaml
{{- if .Values.userservice.secretName }}
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: {{ .Values.userservice.secretName }}
  namespace: {{ .Values.namespace }}
spec:
  refreshInterval: {{ .Values.externalSecrets.refreshInterval }}
  secretStoreRef:
    name: {{ .Values.externalSecrets.secretStoreName }}
    kind: ClusterSecretStore
  target:
    name: {{ .Values.userservice.secretName }}
    creationPolicy: Owner
  dataFrom:
    - extract:
        key: {{ .Values.externalSecrets.awsSecretKey }}
        property: userservice
{{- end }}
```

The `{{- if .Values.<service>.secretName }}` guard means a service without a `secretName` set simply won't get an `ExternalSecret` rendered — no need to comment templates in/out per environment.

After `helm template`/ArgoCD sync, verify each one:

```bash
kubectl get externalsecret -n dev
kubectl get externalsecret hotelservice-secret -n dev -o yaml   # status.conditions → SecretSynced: True
kubectl get secret hotelservice-secret -n dev -o yaml           # confirm base64-encoded keys exist
```

`hotelservice-secret` should show base64-encoded `MYSQL_ROOT`, `MYSQL_PASSWORD`, `DATABASE_URL`, `SERVER_PORT`, and `EUREKA_DEFAULT_ZONE`.

---

## Step 8 — Update your Helm chart to stop templating raw `secretData`

Since ESO now owns creation of the `Secret` objects, remove any plaintext `secretData:` blocks from `values.yaml` and **delete any `Secret` template** in your chart that renders `secretData` into a `kind: Secret` manifest. Otherwise ArgoCD/Helm will fight with ESO for ownership of the same object and cause sync flapping.

Your Deployment templates just need to keep referencing the secret name via `envFrom`:

```yaml
# templates/deployment.yaml (relevant excerpt)
envFrom:
  - secretRef:
      name: {{ .Values.hotelservice.secretName }}
```

Your `values.yaml` for each service now only needs:

```yaml
hotelservice:
  name: hotelservice
  replicas: 1
  image:
    repository: 237974319000.dkr.ecr.ap-south-1.amazonaws.com/hotelservice
    tag: v1
  secretName: hotelservice-secret   # just the name — content comes from ESO
```

Commit this to the Git repo your ArgoCD `Application` will track.

---

## Step 9 — Install ArgoCD

```bash
kubectl create namespace argocd

kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

kubectl get pods -n argocd -w
```

Get the initial admin password:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
```

Access the UI (quick way, port-forward):

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Then browse to `https://localhost:8080` and log in as `admin` with the password above. (For production, expose via an ALB Ingress instead of port-forward — the same ALB ingress pattern you're already using for `frontend-ingress`/`java-ingress`.)

Log in via CLI as well (useful for scripting):

```bash
argocd login localhost:8080 --username admin --password <password> --insecure
```

---

## Step 10 — Create the ArgoCD `Application` for your Helm chart

```yaml
# argocd-application.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: myapp-dev
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/<your-org>/<your-repo>.git
    targetRevision: main
    path: <path-to-your-helm-chart>
    helm:
      valueFiles:
        - values.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: dev
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

```bash
kubectl apply -f argocd-application.yaml
```

`selfHeal: true` means ArgoCD will keep reconciling drift automatically. This is safe here because the `Secret` objects in this namespace are the ones ESO manages (`creationPolicy: Owner`), and per Step 8 your Helm chart no longer templates `kind: Secret` at all — so there's no ownership conflict between ArgoCD and ESO.

Check sync status:

```bash
argocd app get myapp-dev
argocd app sync myapp-dev
```

---

## Step 11 — Verify end to end

```bash
kubectl get pods -n dev
kubectl get externalsecret -n dev
kubectl describe pod <hotelservice-pod> -n dev   # check env vars are populated
```

If a pod's env var is missing or empty, check in this order:

1. `kubectl get externalsecret <name> -n dev -o yaml` → status conditions
2. `kubectl logs -n external-secrets deploy/external-secrets` → IAM/auth errors
3. `kubectl get secret <name> -n dev -o yaml` → confirm keys exist
4. Helm template `envFrom.secretRef.name` matches `target.name` in the `ExternalSecret`

---

## Ongoing secret rotation

Update the value in Secrets Manager only — no redeploy needed:

```bash
aws secretsmanager put-secret-value \
  --secret-id dev/myapp/all-secrets \
  --region ap-south-1 \
  --secret-string file://all-secrets.json
```

ESO picks it up within `refreshInterval` (1h by default in the examples above; lower it, e.g. `5m`, in dev if you want faster propagation) and updates the K8s `Secret`. Pods reading env vars via `envFrom` still need a rolling restart to pick up new values — Kubernetes doesn't hot-reload env vars into a running container. If that matters, add the [Reloader](https://github.com/stakater/Reloader) controller to auto-restart pods on Secret change.



 argocd login 52.53.156.187:32738 --username admin

 kubectl config get-contexts

 argocd cluster add  arn:aws:eks:ap-south-1:237974319000:cluster/my-eks-cluster --name java-app