# Prerequisites:

- Install Terraform from https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli#install-cli

click on install on the top in the menu - select your operating system

- To install execute all the commands as listed except for touch ~/.bashrc (This is required only if bashrc file does not already exist)

- Install AWS cli and configure aws credentials if not already done. Please note you may have AWS credetials already set up if you have executed S3 bucket assigment then you already have set up AWS credentials

# Execution Steps

- clone the git repository https://github.com/unh9908/proj_infra.git
- cd into **setup** directory and open main.tf file to update bucket name, replace comp851 with your unh username in "comp851-terraform-state-%s"

run below commands one at a time
-   
``` 
terraform init   
terraform validate   
terraform plan   (if you see a prompt for aws region enter us-east-1)
terraform apply  (confirm the prompt by typing "yes")
```
- Wait for the resources to be created.
- you should now see a s3 bucket created in the default vpc, check if you see a new s3 bucket that has your username (aws s3 ls will list all the buckets)

**Now we create other resources a new vpc, jumpserver and rds instance**

- cd into networking directory and open main.tf file, replace "comp-851" with your unh username in "comp851-rds_sg"    
- Now cd into region/virgina directory change the s3 bucket name (replace comp851 with your username as you did before and make sure that the bucket name matches with the previously created bucket in S3) in providers.tf file at the bottom in backend "s3" section and save.   
- Create public and private key pair using "ssh-keygen -f jump-server" command.    
- Open main.tf file in "ec2" directory and replace the value of public_key with the value from "proj_infra/module/virginia/jump-server.pub" file.
- Now navigate back to region/virginia and open main.tf file, update vpc name by replacing "comp851" with your username in "comp851-VPC".

- Execute below commands from virginia directory
```
terraform init   
terraform validate   
terraform plan   
terraform apply 
```

Now you should have a new VPC created with a jumpserver to connect to the internal aws private subnet where the rds instance is created. To connect to RDS instance, we first need to SSH to jump-server instance. You can check the resources using command "terraform show"

**Steps to connect to jump host**
- Get the public ip of the jump server instance from the output of "terraform show" command. Look for public ip or public_dns of the jumpserver ec2 instance because you need this to connect to jump server instance.
- Once you find the public ip, ssh to the jump server using "ssh -i privatekeypath ec2-user@publicip". Replace the place holders privatekeypath and publicip.
- After connecting to jump-server execute below commands to install postgresql client

sudo yum update   
sudo amazon-linux-extras install postgresql10   
- nano /home/ec2-user/miniconda3/pkgs/libpq-16.0-hfc447b1_1/share/pg_hba.conf.sample - skip this step if the file does not exist
update the authentication type to md5   

- Check if you are able to connect to postgresql database from jump server using command "psql -h rdshostname -U comp851 -d staging". You can find the rds hostname in the terraform state file which you opened earlier to find public ip of jump server. 

- Once you confirm the connectivity from jump-server to rds instance, move on to the next part of the execution.

- Install miniconda on the jump-server by following below commands:

```
mkdir -p ~/miniconda3
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda3/miniconda.sh
bash ~/miniconda3/miniconda.sh -b -u -p ~/miniconda3
rm -rf ~/miniconda3/miniconda.sh
~/miniconda3/bin/conda init bash
source ~/.bashrc
conda --version
```

- Create conda environment using the env.yml from the project root directory, you need to copy the env.yml file to jump server or create one and paste the content then run commad to create conda env is "conda env create -f path to env.yml file"