DB_HOST_FQDN      = localhost
INFLUXDB_USER     = telegraf
INFLUXDB_BUCKET   = synology-snmp
INFLUXDB_ORG      = NAS
NAS_FQDN          = home.ams
SYNOLOGY_MIBS_URL = https://global.download.synology.com/download/Document/Software/DeveloperGuide/Firmware/DSM/All/enu/Synology_MIB_File.zip

define INFLUXDB_ENV
DOCKER_INFLUXDB_INIT_BUCKET=$(INFLUXDB_BUCKET)
DOCKER_INFLUXDB_INIT_MODE=setup
DOCKER_INFLUXDB_INIT_ORG=$(INFLUXDB_ORG)
DOCKER_INFLUXDB_INIT_PASSWORD=telegraf
DOCKER_INFLUXDB_INIT_USERNAME=$(INFLUXDB_USER)
endef
export INFLUXDB_ENV

.PHONY: prepare-token run

volume/influxdb2.token:
	@echo -n "$(shell cat /proc/sys/kernel/random/uuid)" > "$@"

volume/influxdb2.env: | volume/influxdb2.token
	@echo "$$INFLUXDB_ENV" > "$@"
	@echo "DOCKER_INFLUXDB_INIT_ADMIN_TOKEN=$(shell cat volume/influxdb2.token)" >> "$@"

volume/influxdb/etc/influxdb2:
	@mkdir -p "$@"

volume/influxdb/var/lib/influxdb2:
	@mkdir -p "$@"

volume/grafana:
	@mkdir -p "$@"
	@chmod a+wX "$@"

volume/telegraf/etc/telegraf/telegraf.conf: template/telegraf.conf Makefile | volume/influxdb2.token
	@mkdir -p $(shell dirname $@)
	@sed 's|%INFLUXDB_TOKEN%|$(shell cat volume/influxdb2.token)|g' template/telegraf.conf > $@
	@sed -i 's|%DB_HOST_FQDN%|$(DB_HOST_FQDN)|g' $@
	@sed -i 's|%INFLUXDB_BUCKET%|$(INFLUXDB_BUCKET)|g' $@
	@sed -i 's|%INFLUXDB_ORG%|$(INFLUXDB_ORG)|g' $@
	@sed -i 's|%NAS_FQDN%|$(NAS_FQDN)|g' $@

volume/telegraf/synology/mibs:
	@mkdir -p "$(shell dirname $@)"
	@curl -Ls "$(SYNOLOGY_MIBS_URL)" | bsdtar -xf - -C "$(shell dirname $@)"
	@mv volume/telegraf/synology/Synology_MIB_File "$@"

run: volume/influxdb2.env volume/influxdb/etc/influxdb2 volume/influxdb/var/lib/influxdb2 volume/telegraf/etc/telegraf/telegraf.conf volume/telegraf/synology/mibs volume/grafana
	@podman-compose up --remove-orphans --build
