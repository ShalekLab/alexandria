FROM us.gcr.io/broad-dsp-gcr-public/terra-jupyter-bioconductor:0.0.10

USER $USER
#RUN mkdir -p ~/notebooks/scripts
ADD https://raw.githubusercontent.com/ShalekLab/alexandria/master/notebooks/Metadata_Annotation/convert_adata_to_scp.py /home/jupyter-user/notebooks/scripts/
ADD https://raw.githubusercontent.com/ShalekLab/alexandria/master/notebooks/Metadata_Annotation/MetadataAdder.py /home/jupyter-user/notebooks/scripts/
ADD https://raw.githubusercontent.com/ShalekLab/alexandria/master/notebooks/Metadata_Annotation/metadata_name_type_info.tsv /home/jupyter-user/notebooks/scripts/
ADD https://raw.githubusercontent.com/ShalekLab/alexandria/master/notebooks/scp_save_seurat.R /home/jupyter-user/notebooks/scripts/
ADD https://raw.githubusercontent.com/ShalekLab/alexandria/master/notebooks/Metadata_Annotation/widget_helpers.py /home/jupyter-user/notebooks/scripts/

#ADD --chown=jupyter-user:users https://raw.githubusercontent.com/ShalekLab/alexandria/master/notebooks/Metadata_Annotation/convert_adata_to_scp.py /home/jupyter-user/notebooks/scripts/
#ADD --chown=jupyter-user:users https://raw.githubusercontent.com/ShalekLab/alexandria/master/notebooks/Metadata_Annotation/MetadataAdder.py /home/jupyter-user/notebooks/scripts/
#ADD --chown=jupyter-user:users https://raw.githubusercontent.com/ShalekLab/alexandria/master/notebooks/Metadata_Annotation/metadata_name_type_info.tsv /home/jupyter-user/notebooks/scripts/
#ADD --chown=jupyter-user:users https://raw.githubusercontent.com/ShalekLab/alexandria/master/notebooks/scp_save_seurat.R /home/jupyter-user/notebooks/scripts/
#ADD --chown=jupyter-user:users https://raw.githubusercontent.com/ShalekLab/alexandria/master/notebooks/Metadata_Annotation/widget_helpers.py /home/jupyter-user/notebooks/scripts/

# 'Rccp', 'RccpEigen'
RUN R -e "install.packages( c( \ 
            'data.table', \
            'R.utils', \
            'crunch'))" \
    && R -e "devtools::install_version(package = 'Seurat', version = package_version('3.1.2'))"
#'Seurat', \
USER root
ENV PIP_USER=false

#RUN pip install --upgrade pip && pip install \
#        matplotlib==3.0.3 \
#        scanpy==1.4.4 \
#        anndata==0.6.22 \
#        tzlocal==2.0.0 \
#        rpy2==2.9.4 
#        #\ipywidgets==7.5.1

RUN pip3 install --upgrade pip && pip3 install \
        matplotlib==3.0.3 \
        scanpy==1.4.4 \
        anndata==0.6.22 \
        tzlocal==2.0.0 \
        rpy2==2.9.4 
        #\ipywidgets==7.5.1

ENV PIP_USER=true
USER $USER