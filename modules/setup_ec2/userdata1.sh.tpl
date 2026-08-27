#!/bin/bash
yum update -y
yum install -y git maven docker

systemctl start docker
systemctl enable docker

cd /root
git clone https://github.com/nikhilkothare2106/hotel-rating-microservice.git

aws ecr get-login-password --region ap-south-1 | docker login --username AWS --password-stdin $(echo ${ecr_repos["frontendservice"]} | cut -d'/' -f1)

cd /root/hotel-rating-microservice


docker build \
  --build-arg VITE_API_BASE_URL=http://eks-alb-302654701.ap-south-1.elb.amazonaws.com \
  -t frontendservice:v1 ./hotel-rating-frontend

docker tag frontendservice:v1 ${ecr_repos["frontendservice"]}:v1
docker push ${ecr_repos["frontendservice"]}:v1