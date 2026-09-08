AWS_REGION = "ap-south-1"
CLUSTER_NAME = "nikhil-eks-cluster"

eksctl utils associate-iam-oidc-provider \
--region "$AWS_REGION" \
--cluster "$CLUSTER_NAME" \
--approve


eksctl create iamserviceaccount \
--cluster="$CLUSTER_NAME" \
--namespace=kube-system \
--name=aws-load-balancer-controller \
--role-name AmazonEKSLoadBalancerControllerRole \
--attach-policy-arn=arn:aws:iam::237974319000:policy/AWSLoadBalancerControllerIAMPolicy \
--approve \
--region "$AWS_REGION"

helm repo add eks https://aws.github.io/eks-charts
helm repo update

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
-n kube-system \
--set clusterName="$CLUSTER_NAME" \
--set serviceAccount.create=false \
--set serviceAccount.name=aws-load-balancer-controller
