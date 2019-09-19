import ipywidgets as widgets
import requests

#button_layout = widgets.Layout(
def choose_metadata_name_dropdown(options, description):
    '''
    shows a dropdown of options of metadata, options should be a list of tuples of the form (display name, value)
    Parameters:
    options (list of tuples): list of tuples of options where the tuples are of the form (<display name>, <return value>)
    description (string):  the label that will be placed to the left of the drop down menu
    Returns:
    dropdown widget : A dropdown menu from the ipywidgets library. Access the value of this widget with <widget_variable_name>.value and display this widget with display(<widget_variable_name>). The ipywidgets library must be inported to access this second function.
    
    '''
    return widgets.Dropdown(
        options=options,
        value=options[0][1],
        description=description)


def query_all_values_under_root(ontology_name, root_ID):
    '''
    Queries the EBI ontology API for all of the children under a root in an ontology

    Parameters:
    ontology_name (string): an ontology in the EBI ontology database that will be queried
    root_ID (string): a node in ontology_name of the form ONTOLOGY_IDNUMBER

    Returns:
    list_for_dropdown (list) : a list of tuples of the form (<human readable label>: <description>, <ontology ID label>) for each child of the root in that ontology. This is a good input to a dropdown menu for selecting an ontology value
    name_id_dict (dict): a dictionary mapping the ontology ID to the human-readable name, for use in saving the correct values to the output metadata files
    '''
    ret = requests.get('http://www.ebi.ac.uk/ols/api/ontologies/'+ontology_name+'/hierarchicalChildren?id='+root_ID)
    total_pages = ret.json()["page"]["totalPages"]
    print(total_pages)
    list_for_dropdown = []
    name_id_dict = {}
    
    for pg in range(1,total_pages+1):
        ret_vals = []
        for i in ret.json()['_embedded']['terms']:
            label = i['label']
            if 'description' in i:
                desc=i['description']
                if desc is None:
                    desc = [""]
            else:
                desc= [""]
            i_d=i['short_form'] 
            ret_vals += [(label,desc,i_d)]
        list_for_dropdown += [(l[0]+": "+l[1][0], l[2]) for l in ret_vals] # this makes the display value the name and the description, and it returns the ontology key for lookup in the following dictionary:
        name_id_dict.update({l[2]:l[0] for l in ret_vals})
        if pg < total_pages:
            ret = requests.get('http://www.ebi.ac.uk/ols/api/ontologies/'+ontology_name+'/hierarchicalChildren?id='+root_ID+"&page="+str(pg))
    
    return list_for_dropdown, name_id_dict



def query_search_term(ontology_name, search_term):
    """
    Queries an EBI ontology for a specific search term. This will search all fields - label, synonym, description, short_form, obo_id, annotations, logical_description, iri

    Parameters:
    ontology_name (string): the name of the ontology to query. multiple ontologies are allowed as a string with commas separating their names with no spaces. Ex. "obo,ncbitaxon"
    search_term (string): a string that should be searched in this ontology

    Returns:
    list_for_dropdown (list) : a list of tuples of the form (<human readable label>: <description>, <ontology ID label>) for each query result. This is a good input to a dropdown menu for selecting an ontology value
    name_id_dict (dict): a dictionary mapping the ontology ID to the human-readable name, for use in saving the correct values to the output metadata files
    
    """
    n_per_query = 100
    start_val=0
    ret = requests.get('http://www.ebi.ac.uk/ols/api/search?q='+search_term+'&ontology='+ontology_name+"&rows="+str(n_per_query)+"&start="+str(start_val))
    list_for_dropdown = []
    name_id_dict = {}
    
    while ret.json()['response']['numFound'] > start_val:
        ret_vals = []
        for i in ret.json()['response']['docs']:
            label = i['label']
            if 'description' in i:
                desc=i['description']
            else:
                desc= [""]
            i_d=i['short_form'] 
            ret_vals += [(label,desc,i_d)]
        list_for_dropdown += [(l[0]+": "+l[1][0], l[2]) for l in ret_vals] # this makes the display value the name and the description, and it returns the ontology key for lookup in the following dictionary:
        name_id_dict.update({l[2]:l[0] for l in ret_vals})
        start_val += n_per_query
        ret = requests.get('http://www.ebi.ac.uk/ols/api/search?q='+search_term+'&ontology='+ontology_name+"&rows="+str(n_per_query)+"&start="+str(start_val))
    return list_for_dropdown, name_id_dict
    
