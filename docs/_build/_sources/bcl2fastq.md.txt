# Bcl2Fastq Dockerfile

This guide is an extension of the [Cumulus Team's guide](https://cumulus-doc.readthedocs.io/en/latest/bcl2fastq.html#docker) on creating and referencing your own Dockerfile to run bcl2fastq on Alexandria/Terra.

```eval_rst
.. warning:: Until cumulus/dropseq_workflow snapshot 6 is released, only launch bcl2fastq from the latest version of cumulus/bcl2fastq.
```

1. Register an account on [Illumina](https://support.illumina.com/sequencing/sequencing_software/bcl2fastq-conversion-software/downloads.html) and download the Linux rpm of Bcl2Fastq.
2. Install [Docker Desktop](https://www.docker.com/products/docker-desktop), register a Docker account, and `docker login` in your terminal.
3. Open up any text editor and save your file called Dockerfile. Place `bcl2fastq2-v2.20.0.422-Linux-x86_64.rpm` in the same directory as Dockerfile.
4. The Dockerfile should contain the following chunks:
```Docker
FROM continuumio/miniconda3:4.7.12
```
```Docker
# Install Google Cloud SDK
RUN apt-get update \
    && apt-get install --no-install-recommends -y build-essential dpkg-dev gnupg lsb-release procps curl \
    && export CLOUD_SDK_REPO="cloud-sdk-$(lsb_release -c -s)" \
    && echo "deb http://packages.cloud.google.com/apt $CLOUD_SDK_REPO main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list \
    && curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - \
    && apt-get update && apt-get install -y google-cloud-sdk
```
```Docker
# Bcl2Fastq: Make sure the downloaded Bcl2Fastq RPM file is in the same directory as your Dockerfile 
ADD bcl2fastq2-v2.20.0.422-Linux-x86_64.rpm /software/
RUN apt-get update && apt-get install --no-install-recommends -y alien \
    && alien -i /software/bcl2fastq2-v2.20.0.422-Linux-x86_64.rpm
```
5. In terminal, change directory to the folder containing the Dockerfile and enter `docker build -t <yourusername>/bcl2fastq:2.20.0.422 .` with your Docker username inserted.
6. If the build does not succeed, contact jgatter@mit.edu with the Dockerfile attached. Otherwise enter `docker push <yourusername>/bcl2fastq:2.20.0.422` in your terminal. _Make sure to make the docker image publicly accessible!_
7. Export the most recent cumulus/bcl2fastq workflow to your Terra workspace.
8. Edit the `docker_registry` variable to contain your Docker username, configure other inputs, and launch the analysis!


