pwd = $(shell pwd)

harbor-cert:
	wget https://raw.githubusercontent.com/cormachogan/harbor-certs/main/gen-harbor-certs.sh
	chmod +x gen-harbor-certs.sh
	sudo ./gen-harbor-certs.sh
	mkdir certs
	sudo cp *.crt *.cert *.key certs
	sudo chown -R $(id -u):$(id -g) certs

harbor-download:
	wget https://github.com/goharbor/harbor/releases/download/v2.1.2/harbor-offline-installer-v2.1.2.tgz
	tar -zxvf harbor-offline-installer-v2.1.2.tgz
	mv harbor/* .
	cp harbor.yml.tmpl harbor.yml

harbor-yml:
	sed -i 's/hostname: reg.mydomain.com/hostname: harbor.localdomain.com/g' harbor.yml
	sed -i 's/certificate: \/your\/certificate\/path/certificate: $(subst /,\/,${pwd})\/harbor.localdomain.com.crt/g' harbor.yml
	sed -i 's/private_key: \/your\/private\/key\/path/private_key: $(subst /,\/,${pwd})\/harbor.localdomain.com.key/g' harbor.yml

harbor-prepare:
	sudo ./prepare

harbor-install:
	sudo ./install.sh

harbor-up:
	sudo docker-compose up -d

harbor-down:
	sudo docker-compose down