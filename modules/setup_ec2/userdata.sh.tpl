#!/bin/bash
yum update -y
yum install -y git maven docker

systemctl start docker
systemctl enable docker

cd /root
git clone https://github.com/nikhilkothare2106/hotel-rating-microservice.git

aws ecr get-login-password --region ap-south-1 | docker login --username AWS --password-stdin $(echo ${ecr_repos["hotelservice"]} | cut -d'/' -f1)

cd /root/hotel-rating-microservice

docker build -t hotelservice:v1 ./HotelService
docker tag hotelservice:v1 ${ecr_repos["hotelservice"]}:v1
docker push ${ecr_repos["hotelservice"]}:v1

docker build -t userservice:v1 ./UserService
docker tag userservice:v1 ${ecr_repos["userservice"]}:v1
docker push ${ecr_repos["userservice"]}:v1

docker build -t ratingservice:v1 ./RatingService
docker tag ratingservice:v1 ${ecr_repos["ratingservice"]}:v1
docker push ${ecr_repos["ratingservice"]}:v1

docker build -t apigatewayservice:v1 ./ApiGateway
docker tag apigatewayservice:v1 ${ecr_repos["apigatewayservice"]}:v1
docker push ${ecr_repos["apigatewayservice"]}:v1

docker build -t serviceregistry:v1 ./ServiceRegistry
docker tag serviceregistry:v1 ${ecr_repos["serviceregistry"]}:v1
docker push ${ecr_repos["serviceregistry"]}:v1


