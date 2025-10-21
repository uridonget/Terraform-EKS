## 반드시 variables.tf 파일과 values.yaml 파일을 수정해서 배포하세요!

실행 순서

cd 01-cluster

terraform init
terraform apply

cd ..
cd 02-addons

terraform init
terraform plan

cd ..
cd 03-manifests

helm install tarot-jeong . -f secret-values.yaml --namespace tarot --create-namespace
