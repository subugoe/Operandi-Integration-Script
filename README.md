
# Operandi Integration Script

This script is made to integrate Operandi with other tools such as Goobi. Also, it can be used as an interface to use Operandi services. 


## Procedures

- Creates a workspace (with or without mets)
- Generates OCRD zip file
- Validates the generated OCRD zip file
- Uploads the OCRD zip to Operandi
- Uploads a workflow or use the default one
- Submit the job to Operandi
- Checks the status of the job till it is finished
- Download the results


## Flags

- `-e [no arguments]` to create a workspace from an existing mets file
- `-s [requires an argument. Ex: http://operandi.ocr-d.de]` to set the server address. 
- `-u [required an argument. Ex: user:pass]` to set operandi user and password.
- `-w [requires an argument. Ex: WS1, or Workspace/WS1]` to set the workspace directory name or path.
- `-m [requires an argument. Ex: http://url.mets.xml]` to set mets URL that needs to be cloned.
- `-x [requires an argument. Ex: tiff, jpg]` to set the images extension 
- `-i [requires an argument. Ex: path/to/images/]` to set the path of the images directory
- `-f [requires an argument. Ex: MIN, MAX, DEFAULT..etc]` to set the file group
- `-n [requires an argument. Ex: nextflow.nf]` to upload a new Nextflow workflow.
- `-c [requires an argument. Ex: 4, 8, 10…etc]` to set the number of CPUs in the HPC
- `-r [requires an argument. Ex: 8,16,32…etc]` to set the number of RAM Gigabytes in the HPC
- `-z [requires an argument. Ex: workspace.ocrd.zip]` to upload an OCRD zip file to Operandi directly and get the results.


## Default Values and The Corresponding Flags

- `-w` Workspace Directory= `$pwd` 
- `-s` Server Address = `http://operandi.ocr-d.de`
- `-f` File Group= `DEFAULT`
- `-n` Workflow= `3515bd6c-3c79-41a4-9890-fb8bfd479162`
- `-i` Images Directory= `$(pwd)/images`
- `-x` Image extension = `jpg`
- `-c` CPUs= `4`
- `-r` RAM= `32`


## Usage

### Scenario 1: 
To create a workspace from existing mets and get the results:
#### Case 1: with mets URL
`./script.sh   -e -u <user:pass> -w <workspace_dir> -m <mets_url>`
#### Case 2: with mets.xml file stored in the workspace
`./script.sh   -e -u <user:pass> -w <workspace_dir> `
#### If you want to add a new workflow use -n
`./script.sh   -e -u <user:pass> -w <workspace_dir>  -n <nextflow.nf>`
#### If you don't want to use default values
`./script.sh   -e -u <user:pass> -w <workspace_dir>  -n <nextflow.nf> -s <http://localhost:8000> -f <MAX> -c <8> -r <32>`
### Scenario 2: 
To create a workspace from non existing mets and get the results:
`./script.sh -u <user:pass> -w  <workspace_dir> -i <images> -x <jpg> `
### Scenario 3: 
To use an already created ocrd zip file directly and get the results use -z:
`./script.sh -u <user:pass> -z <workspace.ocrd.zip>`

