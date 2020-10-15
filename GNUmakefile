default: build

SHELL=/bin/bash
.ONESHELL:

NEW_VERSION_LABEL := 0.01

build:
	$(eval BUILD_CONTEXT := $(shell mktemp -d))
	echo Build context is ${BUILD_CONTEXT}
	cp -r Dockerfile infracontainer-entrypoint.sh ${BUILD_CONTEXT}
	cp -r modules/$(MODULE) ${BUILD_CONTEXT}/module
	docker build "${BUILD_CONTEXT}" -f Dockerfile -t az_$(MODULE):$(NEW_VERSION_LABEL)
	rm -rf "${BUILD_CONTEXT}"
