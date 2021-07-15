pwd = $(shell pwd)
gitlab_con=gitlab
sh_cmd=docker exec -ti $(gitlab_con)

gitlab-up:
	docker-compose up -d

gitlab-down:
	docker-compose down

shell:
	$(sh_cmd) bash

log:
	docker logs -f $(gitlab_con)

take-backup:
	$(sh_cmd) gitlab-backup create

clean-registry:
	$(sh_cmd) gitlab-ctl registry-garbage-collect -m

check-status:
	$(sh_cmd) gitlab-ctl status

check-system:
	$(sh_cmd) gitlab-rake gitlab:check SANITIZE=true

stop:
	$(sh_cmd) gitlab-ctl stop

start:
	$(sh_cmd) gitlab-ctl start

restart:
	$(sh_cmd) gitlab-ctl restart

before-backup:
	$(sh_cmd) gitlab-ctl stop unicorn
	$(sh_cmd) gitlab-ctl stop sidekiq

after-backup:
	$(sh_cmd) gitlab-ctl start unicorn
	$(sh_cmd) gitlab-ctl start sidekiq

get-root-pass:
	$(sh_cmd) cat /etc/gitlab/initial_root_password

set-root-pass:
	$(sh_cmd) gitlab-rake "gitlab:password:reset[root]"