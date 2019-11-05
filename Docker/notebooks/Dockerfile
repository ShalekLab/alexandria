FROM us.gcr.io/broad-dsp-gcr-public/terra-jupyter-bioconductor:0.0.2

RUN R -e "install.packages('data.table')" \
    && R -e "install.packages('R.utils')" \
    && R -e "install.packages('crunch')" \
    && R -e "devtools::install_version(package = 'Seurat', version = package_version('3.1.0'))"

ADD --chown=jupyter-user:users https://raw.githubusercontent.com/ShalekLab/alexandria/master/uploadHelpers/convert_adata_to_scp.py ~/notebooks/
ADD --chown=jupyter-user:users https://raw.githubusercontent.com/ShalekLab/alexandria/master/uploadHelpers/MetadataAdder.py ~/notebooks/
ADD --chown=jupyter-user:users https://raw.githubusercontent.com/ShalekLab/alexandria/master/uploadHelpers/metadata_name_type_info.tsv ~/notebooks/
ADD --chown=jupyter-user:users https://raw.githubusercontent.com/ShalekLab/alexandria/master/uploadHelpers/scp_save_seurat.R ~/notebooks/
ADD --chown=jupyter-user:users https://raw.githubusercontent.com/ShalekLab/alexandria/master/uploadHelpers/widget_helpers.py ~/notebooks/

ENV PIP_USER=false
USER root

RUN pip install --upgrade pip && pip install \
        numpy==1.17.2 \
        pandas==0.25.1 \
        matplotlib==3.0.3 \
        scanpy==1.4.4 \
        anndata==0.6.22 \
#       r-seurat==3.0.2 \
        tzlocal==2.0.0 \
        rpy2==2.9.4 \
        ipywidgets==7.5.1

USER jupyter-user
ENV PIP_USER=true
