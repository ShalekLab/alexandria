# Bcl2Fastq Docker Image

## What is Docker?

[Docker](https://www.docker.com/resources/what-container) is a platform that enables the packaging of software in containers which can be run on a variety of computing environments. You can think of container images as portable virtual environments. We use Docker to package software tools and their dependencies so that users can run them in workflows and notebooks on Google Cloud.  
  
Normally we provide these public images in our workflows, but due to legal matters, you must push your own Bcl2Fastq Docker image to run it within our workflows. Docker can be a powerful tool in the sphere of bioinformatics, so hopefully the content taught in this guide can help you use Docker in your future research.
  
## Instructions
  
This guide is an extension of the [Cumulus Team's guide](https://cumulus-doc.readthedocs.io/en/latest/bcl2fastq.html#docker) on creating and referencing your own Dockerfile to run Bcl2Fastq on the Single Cell Portal/Terra.
  
1. Register an account on [Illumina](https://support.illumina.com/sequencing/sequencing_software/bcl2fastq-conversion-software/downloads.html) and download the Linux rpm of Bcl2Fastq.
2. Install [Docker Desktop](https://www.docker.com/products/docker-desktop), register a Docker account, and `docker login` in your computer's terminal.
3. Open up any text editor and save an empty file called Dockerfile. Place `bcl2fastq2-v2.20.0.422-Linux-x86_64.rpm` in the same directory as Dockerfile.
4. An example Dockerfile is viewable [here](https://github.com/ShalekLab/alexandria/blob/master/Docker/bcl2fastq/2.20.0.422/Dockerfile). The Dockerfile should contain the following chunks of code:  

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
6. If the build does not succeed, file a GitHub issue on our repository with the Dockerfile attached. Otherwise enter `docker push <yourusername>/bcl2fastq:2.20.0.422` in your terminal. 
7. Go to the repositories tab on [hub.docker.com](hub.docker.com) and visit your image repository. In the settings tab, make the image publicly accessible.
8. On the Single Cell Portal/Terra workflow configuration page, look for the bcl2fastq docker registry parameter. Edit this parameter to be your Docker username.
9. Configure other workflow inputs and launch the analysis!


