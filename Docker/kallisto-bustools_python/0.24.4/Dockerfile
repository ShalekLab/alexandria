FROM python:3.7.5-slim

ARG KB_VERSION=0.24.4

RUN apt-get update && \
	apt-get install --no-install-recommends -y curl dpkg-dev gnupg lsb-release procps && \
	export CLOUD_SDK_REPO="cloud-sdk-$(lsb_release -c -s)" && \
	echo "deb http://packages.cloud.google.com/apt $CLOUD_SDK_REPO main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list && \
	curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - && \
	apt-get update && apt-get install -y google-cloud-sdk

RUN pip install --upgrade pip && pip install kb-python==${KB_VERSION}