주의! 이 테라폼은 Team Neves에 맞춰진 테라폼입니다.

특히! authenticate에서 특정 팀 사람들에게 권한을 부여하도록 설정되어있습니다.

그 부분 알아서 잘 수정해서 사용하세요! (아니면 스킵하고 콘솔에서 직접 추가해도 괜찮습니다~)

테라폼 실행 순서

cd cluster

terraform init

terraform plan

terraform apply

cd ../authenticate

terraform init

terraform plan

terraform apply

cd ../apps

terraform init

terraform plan

terraform apply

manifests 파일을 바꿔서 배포하고싶은 사람들은 반드시 apps/test-app.tf 파일도 수정하세요!