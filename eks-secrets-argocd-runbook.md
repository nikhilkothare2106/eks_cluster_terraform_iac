# Secure Secrets on EKS: AWS Secrets Manager → External Secrets Operator → ArgoCD

**Account:** `$ACCOUNT_ID` (`237974319000`) &nbsp;|&nbsp; **Region:** `ap-south-1` &nbsp;|&nbsp; **Namespace:** `dev`
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
                         ◄── exposed externally via AWS Load Balancer Controller
                             (Ingress → ALB), e.g. frontend-ingress / java-ingress
```

**Prerequisites:**
- An existing EKS cluster.
- `kubectl`, `aws` CLI, `helm`, `eksctl`, and `argocd` CLI installed locally.
- An AWS CLI profile with permissions to create IAM policies/roles, tag EC2 subnets, and manage Secrets Manager secrets. Use a scoped deployment role rather than a long-lived admin/root profile where possible — everything below only needs `iam:CreatePolicy`, `iam:CreateRole` (via `eksctl`), `secretsmanager:*` on the one secret, and `ec2:CreateTags`/`DescribeSubnets`.
- Do not commit `all-secrets.json` or any file containing plaintext secret values to Git. Add it to `.gitignore` immediately if you create one locally.

---

## Step 0 — Set your environment variables

Set these once at the start of your shell session. Every command below uses `$ACCOUNT_ID` and `$CLUSTER_NAME` instead of hardcoding the values, so this is the only place you need to change anything to reuse the guide against a different account or cluster.

```bash
export ACCOUNT_ID=237974319000
export CLUSTER_NAME=eks-cluster
export AWS_REGION=ap-south-1
```

> Added `AWS_REGION` so every later `--region ap-south-1` flag can instead read `--region $AWS_REGION` if you copy this guide to another region — the flags below still show the literal value for clarity, but exporting it now means a find-and-replace is all you need.

---

## Step 1 — Create the secret in AWS Secrets Manager

Run this once (use `update-secret` or `put-secret-value` later if values change — see **Ongoing secret rotation** at the end):

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

> Prefer keeping this JSON in a local `all-secrets.json` file (gitignored) and passing `--secret-string file://all-secrets.json` instead of an inline string — it avoids the value showing up in your shell history and is consistent with how you'll rotate it later.

Get the ARN — you'll need it for the IAM policy in Step 2:

```bash
aws secretsmanager describe-secret \
  --secret-id dev/myapp/all-secrets \
  --region ap-south-1 \
  --query 'ARN' --output text
```

It will look like:
`arn:aws:secretsmanager:ap-south-1:$ACCOUNT_ID:secret:dev/myapp/all-secrets-XXXXXX` (i.e. `arn:aws:secretsmanager:ap-south-1:237974319000:secret:dev/myapp/all-secrets-XXXXXX`)

---

## Step 2 — Create the IAM policy

This policy grants read-only access to exactly this one secret (least privilege). Note the trailing `-*` in the resource ARN — Secrets Manager appends a random 6-character suffix to the secret's ARN, so the wildcard is required for the policy to match regardless of that suffix.

```bash
cat > eso-secrets-policy.json << EOF
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
      "Resource": "arn:aws:secretsmanager:ap-south-1:${ACCOUNT_ID}:secret:dev/myapp/all-secrets-*"
    }
  ]
}
EOF

aws iam create-policy \
  --policy-name external-secrets-myapp-dev-policy \
  --policy-document file://eso-secrets-policy.json
```

> The heredoc above uses an **unquoted** `EOF` (not `'EOF'`) so `$ACCOUNT_ID` gets substituted into the JSON file when it's written. Make sure `ACCOUNT_ID` is exported (Step 0) before running this — if `create-policy` fails with `MalformedPolicyDocument`, check that the file doesn't contain a literal, unsubstituted `${ACCOUNT_ID}`.

Note the returned `Arn`, e.g.:
`arn:aws:iam::$ACCOUNT_ID:policy/external-secrets-myapp-dev-policy`

If you re-run this later (e.g. after editing the policy), `create-policy` will fail with `EntityAlreadyExists` — use `aws iam create-policy-version --policy-arn <arn> --policy-document file://eso-secrets-policy.json --set-as-default` instead.

---

## Step 3 — Confirm the OIDC provider exists on your EKS cluster

IRSA (IAM Roles for Service Accounts) requires an OIDC identity provider associated with the cluster.

```bash
eksctl utils associate-iam-oidc-provider \
  --cluster $CLUSTER_NAME \
  --region ap-south-1 \
  --approve
```

This is idempotent — safe to run even if it already exists.

---

## Step 4 — Create the Kubernetes ServiceAccount + IAM Role (IRSA) for External Secrets Operator

Create the namespace first, then let `eksctl` handle IAM role creation, the trust policy, and policy attachment in one command:

```bash
kubectl create namespace external-secrets

eksctl create iamserviceaccount \
  --name external-secrets-sa \
  --namespace external-secrets \
  --cluster $CLUSTER_NAME \
  --region ap-south-1 \
  --attach-policy-arn arn:aws:iam::$ACCOUNT_ID:policy/external-secrets-myapp-dev-policy \
  --approve \
  --override-existing-serviceaccounts
```

This creates:
- A namespace-scoped ServiceAccount `external-secrets-sa` in namespace `external-secrets`
- An IAM role trusted only by that ServiceAccount (via OIDC federation) — the trust policy's `Condition` restricts the token subject to `system:serviceaccount:external-secrets:external-secrets-sa`, so no other ServiceAccount can assume it
- The policy attached to that role

Verify:

```bash
kubectl get sa external-secrets-sa -n external-secrets -o yaml
```

You should see an annotation like:

```yaml
eks.amazonaws.com/role-arn: arn:aws:iam::$ACCOUNT_ID:role/eksctl-...-external-secrets-sa
```

If the annotation is missing, the pods will fall back to the node's IAM role (or none) and every Secrets Manager call from ESO will fail with an access-denied error — re-run this step rather than patching the ServiceAccount by hand.

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

All three pods (`external-secrets`, `external-secrets-cert-controller`, `external-secrets-webhook`) should reach `Running`/`1/1`. If the webhook pod isn't ready, `ClusterSecretStore`/`ExternalSecret` creation in later steps will hang on admission webhook calls — wait for it before proceeding.

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

Check `status.conditions` shows `Ready: True`. If it errors, it's almost always one of:
- IAM trust policy / OIDC subject mismatch → re-run Step 4
- Region mismatch between `spec.provider.aws.region` and where the secret actually lives → re-check Step 1's `describe-secret` output
- The ESO webhook not yet ready → re-check Step 5

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
    repository: 237974319000.dkr.ecr.ap-south-1.amazonaws.com/hotelservice   # 237974319000 = $ACCOUNT_ID
    tag: v1
  secretName: hotelservice-secret   # just the name — content comes from ESO
```

(This is a static `values.yaml` file, not a shell command, so it can't reference `$ACCOUNT_ID` directly — swap in your account's numeric ID here, the same one you exported in Step 0.)

Commit this to the Git repo your ArgoCD `Application` will track.

---

## Step 9 — Install the AWS Load Balancer Controller (ALB)

Before exposing anything (ArgoCD's UI, or app ingresses like `frontend-ingress` / `java-ingress`) with an ALB, install the **AWS Load Balancer Controller**. It watches `Ingress` (and `Service` of type `LoadBalancer`) objects in the cluster and provisions/configures real Application Load Balancers for them. This is IRSA-based, same pattern as ESO in Steps 3–4.

### 9.1 Tag the VPC subnets

The controller auto-discovers subnets by tag. Public subnets (for internet-facing ALBs) need:

```
kubernetes.io/role/elb = 1
```

Private subnets (for internal ALBs, if used) need:

```
kubernetes.io/role/internal-elb = 1
```

If the cluster was created with `eksctl` using its default VPC/subnet setup, these tags are often already present — check before assuming you need to add them:

```bash
aws ec2 describe-subnets \
  --region ap-south-1 \
  --filters "Name=tag:kubernetes.io/cluster/$CLUSTER_NAME,Values=owned,shared" \
  --query 'Subnets[].{ID:SubnetId,AZ:AvailabilityZone,Public:MapPublicIpOnLaunch,Tags:Tags}'
```

Only tag the ones that are missing the appropriate role tag:

```bash
aws ec2 create-tags \
  --region ap-south-1 \
  --resources <public-subnet-id-1> <public-subnet-id-2> \
  --tags Key=kubernetes.io/role/elb,Value=1

aws ec2 create-tags \
  --region ap-south-1 \
  --resources <private-subnet-id-1> <private-subnet-id-2> \
  --tags Key=kubernetes.io/role/internal-elb,Value=1
```

### 9.2 Create the IAM policy

Use AWS's official policy document for the controller:

```bash
curl -o alb-iam-policy.json \
  https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json

aws iam create-policy \
  --policy-name AWSLoadBalancerControllerIAMPolicy \
  --policy-document file://alb-iam-policy.json
```

Note the returned `Arn`, e.g.:
`arn:aws:iam::$ACCOUNT_ID:policy/AWSLoadBalancerControllerIAMPolicy`

> Tip: pin to a specific tag (e.g. `.../v2.x.x/docs/install/iam_policy.json`) instead of `main` in production, so the policy doesn't silently change under you between runs.

### 9.3 Create the ServiceAccount + IAM Role (IRSA)

```bash
eksctl create iamserviceaccount \
  --cluster $CLUSTER_NAME \
  --region ap-south-1 \
  --namespace kube-system \
  --name aws-load-balancer-controller \
  --attach-policy-arn arn:aws:iam::$ACCOUNT_ID:policy/AWSLoadBalancerControllerIAMPolicy \
  --approve \
  --override-existing-serviceaccounts
```

Verify the annotation, same check as Step 4:

```bash
kubectl get sa aws-load-balancer-controller -n kube-system -o yaml
```

### 9.4 Install the controller via Helm

The chart also needs the cluster's VPC ID on some EKS/VPC-CNI combinations; pass it explicitly if the controller logs show it failing to auto-detect the VPC:

```bash
helm repo add eks https://aws.github.io/eks-charts
helm repo update

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=$CLUSTER_NAME \
  --set region=ap-south-1 \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller
  # --set vpcId=<vpc-id>   # uncomment if controller logs show VPC auto-detection failing
```

`serviceAccount.create=false` + `serviceAccount.name` — same pattern as Step 5 — points the controller's pods at the IRSA-annotated ServiceAccount from 9.3 instead of a fresh, unprivileged one.

Verify pods are running:

```bash
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
kubectl logs -n kube-system deploy/aws-load-balancer-controller
```

### 9.5 Expose a service with an `Ingress`

Once the controller is running, any `Ingress` with the `alb` class gets an ALB provisioned automatically — this is the pattern already used for `frontend-ingress` / `java-ingress`:

```yaml
# ingress.yaml (example)
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: hotelservice-ingress
  namespace: dev
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
spec:
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: hotelservice
                port:
                  number: 8082
```

```bash
kubectl apply -f ingress.yaml
kubectl get ingress hotelservice-ingress -n dev -w
```

Watch the `ADDRESS` column populate with the ALB's DNS name — that's your externally reachable endpoint. If it stays empty, check `kubectl describe ingress hotelservice-ingress -n dev` and the controller logs from 9.4 for subnet-discovery or IAM errors.

---

## Step 10 — Install ArgoCD

```bash
kubectl create namespace argocd

kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

kubectl get pods -n argocd -w
```

> `stable` always points at the latest stable release, which means re-running this later can pull in a newer ArgoCD version than the one you tested against. For reproducible installs, pin a tag instead, e.g. `.../argo-cd/v2.13.2/manifests/install.yaml`.

Get the initial admin password:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
```

Access the UI (quick way, port-forward):

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Then browse to `https://localhost:8080` and log in as `admin` with the password above. Rotate this password (or switch to SSO) once you've confirmed access — the initial secret is meant to be temporary:

```bash
argocd account update-password
```

For production, expose the ArgoCD UI via an `Ingress` instead of port-forward, using the ALB Controller installed in Step 9 — the same ALB ingress pattern you're already using for `frontend-ingress`/`java-ingress`:

```yaml
# argocd-server-ingress.yaml (example)
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-server-ingress
  namespace: argocd
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/backend-protocol: HTTPS   # argocd-server serves TLS by default
spec:
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: argocd-server
                port:
                  number: 443
```

Log in via CLI as well (useful for scripting):

```bash
argocd login localhost:8080 --username admin --password <password> --insecure
```

---

## Step 11 — Create the ArgoCD `Application` for your Helm chart

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
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
```

`selfHeal: true` means ArgoCD will keep reconciling drift automatically. This is safe here because the `Secret` objects in this namespace are the ones ESO manages (`creationPolicy: Owner`), and per Step 8 your Helm chart no longer templates `kind: Secret` at all — so there's no ownership conflict between ArgoCD and ESO. The `retry` block above gives transient sync failures (e.g. a brief API server hiccup) a few automatic retries with backoff instead of surfacing immediately as `Degraded`.

```bash
kubectl apply -f argocd-application.yaml
```

Check sync status:

```bash
argocd app get myapp-dev
argocd app sync myapp-dev
```

---

## Step 12 — Verify end to end

```bash
kubectl get pods -n dev
kubectl get externalsecret -n dev
kubectl get ingress -n dev
kubectl describe pod <hotelservice-pod> -n dev   # check env vars are populated
```

If a pod's env var is missing or empty, check in this order:

1. `kubectl get externalsecret <name> -n dev -o yaml` → status conditions
2. `kubectl logs -n external-secrets deploy/external-secrets` → IAM/auth errors
3. `kubectl get secret <name> -n dev -o yaml` → confirm keys exist
4. Helm template `envFrom.secretRef.name` matches `target.name` in the `ExternalSecret`

If an `Ingress` isn't getting an ALB address, check in this order:

1. `kubectl describe ingress <name> -n <namespace>` → events for the actual error
2. `kubectl logs -n kube-system deploy/aws-load-balancer-controller` → subnet-tagging / IAM errors
3. `aws ec2 describe-subnets --region ap-south-1` → confirm `kubernetes.io/role/elb` (or `internal-elb`) tags from Step 9.1
4. `kubectl get sa aws-load-balancer-controller -n kube-system -o yaml` → confirm the IRSA role-arn annotation from Step 9.3

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

Delete `all-secrets.json` (or make sure it's gitignored) once the rotation is applied, so the plaintext values don't linger on disk longer than necessary.

---

## Appendix — Handy commands

```bash
# Log in to ArgoCD via its externally exposed address instead of port-forward
# (replace with your ArgoCD server's actual external IP:port — the value below is a placeholder)
argocd login <argocd-external-ip>:<port> --username admin

# List available kubeconfig contexts
kubectl config get-contexts

# Register an additional EKS cluster with this ArgoCD instance
argocd cluster add arn:aws:eks:ap-south-1:$ACCOUNT_ID:cluster/my-eks-cluster --name java-app
```