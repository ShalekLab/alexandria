Install Single Cell Portal convenience scripts:

```
git clone https://github.com/broadinstitute/single_cell_portal.git
cd single_cell_portal
python3 -m venv env --copies
source env/bin/activate
pip install -r requirements.txt
```

Then [install and initialize Google Cloud SDK](https://cloud.google.com/sdk/docs/quickstarts) on your machine.

Testing manage_study.py
```
cd scripts
ACCESS_TOKEN=`gcloud auth print-access-token`
python manage_study.py --token=$ACCESS_TOKEN list-studies --summary
```