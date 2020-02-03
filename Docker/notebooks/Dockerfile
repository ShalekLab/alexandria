FROM us.gcr.io/broad-dsp-gcr-public/terra-jupyter-bioconductor:0.0.7

#USER $USER

#RUN mkdir ~/notebooks/scripts \
#     && R -e "install.packages(c('data.table', \
#         'R.utils', \
#         'crunch'))" \
#     && R -e "devtools::install_version(package = 'Seurat', version = package_version('3.1.0'))"

USER root
# ENV PIP_USER=false

# RUN pip install --upgrade pip && pip install \
#         numpy==1.17.2 \
#         pandas==0.25.1 \
#         matplotlib==3.0.3 \
#         scanpy==1.4.4 \
#         anndata==0.6.22 \
# #       r-seurat==3.0.2 \
#         tzlocal==2.0.0 \
#         rpy2==2.9.4 \
#         ipywidgets==7.5.1
# ENV PIP_USER=true

RUN pwd && mkdir -p ~/notebooks/scripts
ADD --chown=jupyter-user:users https://raw.githubusercontent.com/ShalekLab/alexandria/master/uploadHelpers/convert_adata_to_scp.py ~/notebooks/scripts/
ADD --chown=jupyter-user:users https://raw.githubusercontent.com/ShalekLab/alexandria/master/uploadHelpers/MetadataAdder.py ~/notebooks/scripts/
ADD --chown=jupyter-user:users https://raw.githubusercontent.com/ShalekLab/alexandria/master/uploadHelpers/metadata_name_type_info.tsv ~/notebooks/scripts/
ADD --chown=jupyter-user:users https://raw.githubusercontent.com/ShalekLab/alexandria/master/uploadHelpers/scp_save_seurat.R ~/notebooks/scripts/
ADD --chown=jupyter-user:users https://raw.githubusercontent.com/ShalekLab/alexandria/master/uploadHelpers/widget_helpers.py ~/notebooks/scripts/
RUN ls ~/notebooks/scripts

USER $USER