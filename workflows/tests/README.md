# WORKFLOW TESTING DIRECTORY

## Required file tree

The scripts in this directory are not very portable, not well written, and require a certain file tree:
 
workflows/  
	workflow_A.wdl  
	workflow_Asub.wdl  
	tests/  
		[bash scripts]  
		cromwell/  
			cromwell-*.jar  
			womtool-*.jar  
			cromwell.conf  
			cromwellsa.json  
			cromwell_workflow_options.json  
			monitor_script.sh  
		dummies/.  
			workflow_A/.  
				workflow_A_dummy.wdl  
				taskA1.sh  
				taskA2.sh  
				taskA3.sh  
			workflow_Asub/
				workflow_Asub_dummy.wdl  
				taskB1.sh  
				taskB2.sh  

The idea is that public workflows go into workflows/  
tests/ can be added to the .gitignore  
cromwell/ and dummies/ are hidden in tests/

## make_dummy.sh
`chmod +x make_dummy.sh`
`./make_dummy.sh ../workflow_A.wdl`

Deletes workflow_A_dummy.wdl if it is found in dummies/workflow_A/
Makes a new workflow_A_dummy.wdl and fills its command blocks with task scripts in dummies/workflow_A/
If a task script does not exist, it will be created (by a call to output_parser.sh)
You can edit these scripts to be whatever you want. It's advisable to do so.

## validate.sh and inputs.sh
TODO

## run.sh
TODO