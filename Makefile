PORT ?= 1313
THEME ?= purehugo

.PHONY: serve build publish

serve:
	hugo server -t purehugo -D -w -p $(PORT)

build:
	hugo -t $(THEME)

publish: build
	./scripts/publish.sh
