import widget_helpers as uh
import ipywidgets as widgets
import pandas as pd

label_style = {'description_width': 'initial', 'width':'initial'}
class MetadataAdder():


    def __init__(self, mapping_options, available_metadata, metadata_info,cell_level_metadata):
        """

        Parameters:
        mapping_options (list): a list of strings describing the possible sources of metadata tables ex: anndata object, sample level metadata file, etc
        available_metadata (list): a list of Alexandria metadata that has not yet been set
        metadata_info (dataframe): a Pandas dataframe containing info about the metadata
        """
        self.available_metadata = available_metadata
        self.mapping_options = mapping_options
        self.metadata_info = metadata_info
        self.cell_level_metadata = cell_level_metadata
        
        #First make a dropdown allowing the user to select the mapping option
        self.mapping_loc = widgets.Dropdown(
            options= list(mapping_options.keys()),
            value = list(mapping_options.keys())[0],
            description = "table with metadata to map",
            style=label_style
        )
        
        display(self.mapping_loc)
        self.output_box = widgets.Output()
        my_select_button = widgets.Button(description="select table",layout=widgets.Layout(width='auto', height='40px'))
        display(my_select_button)
        my_select_button.on_click(self.selected_data_input)
        display(self.output_box)
    
    def selected_data_input(self,select_button):
        # TODO: if this is sample-level or using an R object, this is not ideal
        if self.mapping_loc.value == "anndata":
            self.df = self.mapping_options["anndata"].obs
            self.cell_level = True
            self.mapping_options["cell level dataframe"] = self.mapping_options["anndata"].obs
            self.init_dataframe()
        elif self.mapping_loc.value == "cell level dataframe":
            self.df = self.mapping_options["cell level dataframe"]
            self.cell_level = True
            self.init_dataframe()
        else:
            self.cell_level = False
            self.df = pd.read_csv(self.mapping_loc.value)
            key_options = list(set(adata.obs.columns).intersection(set(df.columns)))
            self.map_key = widgets.Dropdown(
                options=key_options,
                value=key_options[0],
                description="key to map adata to file",
                style=label_style)
            select_map_key_button = widgets.Button(description="select map key",layout=widgets.Layout(width='auto', height='40px'))
            display(self.map_key) 
            display(select_map_key_button)
            select_map_key_button.on_click(self.init_dataframe)
    def init_dataframe(self, select_map_key_button=""):
        if select_map_key_button != "":
           self.mapping_col = self.map_key.value
           self.df.set_index(mapping_col, inplace=True)
    
        self.metadata_dataframe = pd.DataFrame(index=self.df.index)
        
        self.choose_next_column_mapping()

    def choose_next_column_mapping(self):
        """
        Displays dropdowns for choosing the local column and alexandria column to map to each other
        """
        self.m_key = widgets.Dropdown(
            options=self.df.columns,
            value=self.df.columns[0],
            description="my metadata column",
            style=label_style)
        self.al_key = widgets.Dropdown(
            options=self.available_metadata,
            value=self.available_metadata[0],
            description="Alexandria metadata column",
            style=label_style)
        
        map_button = widgets.Button(description="map ",layout=widgets.Layout(width='auto', height='40px'))
        display(self.m_key, self.al_key)
        display(map_button)
        # this is how we escape
        map_button.on_click(self.map_columns)
        done_button = widgets.Button(description="save my maps, I am done with this matrix", layout=widgets.Layout(width='auto', height='40px'))
        display(done_button)
        done_button.on_click(self.finish_mapping)
    def map_columns(self, button):
        """
        Once you've selected the columns you want to map, this function is called by pressing the 'map' button
        """
        # save the values in the drop downs in case someone changes them without pushing the map button
        self.alexandria_col = self.al_key.value
        self.local_col = self.m_key.value
        # figure out what the alexandria convention wants this file to be
        self.metadata_class = self.metadata_info.loc[self.alexandria_col,"class"] # class is ontology or enum etc
        self.metadata_type = self.metadata_info.loc[self.alexandria_col,"type"] # type is number or string

        if self.metadata_type == "number":
            self.map_numeric_data()
        elif self.metadata_class == "ontology":
            self.map_ontology_data()
        elif self.metadata_class == "enum":
            self.select_controlled_list()
        elif self.metadata_type == "string":
            self.select_string_data()
        # I don't think we ever actually get to this, right now everytime we select a new column the dropdown menus reappear
        button.close()
        self.al_key.close()
        self.m_key.close()
    def map_numeric_data(self):
        """
        If the metadata is of numeric type, I was really generous and decided to implement a way that helps you 
        correct it if you accidentally make it not numeric
        """
        self.output_box.clear_output()
        self.output_box.append_stdout("This metadata is numeric, if text boxes are output below, please map the left values to numbers")
        new_val_mapping = {}
        try: # try casting to float
            self.df[self.local_col].astype(float, inplace=True)
            self.metadata_dataframe[self.alexandria_col] = self.df[self.local_col]
            self.output_box.append_stdout("data was mapped!")
            self.continue_to_next_column()
        except ValueError:
            self.output_box.append_stdout("this metadata needs to be numeric!")
        
            for k in self.df[self.local_col].unique():
                # figure out which ones won't map
                try:
                    new_val_mapping[k] = float(k)
                        
                except ValueError: # found one that isn't cast-able!
                    new_val_mapping[k] = widgets.Text(
                        value="0",
                        placeholder='Type float',
                        description=k,
                        disabled=False,
                        style=label_style)
            # display the values that have not been cast yet
            for k,v in new_val_mapping.items():
                if type(v) is not float:
                    display(v)
            # save button for when user is done fixing the numbers
            numeric_replacement_button = widgets.Button(description="save numbers")
            numeric_replacement_button.on_click({lambda a: self.save_numbers(new_val_mapping, a)})
    def save_numbers(self, new_val_mapping, button):
        """
        Remaps numbers if they weren't already numeric. This is only called if the user was required to provide input to make a value castable as numeric.
        """
        cont = True
        for k,v in new_val_mapping.items():
                if type(v) is not float:
                    try:
                        self.new_val_mapping[k] = float(v.value)
                        v.close()
                    except:
                        self.output_box.append_stdout(k+" needs to be numeric!, "+v.value+" is not numeric!")
                        cont = False
        if cont == True:
            # map if the user didn't screw up!
            self.metadata_dataframe[self.alexandria_col] = self.df[self.local_col].map(new_val_mapping)
            button.close()
                
            self.continue_to_next_column()

    def map_ontology_data(self):
        """
        Makes the grid appear for mapping each unique term of the 'self.local_col' to an entry in the ontology for the attribute saved in 'self.alexandria_col'
        """
        self.output_box.clear_output()
        self.output_box.append_stdout("Each value in this column will need to be mapped to a controlled vocabulary. In the first box, type a search term. Then, click the search button next to it and select from the dropdown the closest match. If this is not a required metadata value, you may leave the drop down blank by not clicking the search button.")
        # get the list of unique values to map in this column
        unique_keys = list(self.df[self.local_col].unique())
        # this function will make a grid of number of unique keys x 3 where the first column is a text box
        # to enter a search term for the ontology. The second column is a 'search' button, and the third column is a 
        # dropdown menu with the search results.
        # self.grid is a dictionary mapping the key in local_col to a widgets.HBox holding the values
        self.grid = {} # cols are search input, search button, value selection
        # saving each one because I think they might be overwriting each other if I don't in this for loop?
        searches = [0 for i in range(len(unique_keys))]
        searchbuttons = [0 for i in range(len(unique_keys))]
        dropdowns = [0 for i in range(len(unique_keys))]
        # make a row for each unique key
        for i,k in enumerate(unique_keys):
            # search term text box
            searches[i]=widgets.Text(
                                value=k,
                                placeholder='search term',
                                description=k,
                                disabled=False,
                                style=label_style)
            # search button
            searchbuttons[i] = widgets.Button(description="search "+k)
            # search results dropdown
            dropdowns[i] = widgets.Dropdown(
                 options=[""],       
                 value="",
                 description=k)
            # for some reason this isnt working, k is always the last term in this for loop. rude.
            searchbuttons[i].on_click(lambda a : self.search_ontology(k,a))
            # save as final grid
            self.grid[k]=widgets.HBox([searches[i],searchbuttons[i],dropdowns[i]])
        # display the grid
        for row,v in self.grid.items():
            display(v)
        # a button will save all these values once the user is done setting them!
        save_button = widgets.Button(description="save")
        display(save_button)
        save_button.on_click(lambda a : self.save_ontology_map(unique_keys,a))

    def search_ontology(self, rowname, button):
        """
        Run the search for the ontology term. Runs when the button for each ontology search is pressed.
        """
        # for some reason the rowname that is passed is not correct, so this hack works
        rowname= button.description.split("search ")[1]
        grid_row = self.grid[rowname]
        # run the query
        list_for_dropdown, name_id_dict=uh.query_search_term(self.metadata_info.loc[self.alexandria_col,"ontology"].split("/")[-1],grid_row.children[0].value)
        # save the results to the existing dropdown menu that you made before
        if len(list_for_dropdown)>0:
            grid_row.children[2].options = list_for_dropdown
            grid_row.children[2].value = list_for_dropdown[0][1]
    
    def save_ontology_map(self, unique_keys,button):
        """
        Save the mapping of ontology values from the unique keys for each row in self.df
        """
        key_mapping_ontology = {}
        key_mapping_values = {}
        for i,k in enumerate(unique_keys):
            # TODO: what if one value is not selected??
            key_mapping_ontology[k] = self.grid[k].children[2].value
            key_mapping_values[k] = self.grid[k].children[2].label.split(":")[0] # not using the name_id_dict here because this works fine but if you change what the labels look like that is going to be bad
        # save ontology and the __ontology_label
        self.metadata_dataframe[self.alexandria_col] = self.df[self.local_col].map(key_mapping_ontology)
        self.metadata_dataframe[self.alexandria_col+"__ontology_label"] = self.df[self.local_col].map(key_mapping_values)
        
        self.continue_to_next_column()
    
    
    def select_controlled_list(self):
        """
        Show selection dropdowns from each unique local value to the values in a controlled list
        Called when a controlled list metadata type is selected as self.alexandria_col
        """
        self.output_box.clear_output()
        self.output_box.append_stdout("This column is a controlled list, please select the value for each term:")
        # This will need to be changed if there is a different format for controlled_list_entries in the input file 
        # also if you upload from JSON you will need to change this
        contrl_list = self.metadata_info.loc[self.alexandria_col, "controlled_list_entries"].strip("[").strip("]").strip("\"").split("\", \"")
        
        unique_keys = list(self.df[self.local_col].unique())
        key_mapping_dict = {}
        for k in unique_keys:
            key_mapping_dict[k] = widgets.Dropdown(
                options=contrl_list+ [""],
                value=contrl_list[0],
                description=k,
                style=label_style)      
            display(key_mapping_dict[k])
        map_button = widgets.Button(description="map")
        display(map_button)
        map_button.on_click(lambda a :self.map_controlled_list(key_mapping_dict, a))

    def map_controlled_list(self, key_mapping_dict, map_button):
        """
        Map values from self.df to selected controlled list values
        Called after the map button is selected
        """

        for k,v in key_mapping_dict.items():
            # TODO: what if there is no selection for one of these?
            key_mapping_dict[k] = v.value
            v.close()
        map_button.close()
        self.metadata_dataframe[self.alexandria_col] = self.df[self.local_col].map(key_mapping_dict)
        self.continue_to_next_column()

    def select_string_data(self):
        """
        Accepts text input for string data 
        """
        self.output_box.clear_output()

        self.output_box.append_stdout("This metadata column is a non-controlled string type. It will be directly mapped from the values in your column if you do not change these values and press 'map' below. If you would like to change their values, change these text boxes and press")
        unique_keys = list(self.df[self.local_col].unique())
        key_mapping_dict = {}
        for k in unique_keys:
            key_mapping_dict[k]=widgets.Text(
                                value=k,
                                placeholder=k,
                                description=k,
                                disabled=False,
                                style=label_style)
            display(key_mapping_dict[k])
        map_button = widgets.Button(description="map")
        display(map_button)
        map_button.on_click(lambda a :self.map_string_data(key_mapping_dict, a))
    def map_string_data(self, key_mapping_dict, map_button):
        """
        Maps data that is not of a controlled type to the cell level metadata table under the Alexandria column name
        """
        self.metadata_dataframe[self.alexandria_col] = self.df[self.local_col]
        self.continue_to_next_column()
        for k,v in key_mapping_dict.items():
            key_mapping_dict[k] = v.value
            v.close()
        map_button.close()
        self.metadata_dataframe[self.alexandria_col] = self.df[self.local_col].map(key_mapping_dict)
        self.continue_to_next_column()

    def continue_to_next_column(self):
        """
        Call when you're done with this local column and alexandria column. Delete the alexandria column from the available metadata
        """
        self.available_metadata = self.available_metadata.drop(self.alexandria_col)
        self.choose_next_column_mapping()

    def finish_mapping(self, button):
        """
        Call when you're done with all the mapping!
        Called when the "I'm done mapping" button is pressed

        It will save the cell_level_metadata as a class variable, but to get it back into your notebook you need to take it from here (it is not updating the dataframe in the notebook)
        """
        #button.close()
        if self.cell_level:
            self.cell_level_metadata= pd.concat([self.cell_level_metadata, self.metadata_dataframe], sort=True, axis=1)
        else:
            # TODO: this is where you need to make an adjustment to allow for a) non-anndata cell-level objects to be mappable, and b) sample level outputs
            for val in self.metadata_dataframe.columns:
                self.cell_level_metadata[val] = self.mapping_info["cell level dataframe"][self.mapping_col].map(self.metadata_dtaframe[val])
            
