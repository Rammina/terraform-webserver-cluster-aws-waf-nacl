# Terraform Web Server Cluster with AWS Firewall Web ACL & NACL

This [Terraform](https://www.terraform.io/) config sets up a VPC, public subnets, ALB, ASG, and other networking components along with security measures like WAF and NACLs to deploy and securely host a web application. The key resources it creates are the ALB, ASG, WAF ACL, and associated components to deploy and scale the web servers.

## Purpose

It allows you to quickly set up AWS WAF rules that identify and block common DDoS request patterns to effectively mitigate a DDoS attack on your web app's cloud infrastructure. It also comes with a Network Access Control List (ACL) to only allow the required ports and network addresses in the VPC.

Feel free to update the user data script for the ASG Launch Template based on your use cases.

## Prerequisites

- You must have [Terraform](https://www.terraform.io/) installed on your computer.
- AWS CLI v2
- [AWS (Amazon Web Services)](http://aws.amazon.com/) account and its credentials set up for your AWS CLI.

## Installation

1. Install [Terraform](https://www.terraform.io/downloads.html), if you don't already have it.

2. Configure your AWS access keys in your AWS CLI, if you haven't yet:

    ```bash
    aws configure
    ```

3. Clone this repository:

    ```bash
    git clone https://github.com/Rammina/terraform-webserver-cluster-aws-waf-nacl.git
    ```

4. Navigate into the repository directory:

    ```bash 
    cd terraform-webserver-cluster-aws-waf-nacl
    ```

## Usage

1. Install the plugins and modules needed for the configuration:

    ```bash
    terraform init
    ```

2. Check for syntax errors and missing variables/resources:

    ```bash
    terraform validate
    ```

3. Show the infrastructure changes to be made if the configuration is applied:

    ```bash
    terraform plan
    ```

4. Customize the setup by modifying the project files as needed. Feel free to update it according your needs.

5. Apply the changes to deploy the infrastructure - this provisions the resources specified in the configuration:

    ```bash
    terraform apply
    ```

6. When you are finished with the infrastructure and no longer need it, you can destroy it:

    ```bash
    terraform destroy
    ```

    This removes all provisioned infrastructure resources.

7. In between `terraform apply` and `terraform destroy`, you can modify Terraform files as needed and rerun steps 2-4 to incrementally update your infrastructure.
