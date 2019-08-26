FROM continuumio/miniconda3:4.7.10

ADD https://raw.githubusercontent.com/ShalekLab/alexandria/master/miniconda3/metadata_type_map.tsv /tmp/metadata_type_map.tsv

RUN apt-get update && \
apt-get install --no-install-recommends -y curl dpkg-dev gnupg lsb-release procps && \
export CLOUD_SDK_REPO="cloud-sdk-$(lsb_release -c -s)" && \
echo "deb http://packages.cloud.google.com/apt $CLOUD_SDK_REPO main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list && \
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - && \
apt-get update && apt-get install -y google-cloud-sdk

RUN conda install -y numpy=1.16.4 pandas=0.24.2