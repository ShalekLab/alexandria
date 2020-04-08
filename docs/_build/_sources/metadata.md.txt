# The Alexandria Metadata Convention
  
In order to upload data with metadata to Alexandria, your metadata must conform to the [Alexandria Metadata Convention](https://github.com/broadinstitute/scp-ingest-pipeline/blob/master/tests/data/AMC_v1.1.3.tsv). For upload through the alignment pipeline, this metadata should be included within your [input CSV file](dropseq_cumulus.html#the-alexandria-sheet) which should include any metadata that can be applied to all cells in a single sample. 

For direct upload from Single Cell Portal formatted file types, these metadata should be included in the metadata file, referred to in this description as the 'cell-level metadata file'. In your cell-level metadata file, each attribute name in the metadata can be a column name. To enforce some structure to the database, several fields are required and others require specific formatting guidelines. Users are encouraged to include as much metadata as possible, including metadata attributes which are the same for all samples in the study (ex. sequencing technology) as they will be important to users comparing data between studies.  
  
## Metadata categories

The Alexandria Metadata Convention contains 4 categories of structured metadata as follows:

### Ontology-valued metadata

Examples: disease, species, organ

To allow query at varying levels of specificities, the Alexandria Metadata Convention uses ontology-valued metadata whenever possible. These ontologies are tree-structured heirarchies curated by experts and maintained by EBI. For the purposes of the Alexandria Metadata Convention, please select the most specific value in the heirarchy as possible. For use of this metadata during query of the Alexandria database, a query result will include all child values of the query term. Single Cell Portal treats these values as group, or categorical variables. 

**Navigating ontologies to manually annotate your metadata:** The EBI OLS (ontology lookup service) provides an interface as well as an API to explore these ontologies which may be useful in preparing your metadata. The API is documented [here](https://www.ebi.ac.uk/ols/docs/developer), and the API endpoints for a given ontology are found in the `ontology` column in the AMC spreadsheet. The graphical interface can be accessed through the same URL with `api` substituted with `ols` (ex. `https://www.ebi.ac.uk/ols/ontologies/UBERON`). Because some ontologies include more areas than are covered by Alexandria, we have specified a _root_ for some ontologies, specified in the `ontology_root` column of the AMC spreadsheet. Entries in Alexandria metadata should come from below that root in the ontology tree.  To visit the page described by the root use the URL: `https://www.ebi.ac.uk/ols/ontologies/<ontology name>/terms?iri=http%3A%2F%2Fpurl.obolibrary.org%2Fobo%2F<alexandria ontology root>`. For example, for the species attribute, from the `NCBITaxon` ontology with root `NCBITaxon_2759` can be accessed using the URL `https://www.ebi.ac.uk/ols/ontologies/ncbitaxon/terms?iri=http%3A%2F%2Fpurl.obolibrary.org%2Fobo%2FNCBITaxon_2759`.


**Formatting ontology-valued metadata in the metadata file:** In the Alexandria Metadata Convention, two columns should be included for each ontology-valued metadata entry. The first, named `<metadata attribute>` contains the ontology ID in the structure `<ontology name>_<numeric ID>` or `<ontology name>:<numeric ID>`. The second column, `<metadata attribute>__ontology_label`, should contain the human-readable label for the ontology ID and should exactly match the name in the EBI database. This name is the title of the page on OLS. Ex. for attribute `species`, value: `NCBITaxon_9606` and `species__ontology_label`, value: `homo sapiens`. The label attribute is required for required metadata but may be left blank for optional metadata. It is recommended that users fill in this value to allow for more through validation of metadata files.

### Numeric-valued metadata

Examples: organism_age, bmi

This metadata is read in by Single Cell Portal as numeric, so when it is visualized in a plot, it will be shown on a color scale instead of as a categorical variable. 

**Each numeric metadata value in the convention requires a corresponding unit attribute. Each study should use the same unit for all values of that attribute.**

These unit attributes are named `<metadata attribute>__unit` and most come from an _ontology_ whose contents can be found in the **ontology** column of the AMC spreadsheet. For units derived from an ontology, please include the corresponding `<metadata attribute>__unit_label` column in your metadata file as well. These columns contain the same information as the `<attribute>__ontology_label` columns (the human-readable metadata name which corresponds with the ontology ID). 

Some unit metadata are not ontologies because no ontology currently exists to describe these units. In these cases, please enter a clear description of the units (ex. mg/mL).

While all values of a given unit attribute must be the same in a single study, please include the unit attribute for all rows with a value for its corresponding numeric metadata.

### Boolean-valued metadata

ex. treated

Boolean valued metadata may take the values `True` or `False` and is read by Single Cell Portal as group (categorical) metadata.


### Controlled-list metadata

ex. sample_type

Some metadata attributes do not fit into existing ontologies but can be described using a limited set of categories. For this metadata, the Alexandria team has selected a controlled list of values. These metadata have type `enum` in the AMC spreadsheet and their possible values can be found in the `controlled_list_entries` column. 

### Free text-valued metadata

ex. vaccination__adjuvants

Some metadata attributes could not be described by existing ontologies. While Alexandria will not support direct cross-study query of this metadata, it will be useful for users to include metadata in these structured columns so these attributes can be easily compared in query results. 

## Metadata with complex dependencies

Some metadata concepts cannot be fully described as a single field. While Alexandria does not attempt to fully capture all relevant experimental details that one would expect to find in the methods section of a paper, some values are relevant enough for query and further analysis that they are included in this convention. 

### Dependent metadata

Metadata attributes that are only relevant under specific conditions which depend on other metadata values are also specified in this ontology. For example, the `vaccination__time_since` attribute is only relevant in the context of the `vaccination` attribute. The AMC spreadsheet describes these dependencies through the `dependency` column which includes the name of the attribute that a given row depends on, the `dependency_condition` column which describes, if applicable, the specific condition that must be met for the metadata attribute to be included, the `dependent` column which includes any attributes which directly depend on the attribute in that row, and the `dependency_type` column which deliminates if the dependant attribute is allowed if the dependency is included ("if") or if the dependant attribute is required if the dependency is included ("required_if"). 

The specifics of each dependency are described in the AMC spreadsheet under the `attribute_description` column. 

### Array valued metadata

ex. disease, vaccinations

For several attributes, it does not make semantic sense to only allow one value for each metadata row. While we expect that in most controlled studies, these values will contain a single entry, we chose to allow multiple values for studies investigating combinitorial effects. Even if one of the values is not of specific interest to the study, please include it if possible. Ex. a study about flu vaccines would include the flu vaccine as a value for the vaccination attribute, but if the clinical data about other vaccines is also available, these vaccinations should be included as well. 

**Syntax in metadata file:** Array-valued metadata should be formatted as follows: `["value1""value2""value3"]` or `"value1""value2""value3"`. If the array-valued metadata only contains a single value it should still follow the same format: ex `"value1"` or `["value1"]`.

If the array-valued metadata attribute is a dependant metadata attribute, the order in the array should correspond with the order of the array the attribute depends on. For example, the following metadata entries for `vaccination__ontology_label`: `"Influenza Virus Vaccine""BCG Vaccine"`, for `vaccination__time_since` : `"1","2"`, and for `vaccination__time_since__unit_label`: `"year","year"` would indicate that the Influenza vaccine was recieved 1 year ago and the BCG Vaccine was recieved 2 years ago.  If information is not available for one of the metadata entries in a dependant array, include an empty string(`""`) for that value.



The AMC spreadsheet can be used as a guide in writing an Alexandria metadata file but includes more information than is necessary for this process.

See the below table for descriptions of columns in this spreadsheet that are useful in building this file: w

```eval_rst
+-------------------------+--------------------------------------------------------------------------------------------------------------------------+
| **Column**              | **Description**                                                                                                          |
+=========================+==========================================================================================================================+
| attribute               | Serve as valid metadata column headers in the `Alexandria Sheet <dropseq_cumulus.html#the-alexandria-sheet>`_ for        |
|                         | dropseq_cumulus workflow or the cell-level metadata file. Spaces between words are denoted by a single '_' while         |
|                         | subattributes are denoted with a double '\_' between the attribute parent and the attribute child.                       |
+-------------------------+--------------------------------------------------------------------------------------------------------------------------+
| required                | Whether the attribute **MUST** be included as a column in the metadata file of the data you are uploading to Alexandria. |
+-------------------------+--------------------------------------------------------------------------------------------------------------------------+
| default                 | The default value which you should include in the metadata file for a required value if it does not apply to your data.  |
|                         | *There is currently no system to automatically fill this data.*                                                          |
+-------------------------+--------------------------------------------------------------------------------------------------------------------------+
| type                    | The datatype of the attribute that Alexandria expects. ``strings`` can be text without quotation marks  `booleans` can   |
|                         | be either ``True`` or ``False``. ``numbers`` are any numeric character, e.g. ``0``, ``1``, ``2``, ...                    |
+-------------------------+--------------------------------------------------------------------------------------------------------------------------+
| array                   | ``TRUE`` if the metadata is an array-valued metadata type.                                                               |
+-------------------------+--------------------------------------------------------------------------------------------------------------------------+
| class                   | The classes of a string-type metadata attribute:                                                                         |
|                         |                                                                                                                          |
|                         |  - **[blank]**: no class, ontology: this attribute should be an ontology ID.                                             |
|                         |  - **ontology_label**: This attribute should be the human-readable label corresponding to it's ontology ID.              |
|                         |  - **enum**: a value from a controlled list.                                                                             |
|                         |  - **unit_label**: the name of the unit, either a free-text string or the ontology label from the unit ontology          |
+-------------------------+--------------------------------------------------------------------------------------------------------------------------+
| ontology                | A URL to the ontology entry on the European Bioinformatics Insitute domain.                                              |
+-------------------------+--------------------------------------------------------------------------------------------------------------------------+
| ontology_root           | The highest value in the ontology tree applicable to this metadata attribute.                                            |
+-------------------------+--------------------------------------------------------------------------------------------------------------------------+
| controlled_list_entries | For attributes of class enum, the value is expected to be one value from the list of entries displayed here.             |
+-------------------------+--------------------------------------------------------------------------------------------------------------------------+
| dependency              | The parent ontology that the attribute is dependent upon.                                                                |
+-------------------------+--------------------------------------------------------------------------------------------------------------------------+
| dependency_condition    | The condition on the dependency under which the attribute is dependent.                                                  |
+-------------------------+--------------------------------------------------------------------------------------------------------------------------+
| dependent               | The attribute that is dependent upon this attribute.                                                                     |
+-------------------------+--------------------------------------------------------------------------------------------------------------------------+
| attribute_description   | A description of what the attribute is.                                                                                  |
+-------------------------+--------------------------------------------------------------------------------------------------------------------------+
```