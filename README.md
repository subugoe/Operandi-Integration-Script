
# Operandi Integration Script

This script is made to integrate Operandi with other tools such as Goobi and Kitodo. Also, it can be used as an interface to use Operandi services or use local OCR-D processing. It also supports LAREX viewer to display the PageXML Results. 
`script_native.sh` is for terminal use with OCR-D native installation.
`script_docker.sh` is for terminal use with OCR-D docker installation.
`goobi_operandi.sh` is used for Operandi-Goobi integration.
`kitodo_operandi.sh` is used for Operandi-Kitodo integration.
`upload_to_ola_hd.sh` is used for OLA_HD-Kitodo-Goobi integration.



## Usage
All values can be set using the corresponding flags unless you want to use the default values. The script is so dynamic, you only need to know which values are required in your case and set them by the corresponding flags. 

Provided below are some scenarios but no all possible scenarios.

### Usage Case 1: You have mets file or URL.
`./script_docker.sh -e -u <user:pass> -m <mets_url or mets_file_path> -w <workspace_name or path>`
### Usage Case 2: You only have the images. 
`./script_docker.sh -u <user:pass> -i <images_directory> -w <workspace_name or path>`
### Usage Case 3: You have OCRD ZIP.
`./script_docker.sh -u <user:pass> -z <workspace.ocrd.zip>`
### Usage Case 4: To use OCR-D on your local machine in any of the above cases use -l
Example: `./script_docker.sh -i <images> -l -w <workspace_name or path>`

The results will be displayable at http://localhost:1476/Larex/



## Procedures

- Creates a workspace (with or without mets)
- Generates OCR-D zip file
- Validates the generated OCR-D zip file
- Uploads the OCR-D zip to Operandi
- Uploads a workflow or use the default one
- Submit the job to Operandi
- Checks the status of the job till it is finished
- Download the results zip file and logs zip file
- Archive the results and upload it to OLA-HD 


## Flags

- `-e [no arguments]` to create a workspace from an existing mets file or mets URL.
- `-l [no arguments]` to use the local OCR-D processing.
- `-v [no arguments]` to control viewing the results in LAREX. The default value is `true`. Use the flag to switch it off. 
- `-o [required an argument. Ex: ola_user:ola_pass]` to upload the results to OLA-HD and set OLA-HD username and password.
- `-s [requires an argument. Ex: http://operandi.ocr-d.de]` to set the server address. 
- `-u [required an argument. Ex: user:pass]` to set operandi user and password.
- `-w [requires an argument. Ex: WS1, or Workspace/WS1]` to set the workspace directory name or path.
- `-m [requires an argument. Ex: http://url.mets.xml]` to set mets URL that needs to be cloned.
- `-i [requires an argument. Ex: path/to/images/]` to set the path of the images directory.
- `-f [requires an argument. Ex: MIN, MAX, DEFAULT..etc]` to set the file group.
- `-n [requires an argument. Ex: nextflow.nf]` to upload a new Nextflow workflow.
- `-c [requires an argument. Ex: 4, 8, 10…etc]` to set the number of CPUs in the HPC.
- `-r [requires an argument. Ex: 8,16,32…etc]` to set the number of RAM Gigabytes in the HPC.
- `-z [requires an argument. Ex: workspace.ocrd.zip]` to upload an OCR-D zip file to Operandi directly and get the results.



## Default Values and The Corresponding Flags

- `-w` Workspace Directory= `ws_<current_time_stamp>` 
- `-s` Server Address = `http://operandi.ocr-d.de`
- `-f` File Group= `DEFAULT`
- `-n` Workflow= `default_workflow.nf`
- `-i` Images Directory= `$(pwd)/images`
- `-c` CPUs= `8`
- `-r` RAM= `64`
- `-v` LAREX_VIEW= `true`



### email notifications for the Logs
To activate it, you need to set RECIPIENT_EMAIL to a non-empty value. As long as RECIPIENT_EMAIL is empty, the script will not send any email notification.

There are two ways to send email notifications for the logs depending on the service provider requirements. You will find two functions in the script t do this: `send_log_by_email` and `send_log_by_email2`. You can modify which function do you want to use at line 469.

`send_log_by_email` uses `mail` command line to send emails and it requires that your machine must be whitelisted on the mailer server. Do this by asking the service provider eg: GWDG to set you machine ip in the whitelist for the mailer service.

`send_log_by_email2` uses `curl` command line to send emails. In this case, you need to modify the following variables in the script:
```# Email settings
SMTP_SERVER="smtp.example.com"
SENDER_EMAIL="sender@example.com"
SENDER_PASSWORD="your_password"
RECIPIENT_EMAIL="recipient@example.com"
```

