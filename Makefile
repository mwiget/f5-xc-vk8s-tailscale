# Copyright (c) 2021 Tailscale Inc & AUTHORS All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

ifndef IMAGE_TAG
  $(error "IMAGE_TAG is not set")
endif

ROUTES ?= ""
BLINDFOLD ?= ""
AUTH_KEY ?= ""

blindfold:
	# TODO needs adjustment!
	vesctl request secrets get-policy-document --namespace mw --name mw-dns2 > secret-policy
	vesctl request secrets encrypt --policy-document secret-policy --public-key playground-api-pubkey ~/.tailscale-authkey > authkey.enc

build:
	@docker build . -t $(IMAGE_TAG)

push: build
	@docker push $(IMAGE_TAG)

deploy: destroy
	@sed -e "s;{{AUTH_KEY}};$(AUTH_KEY);g" tailscale-deployment.yaml | sed -e "s;{{BLINDFOLD}};$(BLINDFOLD);g" | sed -e "s;{{IMAGE_TAG}};$(IMAGE_TAG);g" | sed -e "s;{{ROUTES}};$(ROUTES);g" | kubectl create -f-

destroy:
	@kubectl delete -f tailscale-deployment.yaml --ignore-not-found --grace-period=0

test:
	@sed -e "s;{{AUTH_KEY}};$(AUTH_KEY);g" tailscale-deployment.yaml | sed -e "s;{{BLINDFOLD}};$(BLINDFOLD);g" | sed -e "s;{{IMAGE_TAG}};$(IMAGE_TAG);g" | sed -e "s;{{ROUTES}};$(ROUTES);g" | cat
