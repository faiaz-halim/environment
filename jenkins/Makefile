include ../.env

jenkins_con=jenkins
sh_cmd=docker exec -ti $(jenkins_con)

jenkins-up:
	docker-compose up -d

jenkins-down:
	docker-compose down

shell:
	$(sh_cmd) bash

log:
	docker logs -f $(jenkins_con)

get-token:
	$(sh_cmd) cat /var/jenkins_home/secrets/initialAdminPassword

build:
	docker build -t ${private_repo}/jenkins/jenkins:custom .
	docker push ${private_repo}/jenkins/jenkins:custom
