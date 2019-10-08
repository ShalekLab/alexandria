# The Alexandria Metadata Convention
  
In order to upload data with metadata to Alexandria you must include metadata within your [input_csv_file](/dropseq_scCloud/#formatting-your-input_csv_file). This data must adhere to the [Alexandria Metadata Convention](https://docs.google.com/spreadsheets/d/1r2r4XM7trosTQQFDjz4UcnLLXKZAoC9X80V5yTquFck/edit?usp=sharing).
  
The [Alexandria Metadata Convention](https://docs.google.com/spreadsheets/d/1r2r4XM7trosTQQFDjz4UcnLLXKZAoC9X80V5yTquFck/edit?usp=sharing) is accessible here as a Google Spreadsheet to those with a Broad Institute email address (@broadinstitute.org). To those without a Broad email account, we will grant access to outsiders eventually but for now you can view a [semi-complete version on our Github](https://github.com/ShalekLab/alexandria/blob/master/Docker/metadata_type_map.tsv).
  
The [Alexandria Metadata Convention](https://docs.google.com/spreadsheets/d/1r2r4XM7trosTQQFDjz4UcnLLXKZAoC9X80V5yTquFck/edit?usp=sharing) when first opened appears as such: ![](/imgs/metadata/amc.png) 
  
See the below table for descriptions of columns in this spreadsheet.

**Column**|**Description**
:---------|:--------------
attribute | Metadata attributes that describes all cells in your sample. Serve as valid metadata column headers in the [input_csv_file](/dropseq_scCloud/#formatting-your-input_csv_file) for dropseq_scCloud tool. Spaces between words are denoted by a single '\_' while subattributes are denoted with a double '\_' between the attribute parent and the attribute child.
required | Whether the attribute **MUST** be included as a column in the [input_csv_file](/dropseq_scCloud/#formatting-your-input_csv_file) of the data you are uploading to Alexandria.
default | The default value that will be assumed by the metadata validation script if the column is not included or the spreadsheet cells are left blank.
type | The datatype of the attribute that Alexandria expects. `strings` can be text without quotation marks  `booleans` can be either `True` or `False`. `numbers` are any numeric character, e.g. 0, 1, 2, ...
array | Specifies whether or not the attribute value is expected as an array of the aforementioned type.
class | The class of the attribute. [blank]: ontology: a biological ontology for its parent ontology. ontology_label: A label that describes its parent ontology. enum: . unit_label:
ontology | A URL to the ontology entry on the European Bioinformatics Insitute domain.
ontology_root | Ontology prefix???
controlled_list_entries | For attributes of class enum, the value is expected to be one value from the list of entries displayed here.
dependency | The parent ontology that the attribute is dependent upon.
dependency_condition | ???
dependent | The child ontology that is dependent upon this attribute.
attribute_description | A description of what the attribute is.