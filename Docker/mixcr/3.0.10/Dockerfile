FROM openjdk:8-jre-alpine3.8

ENV MIXCR_VERSION="3.0.10"
ENV GCLOUD_VERSION="266.0.0"

ADD https://github.com/milaboratory/mixcr/releases/download/v${MIXCR_VERSION}/mixcr-${MIXCR_VERSION}.zip /tmp/mixcr-${MIXCR_VERSION}.zip 
ADD https://github.com/ShalekLab/mixcr_workflow/blob/master/imgt.201918-4.sv5.json.gz?raw=true /tmp/imgt.201918-4.sv5.json.gz

RUN apk --no-cache add openssl bash \
	&& mkdir /software \
	&& unzip /tmp/mixcr-${MIXCR_VERSION}.zip -d /software/ \
    	&& rm /tmp/mixcr-${MIXCR_VERSION}.zip \
	&& chmod +x /software/mixcr-${MIXCR_VERSION}/mixcr.jar \
	&& gunzip /tmp/imgt.201918-4.sv5.json.gz \
	&& mv /tmp/imgt.201918-4.sv5.json /software/mixcr-${MIXCR_VERSION}/libraries/

RUN apk add --update --no-cache \
    ca-certificates python wget \
    && wget "https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-${GCLOUD_VERSION}-linux-x86_64.tar.gz" \
    && tar -xzf "google-cloud-sdk-${GCLOUD_VERSION}-linux-x86_64.tar.gz" \
    && rm "google-cloud-sdk-${GCLOUD_VERSION}-linux-x86_64.tar.gz" \
    && google-cloud-sdk/install.sh --usage-reporting=true --path-update=true --bash-completion=true --rc-path=/.bashrc \
    && google-cloud-sdk/bin/gcloud config set --installation component_manager/disable_update_check true \
    && rm -rf google-cloud-sdk/.install/.backup \
    && rm -rf google-cloud-sdk/.install/.download

ENV PATH=/software/mixcr-${MIXCR_VERSION}/:/google-cloud-sdk/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

WORKDIR /software/mixcr-${MIXCR_VERSION}/