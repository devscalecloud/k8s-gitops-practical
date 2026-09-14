# Scenario 02: Kubernetes GitOps Practical

Practice environment for the *second* interview stage described in the
Greenhouse invite: a 1-hour, live, collaborative Kubernetes troubleshooting
exercise. Its stated scope is Kubernetes, GitOps/continuous delivery,
networking, Helm and application configuration, and troubleshooting/
collaboration -- notably **not** the AWS IAM/IRSA-heavy focus of scenario 01.

## How this differs from scenario 01 (movie-recommend-app)

Scenario 01 exists to drill AWS-specific failure modes: IRSA trust policies,
security groups gating AWS API paths, VPC endpoints, etc. -- because the app
itself talks to S3/DynamoDB.

This scenario deliberately strips all of that out. The Terraform here stands
up **only** a VPC + EKS cluster + managed node group -- no IRSA roles for an
application, no S3, no DynamoDB, no VPC endpoints for AWS services. The
application that runs inside the cluster is a small stateless demo app with
no AWS dependency at all, so every fault you can construct against it lives
entirely inside Kubernetes: pod/Deployment/Service misconfiguration, Ingress/
networking, and -- once layered on top -- Helm chart values and ArgoCD
sync/drift issues.

The cluster still registers an OIDC provider (see `terraform/eks.tf`) because
cluster *add-ons* you'll install on top (the AWS Load Balancer Controller for
Ingress, in particular) still need IRSA for themselves, even though the
demo app doesn't.

## Apply

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars   # edit if you want non-default values
terraform init
terraform plan
terraform apply
```

Same shape as scenario 01: EKS control plane + node group takes roughly
10-15 minutes.

## After apply

```bash
aws eks update-kubeconfig --name $(terraform output -raw cluster_name) --region $(terraform output -raw region)
kubectl get nodes
```

## Installing the AWS Load Balancer Controller

Same process as scenario 01 -- its own hand-rolled IRSA role (not part of
this Terraform, on purpose, to keep infra/app-add-on scope separate):

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION=$(terraform -chdir=terraform output -raw region)
OIDC_ARN=$(terraform -chdir=terraform output -raw oidc_provider_arn)
OIDC_URL=$(echo "$OIDC_ARN" | sed 's|.*oidc-provider/||')
CLUSTER_NAME=$(terraform -chdir=terraform output -raw cluster_name)
VPC_ID=$(terraform -chdir=terraform output -raw vpc_id)

cat > alb-trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {"Federated": "arn:aws:iam::${ACCOUNT_ID}:oidc-provider/${OIDC_URL}"},
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": {
        "${OIDC_URL}:aud": "sts.amazonaws.com",
        "${OIDC_URL}:sub": "system:serviceaccount:kube-system:aws-load-balancer-controller"
      }
    }
  }]
}
EOF

aws iam create-role --role-name K8sGitopsLoadBalancerControllerRole \
  --assume-role-policy-document file://alb-trust-policy.json

curl -o iam-policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.9.0/docs/install/iam_policy.json
aws iam create-policy --policy-name K8sGitopsLoadBalancerControllerPolicy \
  --policy-document file://iam-policy.json
aws iam attach-role-policy --role-name K8sGitopsLoadBalancerControllerRole \
  --policy-arn "arn:aws:iam::${ACCOUNT_ID}:policy/K8sGitopsLoadBalancerControllerPolicy"

cat > alb-sa.yaml <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: aws-load-balancer-controller
  namespace: kube-system
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::${ACCOUNT_ID}:role/K8sGitopsLoadBalancerControllerRole
EOF
kubectl apply -f alb-sa.yaml

helm repo add eks https://aws.github.io/eks-charts
helm repo update
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName="$CLUSTER_NAME" \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region="$REGION" \
  --set vpcId="$VPC_ID"
```

## Apply the demo app

```bash
cd ../k8s
kubectl apply -f namespace.yaml
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl apply -f ingress.yaml
kubectl -n demo-app get pods,svc,ingress
```

## What's next (not built yet)

- ArgoCD install + an Application pointed at this repo's `k8s/` manifests
  (or a Helm chart wrapping them), to practice GitOps sync/drift
  troubleshooting.
- Converting `k8s/` into a proper Helm chart so "Helm and application
  configuration" faults (bad values, template errors, wrong release
  namespace) have something real to break.

## Teardown

```bash
kubectl delete namespace demo-app
helm uninstall aws-load-balancer-controller -n kube-system   # if installed
cd terraform
terraform destroy
```

Same caution as scenario 01: delete the namespace (and give the ALB
Controller time to deprovision the ALB) *before* `terraform destroy`, or
destroy can hang on a subnet still in use by a leftover ALB ENI. Also clean
up the hand-rolled `K8sGitopsLoadBalancerControllerRole`/policy -- Terraform
doesn't know about them.
