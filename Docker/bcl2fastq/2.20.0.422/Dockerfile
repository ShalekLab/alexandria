FROM continuumio/miniconda3:4.7.12

# Google Cloud SDK
RUN apt-get update \
    && apt-get install --no-install-recommends -y build-essential dpkg-dev gnupg lsb-release procps curl \
    && export CLOUD_SDK_REPO="cloud-sdk-$(lsb_release -c -s)" \
    && echo "deb http://packages.cloud.google.com/apt $CLOUD_SDK_REPO main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list \
    && curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - \
    && apt-get update && apt-get install -y google-cloud-sdk

# Bcl2Fastq: Make sure the downloaded Bcl2Fastq RPM file is in the same directory as your Dockerfile 
ADD bcl2fastq2-v2.20.0.422-Linux-x86_64.rpm /software/
RUN apt-get update && apt-get install --no-install-recommends -y alien \
    && alien -i /software/bcl2fastq2-v2.20.0.422-Linux-x86_64.rpm