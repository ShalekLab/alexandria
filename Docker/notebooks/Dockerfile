FROM us.gcr.io/broad-dsp-gcr-public/terra-jupyter-bioconductor:0.0.2

ADD https://raw.githubusercontent.com/ShalekLab/alexandria/master/uploadHelpers/convert_adata_to_scp.py /notebook/
ADD https://raw.githubusercontent.com/ShalekLab/alexandria/master/uploadHelpers/MetadataAdder.py /notebook/
ADD https://raw.githubusercontent.com/ShalekLab/alexandria/master/uploadHelpers/metadata_name_type_info.tsv /notebook/
ADD https://raw.githubusercontent.com/ShalekLab/alexandria/master/uploadHelpers/scp_save_seurat.R /notebook/
ADD https://raw.githubusercontent.com/ShalekLab/alexandria/master/uploadHelpers/widget_helpers.py /notebook/

RUN R -e "devtools::install_version(package = 'Seurat', version = package_version('3.1.0'))" \
    && R -e "install.package(data.table)" \
    && R -e "install.package(R.utils)" \
    && R -e "install.packages('crunch')"

RUN python3 -m pip install --upgrade pip \
    && python3 -m pip install \
    	numpy=1.17.2 \
		pandas=0.25.1 \
		matplotlib=3.1.1 \
		scanpy=1.4.4 \
		anndata=0.6.22 \
		r-seurat=3.0.2 \
		rpy2=2.9.4 \
#		tzlocal-2.0.0 \
		ipywidgets=7.5.1