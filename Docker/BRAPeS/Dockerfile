FROM continuumio/miniconda3:4.8.2

RUN apt-get update \
	&& apt-get install --no-install-recommends -y curl dpkg-dev gnupg lsb-release procps \
	&& export CLOUD_SDK_REPO="cloud-sdk-$(lsb_release -c -s)" \
	&& echo "deb http://packages.cloud.google.com/apt $CLOUD_SDK_REPO main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list \
	&& curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - \
	&& apt-get update && apt-get install -y google-cloud-sdk 

RUN git clone https://github.com/YosefLab/BRAPeS.git /scBCR/BRAPeS \
	&& rm -r /scBCR/BRAPeS/Example \
	&& conda install -y -c bioconda \
		openssl=1.0 \
		samtools \
		biopython \
		pysam \
		hisat2 \
		bowtie2 \
		rsem
