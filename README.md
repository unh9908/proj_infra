# Terraform Setup

## Prerequisites:

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

# AWS Tutorial with Boto3, AWS CLI, and Python

This is a simple walkthrough to help you get started writing AWS Lambda Functions (Serverless Applications). It begins with a simple, barebones function and grows difficult until you've eventually implemented the final project. Example code snippets are provided for all of the steps needed to complete the final project, but the provided snippets are for AWS CLI commands. Part One of this walkthrough contains the following sections:
- Writing Your First Lambda Function
- Running Functions
- Dude, Where's my STDOUT?

It goes over how to create the relatively simple Hello World lambda function. If you're looking to dive head-first, just make sure you've read over:
- Before You Start
- Connecting and Syncing Files

Then skip down and follow these sections:
- Differences with VPC and non VPC
- Writing Functions that deal with RDS and VPC

However, this guide was built with the previous sections serving as building blocks for the future sections.

However, this guide was built with the previous sections as building blocks for future sections.
You can achieve all of the same things by using boto3 if you prefer, though it's not covered in the examples. For some ideas you can leverage on managing AWS resources and services using boto3 and python scripts, look at the
[boto3 section for examples](#using-boto3-instead)

## Table of Contents

 - [Before You Start](#before-you-start)
 - [Connecting and Syncing Files](#connecting-and-syncing-files)
 - [Writing Your First Lambda Function](#first-lambda-function)
 - [Running Functions](#running-functions)
 - [Dude, Where's my STDOUT?](#why-logging-matters)
 - [Writing Useful Functions](#writing-useful-functions)
 - [Differences with VPC and non VPC](#how-vpc-changes-things)
 - [COMP851 - Final Project Implementation](#comp851-final-project-guide)
 

---
## Before You Start

This walkthrough assumes you've already completed Part I of the project and deployed your AWS Infrastructure using Terraform to provision S3, EC2, RDS, and the VPC RDS lives inside it. Should you need any extra information about their configuration, refer to the TF State File in the s3 bucket that Terraform provisioned. That TF State file will have every single bit of configuration information for already existing and provided resources you will need.

For this project, since we don't have access to the AWS Management Console for the provisioned resources, we log into the jump-host and use either boto3 or aws cli commands to manage and configure everything. Generally, I recommend keeping a text file with important information so you don't constantly have to query things.

It may be worthwhile to incorporate this project with Git and move this zip archive somewhere into a Git repo you can manage. There is **lot** of configuration that happens, and it is nice to use Git Actions or Git Hooks to automate the packaging of your Lambda Functions before you deploy them to AWS. NOTE: This guide does not cover setting that up. Otherwise, it would be ridiculously longer.

Also, consider, as you go through this guide, there are plenty of opportunities to turn the AWS CLI commands into easy-to-use shell scripts or Python scripts if you prefer using `boto3` instead of `aws cli.`
## Prerequisites

1. **completed part one of this project, using Terraform**
2. Preferably local machine is a linux machine
3. Or a windows machine using Windows Subsystem for Linux
4. Rsync installed locally on machine
5. SSH Key-Pair configured to connecting to provisioned Jump-Host from Terraform. Private key should have perms set to 0600 using `chmod`
6. A clean fresh copy of the .zip archive you found this README.md that contains the boiler-plate files you'll be using to build lambda functions. 

## Connecting and Syncing Files

You'll need to be able to connect to the Jump-Host (EC2 Instance) to complete this project. Ensure the configured private key is locked down appropriately and the public key is on the upstream machine.

### Connecting to the Jump-Host
Connect With
```bash
ssh -i "<path_to_private_key>" ec2-user@<jump-host-ip>
```

so depending on what your jump-host has configured for a publicly reachable IP address you might use: 
```bash
ssh -i "~/.ssh/mySecurePrivateKey" ec2-user@107.20.85.21
```
as an example of connecting to a jump-host

### Uploading to the Jump Host

You'll also need to sync files from your local machine to whichever directory you're working on, in the jump-host. You can do so with: 
```bash
rsync -avz -e "<path_to_ssh_private_key>" <local_directory_path_sync> ec2-user@<jump-host>:<target_destination_on_remote>
```
This will let you upload a local directory to the destination path on your jump-host. 

### Downloading from the Jump Host

```bash
rsync -avz -e "<path_to_ssh_private_key>"
ec2-user@<jump-host>:<remote_directory_path> <local_target_directory>
```
This will let you download your remote directory from the jump host to the specified local directory.

It's important to remember that Rsync only sends the difference of the files, so it is efficient over network resources. And for whatever reason, if a transfer fails, re-running the same command will resume the file syncing between local and remote machines where it left off.

###

## Writing Your First Lambda Function
For extra information on Lambda Functions you can [click here](https://docs.aws.amazon.com/lambda/latest/dg/welcome.html) to see more.  

### Quick Primer on Lambda Functions
Lambda functions are *serverless applications* you can create without having to worry about provisioning servers (in the sense of physically buying them), and instead, you pay per the compute hours of when the Lambda Function is computing information.

To deploy a lambda function to AWS, you must create a zipped archive containing the serverless application source code and all of its dependencies if they are **not** already in the standard library for Python or Amazon's *AMI*. [click here for more info](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-instances-and-amis.html)

For the directory structure of the first-lambda function we write; it'll look something like this: 
```bash
tree my_lambda_function_directory

# output of the above command
my_lambda_function_directory
├── <external dependencies> 
└── hello_lambda.py
```

In any directory in which you're creating a lambda function, the Python source file will always be at the top level of the directory structure. Any external dependencies not included in the standard Python distribution or the AMI will be in sub-directories. To ensure proper staging of the lambda directory, it's best to use pip to install the modules directly like this:

```bash
pip install <some_python_module> -t <path_to_lambda_function>
```

In the case that I wanted to install boto3 to my lambda function directory, so its available to my lambda function when it invokes and runs, I would first cd into that directory:
```bash
cd my_lambda_function
```

And then install boto3 locally to that directory like so:
```bash
pip install boto3 -t .
```
### An Example Lambda Function in Python

Just to get us started with a simple Lambda Function, so you can get a feel for what's involved in the process using `aws cli`, we'll start with hello_lambda. 

```python
import json

def lambda_handler(event, context):
    return {
        "statusCode": 200,
        "body": json.dumps({
            "message": "Hello World!",
        }),
    }
```

With lambda functions, it's not incorrect to do so, but there's no reason to use the shebang that you would normally see at the top of a python source file: 
```python
#!/usr/bin/env python3
```

In this example, JSON is already part of the standard Python distribution for the "Hello Lambda" function we're writing, so there are no dependencies to worry about when packaging this function. The only thing to keep a note of is the name of the function that's going to handle the actual serverless application. In this case, it's named `lambda_handler` and accepts two objects, an event object and a context object. We'll discuss those later, but for now, know that's typically the giveaway for a Python function that will be used as a Lambda Function in AWS.

If it doesn't exist, create a directory on your local machine to store the lambda function after copying the Python source file.
```bash
mkdir HelloLambda;
cp hello_lambda.py ./HelloLambda; 
zip -r HelloLambda.zip ./HelloLambda
```

You should now, have a zip file named `HelloLambda.zip`, or whatever you decided to name it. Go ahead and upload that to the directory you're working out of on your jump-host
```bash
rsync -avz -e "~/.ssh/<private-key>" ./HelloLambda.zip ec2-user@<ip-addr>:<where-ever_youre_working_out_of>/HelloLambda.zip
```

Next we'll be creating the function using `aws cli` with the zip archive uploaded to the jump-host, to configure the function for basic execution. 

### Create Hello-Lambda on the Jump-Host

Once we have a zip-archive on the Jump-Host, it's time to get it configured to run on AWS. **EVERY** lambda function you write for AWS, will have at a bare minimum: 
 - trust-policy.json
 - IAM role

More involved lambda functions, like the one we'll be creating for the Final Project will have: 
 - trust-policy.json
 - IAM role
 - permission-policy.json
 - security groups that are attached to the lambda function
 - inbound / outbound rules dictating which IP addresses and Protocols the lambda function can send or receive information from
 - Unique ARNs (Amazon Resource Names) the lambda function can interact with
 - Subnet IDs that allow the lambda function to associate with resources on those specific subnet-ids
 - VPC-ID that allow the lambda function to interact with Virtual Private Clouds (like the one configured by Terraform in Part 1)
 - etc., Lambda Functions are able to interact with almost anything under the sun; provided they're configured properly for the task you want them to handle

### trust-policy.json

This is the trust-policy that informs AWS what role-policy your lambda function is going to have. We'll be using this document for all lambda functions made in this tutorial: 
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

After you've saved it in the same directory containing `HelloLambda.zip`, go ahead and create an AWS IAM role for the lambda function: 
```bash
aws iam create-role --role-name hello-lambda-role --assume-role-policy-document file://trust-policy.json
```

Now, you'll be ready to create your first lambda function on AWS. This is also a good time to get into the habit of saving off important pieces of the JSON responses that you get from the different `aws cli` commands in STDOUT like the: 
 - names
 - ARNs
 - unique ids
 - etc

for the different resources we create, so you don't have to constantly query for things (though in some cases that's unavoidable). 

To make the lambda function HelloLambda, run the following `aws cli` command: 
```bash
aws lambda create-function --function-name HelloLambda \
--zip-file fileb://HelloLambda.zip \
--handler hello_lambda.lambda_handler \
--runtime python3.9 \
--role arn:aws:iam::[Your-AWS-Account-ID]:role/hello-lambda-role
```
- **--function-name**: this is what AWS will call your lambda function
- **--zip-file**: zip archive containing lambda application and external dependencies
- **--handler**: this is the function inside your source code file that defines what your Lambda Function is going to do when it's invoked. It *must* be defined inside the source code file, otherwise the above code example *will* fail.
- **--runtime**: Even though there's a conda environment for the jump-host and the local machine. You have to specify which Python environment the lambda function will be using. This will be explained further below during the implementation of Part 2 for the Final Project. 
- **--role**: this is the unique ARN of the IAM role created with the trust-policy.json, and later on with the attached permission-policy.json that your Lambda Function will be using to execute its task with. If this is improperly configured your lambda function may not have the necessary permission to interact with different resources in the AWS environment

If the above command was successful, you'll see pretty-printed JSON in STDOUT with all the different configuration details of your lambda function. 

## Running Functions

### Basic Lambda Invocation
After creation, the function is now ready to get tested to see if everything has been configured properly. In order to manually invoke an aws lambda function, use: 
```bash
aws lambda invoke --function-name <name_of_lambda_function> response.json
```

So for the HelloWorld lambda function we just wrote, we would use:
```bash
aws lambda invoke --function-name HelloLambda response.json
```

If your lambda function handles the Event Object, and Context Object that was passed in as a parameter or does any processing, you provide input to it with the following: 
```bash
aws lambda invoke --function-name ExampleLambda --payload fileb://sample_input_data.json response.json
```

## Why Logging Matters 

When your Lambda function executes after manually invoking it from the aws cli using `aws lambda invoke,` you may have noticed that what gets printed to the console is just the JSON statements we configured in the HelloLambda function inside of hello_lambda.py. In addition, another file called response.json will have more JSON information about the execution of that lambda function.

Typically, during a lambda function's execution, it does not print to standard out and instead provides JSON responses that you configure for it to offer status codes (much like HTTP response codes).

This is why in more involved lambda functions, using the logger library in Python is **crucial** along with giving your lambda function permission to write to AWS CloudWatch. When you use logger in Python, it'll write those log messages to AWS CloudWatch, assuming your lambda function has permission to publish messages to CloudWatch logs.

Later on, this will be the best insight into what your lambda function is doing as it executes. This also highlights how important it is for your lambda function to be configured properly for what it will be interacting with and to structure error handling in your Python source file.

Inside lambda_functions, it's widespread to see code wrapped in `try .. except .. finally` blocks—that log information in each block or significant section of the lambda function. The only real debug information will come from the CloudWatch Logs.

To make sure your Lambda Function has the permissions necessary to publish to CloudWatch, attach the following policy to the IAM role your lambda function uses to execute:
```bash
aws iam attach-role-policy \
--role-name hello-lambda-role \ 
--policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
```

`AWSLambdaBasicExecutionRole` comes from AWS, but attaching it to the IAM role the lambda function is using, will also allow said lambda function to write information to the logs. 

Accessing the logs can be achieved through:
```bash
aws logs describe-log-streams \
--log-group-name /aws/lambda/[YourLambdaFunctionName]
```

Which will return JSON, with information about each lambda invocation CloudWatch has tracked for the Lambda Function you specify. 

If you only want to sort the log-streams by the most recent execution:
```bash
aws logs describe-log-streams \
--log-group-name /aws/lambda/[YourLambdaFunctionName]
--order-by LastEventTime \
--descending
```
This will put the log-streams of your specified Lambda Function in descending order for the most recent log-streams being at the top of the list, and the oldest at the bottom. 

Or, you can always limit the query to the most-recent invocation you performed:
```bash
aws logs describe-log-streams \
--log-group-name /aws/lambda/[YourLambdaFunctionName]
--order-by LastEventTime \
--descending
--limit 1
```
And this will return only the most recent invocation of your lambda function that was specified in the `--log-group-name` argument. 

In order to view the actual log, that contains useful information about the execution of your lambda function use the following:
```bash
aws logs get-log-events \
--log-group-name /aws/lambda/[YourLambdaFunction] \
--log-stream-name '[Long String Containing Name of Log Stream]'
```

So when you find that something isn't happening correctly with your lambda function you can follow the basic flow of: 
1. Print out your Lambda Configuration Information
2. Verify it's configured properly for the task
3. Check your python source file for any syntax issues
4. Check the CloudWatch Logs to see what's being written
5. Make a note to see if your Lambda Function has enough memory allocated to it, (there will be a line in the cloudwatch log for this)
6. See if the lambda function has enough time to execute before timing out (this will be in the same line with the memory allocated to the lambda function)

In the event you do find something wrong with your lambda function, you can fix the specific config parameters that weren't correct using: 
```bash
aws lambda update-function-configuration \
--function-name [Lambda Function] \
--<some_config_parameter> [New Value to use for Update]
# reuse the above line for as many parameters need updating
```

Updating the actual Python source file used is more involved. You'll need to update the Python source file and then repackage the lambda function in a zip file like we did earlier with all the dependencies. But instead of creating a new function and IAM role, or anything else you run:
```bash
aws lambda update-function-code \
--function-name [Lambda Function] \
--zip-file fileb://[Lambda Function].zip
```

### Brief Recap

All lambda functions need a few things: 
1. some source file defining functions and libraries the serverless application will be using
2. a zip archive containing that serverless application at the top-level of the directory, and all of the 3rd party libraries not in the AMI or Python Standard Library
3. an IAM role for the lambda function to assume
4. Permission Policies that allow the lambda function access to different resources

More involved functions will need additional configuration information: 
 - Subnet IDs
 - VPC ID
 - Security Group
 - Inbound Rules
 - Outbound Rules
 - Permission Policies per each resource it interacts with

i.e.
 - S3 
 - Other Lambda Functions
 - CloudWatch
 - RDS
 - etc. 

Congrats! You've written your first ever lambda function for AWS, and you have a decent idea of the basic workflow now

---

## Writing Useful Functions

The previous section went over the basic workflow of: 
 - creating a source file
 - packaging that source file and its dependencies
 - uploading it to AWS and creating the lambda function
 - making changes to it and seeing how it runs via CloudWatch

This section will focus more on an example Lambda Function that does something useful. In this case, it will check to see if it can connect to the Port used for PostgreSQL (Port 5432). Write to the CloudWatch logs if it was successful or not, and handle simple errors when connecting to RDS.

The bare shell of the Python source file and some additional commands for AWS CLI that you'll likely find helpful in the development of the final project in the next section will be provided.

As for the AWS Resources that get integrated, it'll be AWS Lambda + AWS RDS. RDS is the service that handles the PostgreSQL instance configured inside of the VPC that Terraform configured for us earlier in Part 1 of this project.

### Python File: lambda_check_psql.py (Outline)
```python
import socket
import logging

# setup logger for INFO level logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# specify an IPv4 socket for TCP/IP connection
client_sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)


def check_port(event, context):
"""
You'll find every single piece of config information you need
for the RDS instance in your TF State File. Including the RDS_DNS_LABEL you'll need, amongst other bits of information.
"""
    IP = 'RDS_DNS_LABEL.some-aws-regions.amazonaws.com'
    PORT = 5432

    try:
        # connect socket to Port 5432 of the PostgreSQL instance
        # On success, it will log to cloudwatch: 
        # f'{PORT} on {IP} is open'
        # break / return / exit here 
    except:
        # implement error handling here
        # If the socket can't connect to RDS it will log
        # f'{PORT} on {IP} is closed'
        # break / return / exit on failure, AFTER logging
    finally:
        # this section executes regardless of the above status
        # one idea is to programmatically set the value of the response code JSON provides based upon if the function was successful or not, or do any cleanup that's necessary
        # for this particular function that won' be really necessary, but if you really wanted you could make a call to client_sock.close() to stop listening to Port 5432
```

The AWS SDK Links in other parts of this project contain examples for logging information for CloudWatch, and the Sokcet library is very well documented and easy to find examples on google if you need them. 

Once you've written this file, go ahead and package into a directory name that makes sense to you and upload to the jump-host:
```bash
mkdir lambda-port-check;
```
```bash
cp ./lambda_check_port.py ./lambda-port-check/
```
```bash
zip -r LambdaCheckPort.zip ./lambda-port-check/
```
```bash
rsync -avz -e "~/.ssh/<private-key>" .LambdaCheckPort.zip ec2-user@<jump-host>:/path/to/remote/directory/you/want/
```

Once it's been uploaded to the ec2 instance / jump-host you'll want to do the following: 
 - create an IAM role using the trust-policy.json
 - be sure to note down the role-name and role-arn of the newly created IAM role 
 - attach the permission-policy from AWS for the BasicLambdaExecutionRole to grant permissions to write to CloudWatch Logs
 - create the lambda function using AWS CLI
 - try testing the lambda function manually using `aws lambda invoke`

If you need a refresher on how to do this, refer to the earlier section where this guide walks through the basic steps of creating and configuring an [AWS Lambda Function](#first-lambda-function)

Once the lambda function has finished executing when you run, check the cloud watch logs. You're really only going to be interested in the most recent execution of the invocation of this function. 

After you verify that there were no syntax issues, with the python source file, find in the cloud-watch logs where the status of the PSQL port is reported. 

Is it what you were expecting? 

## Differences with VPC and Non VPC

In this case, AWS Lambda has given us a nice little surprise. By default, AWS Lambda functions can not interact with private VPC resources (Things inside of the Virtual Private Cloud) since Lambda Functions can communicate with things on the internet. The above lambda function we made to check to see if a port is open for PostgreSQL won't work with the default configuration information we provided the lambda function.

However, once we update the configuration information for the lambda function, it will no longer be able to communicate with AWS services. It needs the open-net or public internet, like SNS, which sends simple notifications. This is because once a Lambda Function becomes associated with a VPC, it's considered a VPC-Bound.

It may seem annoying at first. However, AWS does let you re-enable public internet access for Lambda-Functions that are VPC bound by configuring NATs, Elastic Network Interfaces, and VPC Endpoints; however, that's beyond the scope of this guide and project.

Short Summary:
Lambda Functions that don't need VPC access can communicate with AWS resources, like S3 Buckets, SNS (message notifications), CloudWatch, SQS (Simple Queue Service), other AWS Lambda Functions, or other Endpoints you want Lambda to interact with.

Lambda Functions that do need VPC access can't communicate with resources requiring public internet access, like publishing e-mail messages with SNS to e-mail subscribers or SMS subscribers. At least not without doing additional network configurations

Optional:
You can review the TF-State File, where you've retrieved all the information you need to get the RDS DNS Label of your PostgreSQL instance. You may as well since the next section of this guide depends heavily on that file.

And we can fix the Lambda function above by gathering: 
 - VPC-ID that's associated with our RDS Instance running PostgreSQL
 - Subnet-IDs that are associated with the RDS Instance inside the VPC 
 - Inbound & Outbound traffic setup for the TCP protocol on port 5432
 - What Security Group the RDS Instance is Using 
 - Be sure to note the name of the security-group, security-group id (sg-xxxxxxxxxxx), and it's arn
 - You'll also want the ARN of the RDS instance

Once we have that information, we'll need to do a few things to update our lambda function so it can interact with VPC Resources. 

### Associate Lambda with VPC

First let's get Lambda associated with the VPC our RDS instance is using: 
```bash
aws lambda update-function-configuration \
--function-name LambdaPortCheck \
--vpc-config SubnetIds=SUBNET_ID1,SUBNET_ID2,SUBNET_ID3,SecurityGroupIds=SECURITY_GROUP_ID
```
Pay note to the syntax on the `--vpc-config`, if you put a space between the comma separating SUBNET_ID & SecurityGroupIds, the command will fail due to syntax

### Attach VPC Policy Permission to Lambda

This next part is easy if you've been following the sage advice of saving helpful information about your Lambda Functions or other AWS resources. You'll want to attach VPC permissions to the IAM role your Lambda Function uses for its execution.

You can use: 
```bash
aws lambda get-function --function-name [Name of Function]
```
to print out the JSON for how that specific lambda is configured. 
Or if you don't want to litter your screen with JSON
```bash
aws lambda get-function-configuration \
--function-name [Lambda-Function-Name] \
--query 'Role' \
--output text | awk -F'/' '{print $NF}'
```
If you prefer working with text output, you can override the output with the `--output` argument, so text is printed instead of JSON. Really depends on what you're comfortable with, and like using to handle the output from the commands `aws cli` provides. 

Once you have the role-name that your lambda function uses, attach the following policy to it: 
```bash
aws iam attach-role-policy \
--role-name [Role-Name-From-Lambda-Function] \
--policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole
```

The last part of this process is crucial and important, we need both Security-Groups: Our Lambda Security Group, and our RDS Security Group to refer to each other. 

### Updating Inbound and Outbound Traffic Rules

We need to modify the inbound traffic rules for the RDS Security Group
```bash
aws ec2 authorize-security-group-ingress \
--group-id [RDS Security Group ID] \
--protocol tcp \
--port 5432
--source-group [Lambda Function Security Group ID]
```
This allows Lambda Functions in the Lambda-Security-Group with the Lambda-Security-Group ID to send data to the RDS instance. From the perspective of PostgreSQL, we're allowing only TCP traffic on Port 5432 from Lambda Functions that use the Security Group ID we specify.

Not all situations always call for this; however, if we need RDS to send information back to the lambda function, we need to update the Lambda Function's Security Group to allow for this explicitly.
```bash
aws ec2 authorize-security-group-egress \
--group-id [RDS Security Group ID] \
--protocol tcp \
--port 5432
--destination-group [Lambda Security Group ID]
```

Once you've updated the configuration for the LambdaPortCheck function, reinvoke it, and you should see in the CloudWatch Logs that it's logging that Port 5432 on your RDS instance is Open!

The following section is implementing the complete final project. If you've been doing all sections ahead, it's pretty simple; though, if you jump straight into it without reading all of this guide's other sections, it may seem *daunting*.

I recommend finding your preferred way of bundling the `aws cli` commands into more useful scripts to save yourself some typing.

---

## COMP851 Final Project Guide

### Brief Recap

This guide has walked through simple lambda creation and more involved lambda creation, creating and attaching IAM roles, role policies (granting permissions to lambda), security groups, updating function configuration, logging, and debugging Lambda Functions. Ideally, you're comfortable moving your work to and from your local machine and the jump-host now.

For those jumping straight in, doing the first two parts of the walkthrough is recommended to let some of the concepts sink in since this part can be frustrating, especially if you miss a small detail or need to remember a step. However, once you have the process of Lambda Creation down and are getting AWS Resources configured, it goes smoothly and quickly.

For this project, we'll be looking at a Lambda Function that:
 - Given an event in an S3 bucket
 - Processes the information regarding that event
 - Updates the RDS instance of PostgreSQL via `upsert`
 - If PostgreSQL doesn't have a table to track this information, Lambda creates it
 - If PostgreSQL already has a record for the object that changed from the s3 event, instead of throwing an error it just updates the information
 - After the upsert has finished, the functions logs the status to the CloudWatch Logs

Once ready to upload the function to AWS, we'll test it manually by invoking it with `aws cli` and providing a dummy event using a sample JSON file that simulates the response from an s3 event.

Upon success, you can query PSQL to see that information has been updated in your PSQL database. Below is an outline of the file you'll be filling in the details for

### Python File: s3_upsert_psql.py
```python
import os
import sys
import json
import boto3
import logging
import psycopg2
from mimetypes import guess_type
from datetime import datetime

# create a logger, with logging level set to INFO
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# initialize a psycopg2 client 

# Use os.environ to retrieve PostgreSQL connection details
"""
Host => RDS_DNS_LABEL_IP
Port => 5432
Database Name => Check TF-State File Configuration
User Name => Check TF-State File Configuration
Password => Check TF-State File Configuration
"""
# i.e. something like this
rds_host = os.environ['RDS_HOST']
rds_port = os.environ['RDS_PORT']
# etc. 


# IMPORTANT PLEASE DO THIS IN YOUR IMPLEMENTATION!!
# Keep Database connection outside of the Lambda Handler

try:
    # psycopg2.connect (connection parameters go here)
    
except:
    # error handling goes here for the database connection
    # log errors via logger, to capture them in cloudwatch
    # immediately exit, using sys.exit
    # no sense in trying to do anything else if psycopg2 connection fails

# Have logger log to cloudwatch psycopg2 connection to PSQL succeeded

def s3_lambda_upsert(event, context):
"""
This is going to be the main bulk of the project. 
It's best to break this into clear sections to keep updating 
manageable
"""
    try: 
        cursor = conn.cursor()
        # Process S3 Events for S3 Bucket
            # Iterate over the event object passed in by AWS 
            # Append the records of interest to a list
            # Grab Data you want to have in your database

        # Create s3_event_log table in PSQL if it doesn't exist yet
        # you don't have to call it that, but just make sure the name of your table makes sense to you
        # you'll be wrapping SQL inside of a psycopg2 method
        # cursor.execute (
        #    """
        #    CREATE TABLE IF NOT EXISTS ... 
        #    """
        #)
    
        # This is where the Upsert Logic happens, you'll be using cursor.execute here as well
        # cursor.execute(
        # """
        # INSERT INTO s3_event_log (field1, field2, field3, etc)
        # VALUES
        # ON CONFLICT (object key)
        # DO UPDATE SET
        # """
        #)
        # Upsert Logic examples are plentiful on google 
        # stack overflow
        # and github, be sure to look around
    
        # commit your changes to PostgreSQL 
        conn.commit()
    
        logger.log("Finished Processing {Event} from {Bucket}")
        logger.log("Updated {TABLE} in {DB_NAME}")
    
    except:
        # this is where you handle errors and log them to Cloudwatch
        # call sys.exit after everything you need is logged
    
    finally:
        # this is where I would put the return statement 
        # and json dumps, that you saw in the first lambda function
        # remember this section will always execute
        # so its a good spot for cleaning up once you're done as well
```

Once you're confident you have this file implemented, go ahead and have it uploaded to your jump-host after packaging. Remember, not all of the libraries imported are in the standard python distribution or the AMI. We'll need to install the dependencies for psycopg2!
```
mkdir LambdaS3Upsert;
cp s3_upsert_psql.py LambdaS3Upsert;
cd LambdaS3Upsert;
pip install psycopg2-binary -t .
```
After installing dependencies, its time to package
```bash
zip -r LambdaS3Upsert.zip ./LambdaS3Upsert/
```
And then upload to Jump-Host
```
```bash
rsync -avz -e "~/.ssh/<private_key>" ./<zip_archive> ec2-user@<jump-host-ip>:path/to/directory/you/want/
```

Once we've done that and we're ready to get started creating the necessary pieces to make this function work. 

### Create the IAM role for you lambda-function

This is where you want to use trust-policy.json
```bash
aws iam create-role --role-name Lambda-S3-Upsert-Role --assume-role-policy-document file://trust-policy.json
```

### Make the LambdaS3Upsert Function

For now we'll go ahead and create the function, we can always update it later to attach VPC Execution Role, Basic Lambda Role, The Security Group, etc. 

```bash
aws lambda create-function \
--function-name LambdaS3Upsert \
--zip-file fileb://LambdaS3Upsert.zip \
--handler s3_upsert_psql.lambda_handler \
--runtime python3.9 \
--role-arn arn:aws:iam::[Your-AWS-Account-ID]:role/Lambda-S3-Upsert-Role
```

### Configuring Lambda to use Environment Variables

Before you get ahead of yourself and try to add Environment Variables for Lambda, understand that Lambda's Environment variables are separate from your Shell environment variables.

When AWS executes or invokes a lambda function, the lambda function is run from an isolated environment that's not attached to your shell session. Effectively, your Lambda Function is executed within its own VPC, and once it's finished running, all of its data disappears. This is another reason why logging is essential; Data regarding Lambda Functions from the function's invocation is not guaranteed to be persistent.

With that out of the way, it doesn't take much to configure lambda to use environment variables. Once the function has been created, update the configuration:
```bash
aws lambda update-fucntion-configuration \
--function-name LambdaS3Upsert \
--environment "Variables={USER_NAME=rds_user_name,HOST=rds_host_name,PORT=psql_port,DB_NAME=rds_db_name,PASSWORD=rds_user_password}"
```
Ideally, it's better to configure AWS Secret Manager or KMS to handle passwords and keys for database connections instead of storing plaintext passwords in JSON configurations. **HOWEVER** The critical part of this project is getting Lambda to interact with VPC Resources like RDS and then do valuable things.

You'll want to change the values after the equal sign in all of those variable assignments to what's contained in the TF-State File.

To check if you have the correct information, you should be able to manually connect to the PostgreSQL instance managed by RDS in the VPC. (You can always manually access this via the jump-host)
```bash
psql -h [RDS_DNS_LABEL.terraform.region.amazonaws.com] -U db_user_name -d name_of_database
```

Afterwards, you should be logged into the PSQL terminal, as the database user, connected to the database specified by the `-d` flag. 
```sql
postgres=# -- \d shows you the relations of your table if you have one
```
or
```sql
postgres=# select * from name_of_table;
```

As of right now, both of those commands shouldn't produce output as Lambda has not configured any tables for upserting information to. 
### Configuring S3 Event Notifications

We need to make an event configuration for our S3 Bucket. Instead of manually invoking our lambda function or having it run on a set schedule, we can have AWS invoke the function automatically when the type of events we register happen in the S3 Bucket of our choosing.

event.json, we'll use this to configure when the Lambda function is invoked by S3 Events
**s3-event.json**
```json
{
  "LambdaFunctionConfigurations": [
    {
      "LambdaFunctionArn": "arn:aws:lambda:region:account-id:function:LambdaS3Upsert",
      "Events": [
        "s3:ObjectCreated:*",
        "s3:ObjectRemoved:*"
      ]
    }
  ]
}
```
Grant S3 permission to invoke Lambda
```bash
aws lambda add-permission \
--function-name [Lambda-Function-Name] \
--principal s3.amazonaws.com \
--statement-id s3invoke \
--action "lambda:InvokeFunction" \ 
--source-arn arn:aws:s3:::[YOUR_S3_BUCKET]
```

Configure bucket notifications
```bash
aws s3api put-bucket-notification-configuration \
--bucket [S3_BUCKET_NAME] \
--notification-configuration file://s3-event.json
```

### Configuring for execution in the VPC 

If you have done the previous section, you can mainly copy and paste the configuration steps you performed when Associating the Lambda function to the VPC, in addition to setting up the Lambda Security Group and then updating the inbound and outbound rules for TCP on port 5432 for Lambda and RDS security groups to refer to each other.

Create your Lambda Function's Security Group:
```bash
aws ec2 create-security-group \ 
--group-name Lambda-VPC-Sec-Grp \
--description "Security Group for Lambda Functions using VPC" \
--vpc-id [MAKE SURE THIS ID IS THE SAME AS THE VPC RDS USES]
```
As always, if you're trying to make sure you use the correct VPC-ID associated to RDS, it'll be in the TF-State file from Terraform. 

### Update inbound/outbound traffic rules for TCP on Port 5432

Allow Lambda ingress on RDS over TCP using Port 5432
```bash
aws ec2 authorize-security-group-ingress \
--group-id [RDS Security Group ID] \
--protocol tcp \
--port 5432
--source-group [Lambda Function Security Group ID]
```

Allow RDS egress to Lambda over TCP using Port 5432
```bash
aws ec2 authorize-security-group-egress \
--group-id [RDS Security Group ID] \
--protocol tcp \
--port 5432
--destination-group [Lambda Security Group ID]
```

Associate Lambda to VPC of RDS and Subnets 
```bash
aws lambda update-function-configuration \
--function-name LambdaPortCheck \
--vpc-config SubnetIds=SUBNET_ID1,SUBNET_ID2,SUBNET_ID3,SecurityGroupIds=SECURITY_GROUP_ID
```

Lastly we attach the VPC Execution Role to our Lambda function:
```bash
aws iam attach-role-policy \
--role-name [Role-Name-From-Lambda-Function] \
--policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole
```

### Manual Execution and Testing

This is the s3-test-event.json from the boilerplate directory found in the project zip archive you received, along with all the other boiler-plate.json files. 

**s3-test-event.json**
```json
{
  "Records": [
    {
      "eventVersion": "2.0",
      "eventSource": "aws:s3",
      "awsRegion": "us-east-1",
      "eventTime": "2023-01-01T12:00:00.000Z",
      "eventName": "ObjectCreated:Put",
      "s3": {
        "bucket": {
          "name": "<S3_BUCKET_NAME_HERE>",
          "arn": "<REPLACE_WITH_S3_BUCKET_ARN>"
        },
        "object": {
          "key": "testfile.txt",
          "size": 1024
        }
      }
    }
  ]
}
```

Above is a decent example of that actual event object passed into the Lambda Function by AWS when the function is invoked. We'll use this sample payload to manually invoke our function and test to ensure that Lambda is creating our PSQL Table to keep track of S3 Events for the bucket we configured S3 Events for. In addition, it'll record the time, the event, the object, the size of the object, and whatever else you can scrape from the event data at first.


Invoke the new lambda function manually; update things as needed. The default memory allocation for a lambda function is 128MB, which may need to be more to handle all imported libraries.
```bash
aws lambda invoke \
--function-name LambdaS3Upsert \
--payload fileb://s3-test-event.json \
response.json
```

The memory allocation is also tied to performance; moving to 512MB or 756MB may shorten how long your Lambda takes to execute. So, while the cost per compute rate increases, the duration decreases. In many cases, it may be cheaper to run your Lambda Function with additional memory allocated to it.

Pay attention to the cloud watch logs to ensure your lambda function is behaving correctly and that you can see in the CloudWatch Logs if it's successfully connecting to your PostgreSQL instance in the VPC.
```bash
aws logs describe-log-streams \
--log-group-name /aws/lambda/[YourLambdaFunctionName]
--order-by LastEventTime \
--descending
--limit 1
```

```bash
aws logs get-log-events \
--log-group-name /aws/lambda/[YourLambdaFunction] \
--log-stream-name '[Long String Containing Name of Log Stream]'
```

### Full-Send, Having Fun with lambda

Once the function is configured, you can see that it's updating data in PSQL. Go ahead and gather some random text files and some image files and make a directory on your local machine. Using either `boto3` or `aws cli,` upload all those files to your S3 Bucket. After you've uploaded anywhere between 10-15 files, go ahead and delete some of those duplicate files you've uploaded.

The S3 Event Log in the PSQL instance in the VPC should have plenty of data.
Can you set up the lambda function to properly use guess_type from the mime-type Python library?
If done correctly, you can also have the Python lambda handler try to infer the type of file it processed from the s3 event.

Don't worry if you can't get it working, however. If your lambda function upserts data into the RDS instance and everything else is correct, don't worry too much about bundling everything into tidy little scripts for automating these steps. Or see what else you can make the lambda function do.

Once you have your lambda function tested, it's working. Download your working function from the Jump-Host using rsync:
```bash
rsync -avz -e "~/.ssh/<private_key>" ec2-user@<jump_host>:/path/to/your/lambda/function/archive.zip ~/some/path/where/you/want/it.zip
```
This will be part of your deliverables that Professor Chadwick wants. 

### Tearing it Down
We need to delete lambda functions manually before we can have Terraform destroy everything.
```bash
aws lambda delete-function \
> --function-name [Your-Lambda-Function] \
> --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole
```
Once you're completely done with this project, go ahead and use Terraform to delete your VPC Infrastructure that was used for this project. 

---
## Using Boto3 Instead
[If you want to use Boto3 Instead of AWS CLI](#boto3/README.md)
### Boto3 Code Examples from Amazon
[boto3: s3 examples](#https://github.com/awsdocs/aws-doc-sdk-examples/tree/main/python/example_code/s3)
[boto3: iam examples](https://github.com/awsdocs/aws-doc-sdk-examples/tree/main/python/example_code/iam)
[boto3: lambda examples](#https://github.com/awsdocs/aws-doc-sdk-examples/tree/main/python/example_code/lambda)
[boto3: rds examples](#https://github.com/awsdocs/aws-doc-sdk-examples/tree/main/python/example_code/rds)
[boto3: cloudwatch examples](#https://github.com/awsdocs/aws-doc-sdk-examples/tree/main/python/example_code/cloudwatch)
[boto3: ec2 examples](#https://github.com/awsdocs/aws-doc-sdk-examples/tree/main/python/example_code/ec2)

---



