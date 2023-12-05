
# Operandi Integration Script

This script is made to integrate Operandi with other tools such as Goobi and Kitodo. Also, it can be used as an interface to use Operandi services or use local OCR-D processing. 


## Procedures

- Creates a workspace (with or without mets)
- Generates OCR-D zip file
- Validates the generated OCR-D zip file
- Uploads the OCR-D zip to Operandi
- Uploads a workflow or use the default one
- Submit the job to Operandi
- Checks the status of the job till it is finished
- Download the results
- Archive the results and upload it to OLA-HD 


## Flags

- `-e [no arguments]` to create a workspace from an existing mets file or mets URL.
- `-l [no arguments]` to use the local OCR-D processing.
- `-o [required an argument. Ex: ola_user:ola_pass]` to upload the results to OLA-HD and set OLA-HD username and password.
- `-s [requires an argument. Ex: http://operandi.ocr-d.de]` to set the server address. 
- `-u [required an argument. Ex: user:pass]` to set operandi user and password.
- `-w [requires an argument. Ex: WS1, or Workspace/WS1]` to set the workspace directory name or path.
- `-m [requires an argument. Ex: http://url.mets.xml]` to set mets URL that needs to be cloned.
- `-x [requires an argument. Ex: tiff, jpg]` to set the images extension.
- `-i [requires an argument. Ex: path/to/images/]` to set the path of the images directory.
- `-f [requires an argument. Ex: MIN, MAX, DEFAULT..etc]` to set the file group.
- `-n [requires an argument. Ex: nextflow.nf]` to upload a new Nextflow workflow.
- `-c [requires an argument. Ex: 4, 8, 10…etc]` to set the number of CPUs in the HPC.
- `-r [requires an argument. Ex: 8,16,32…etc]` to set the number of RAM Gigabytes in the HPC.
- `-z [requires an argument. Ex: workspace.ocrd.zip]` to upload an OCR-D zip file to Operandi directly and get the results.


## Default Values and The Corresponding Flags

- `-w` Workspace Directory= `$(pwd)` 
- `-s` Server Address = `http://operandi.ocr-d.de`
- `-f` File Group= `DEFAULT`
- `-n` Workflow= `3515bd6c-3c79-41a4-9890-fb8bfd479162`
- `-i` Images Directory= `$(pwd)/images`
- `-x` Image extension = `jpg`
- `-c` CPUs= `4`
- `-r` RAM= `8`


## Usage
All values can be set using the corresponding flags unless you want to use the default values. The script is so dynamic, you only need to know which values are required in your case and set them by the corresponding flags. 

Provided below are some scenarios but no all possible scenarios.

### Scenario 1: 
To create a workspace from existing mets and get the results:
#### Case 1: with mets URL
`./script.sh -e -u <user:pass> -w <workspace_dir> -m <mets_url>`
#### Case 2: with mets.xml file stored in the workspace
`./script.sh -e -u <user:pass> -w <workspace_dir> `
### Scenario 2: 
To create a workspace from only the images and don't have mets file for those images
`./script.sh -u <user:pass> -w  <workspace_dir> -i <images> -x <jpg> `
### Scenario 3: 
To use an already created OCR-D zip file directly and get the results use -z
`./script.sh -u <user:pass> -z <workspace.ocrd.zip>`
### Scenario 4: 
To use the local OCR-D in any of the above cases use -l and -n to set the nextflow script 
This is an example of a nextflow that can be used in this case:
https://github.com/subugoe/operandi/blob/main/src/utils/operandi_utils/hpc/nextflow_workflows/default_workflow.nf
`./script.sh -w <workspace_dir> -i <images> -x <jpg> -l -n <default_workflow.nf>`
### Scenario 5: 
If you want to upload the results to OLA-HD use -o to insert OLA-HD username and password
`./script.sh -e -u <user:pass> -w <workspace_dir> -o <ola_user:ola_pass>`
### Other Usages:
#### If you want to upload a new workflow to Operandi use -n
`./script.sh -e -u <user:pass> -w <workspace_dir>  -n <default_workflow.nf>`
#### If you don't want to use default values, you can set any value by its flag
`./script.sh -e -u <user:pass> -w <workspace_dir>  -n <default_workflow.nf> -s <http://localhost:8000> -f <MAX> -c <8> -r <32>`

