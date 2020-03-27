FROM continuumio/miniconda3:4.7.10

RUN apt-get update && \
apt-get install --no-install-recommends -y curl dpkg-dev gnupg lsb-release procps && \
export CLOUD_SDK_REPO="cloud-sdk-$(lsb_release -c -s)" && \
echo "deb http://packages.cloud.google.com/apt $CLOUD_SDK_REPO main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list && \
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - && \
apt-get update && apt-get install -y google-cloud-sdk

RUN conda install -y numpy=1.17.2 pandas=0.25.1

ADD scripts/ /alexandria/scripts/