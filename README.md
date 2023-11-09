# Terraform Web Server Cluster with AWS Firewall Web ACL & NACL

This [Terraform](https://www.terraform.io/) config sets up a VPC, public subnets, ALB, ASG, and other networking components along with security measures like WAF and NACLs to deploy and securely host a web application. The key resources it creates are the ALB, ASG, WAF ACL, and associated components to deploy and scale the web servers.

## Purpose

It allows you to quickly set up AWS WAF rules that identify and block common DDoS request patterns to effectively mitigate a DDoS attack on your web app's cloud infrastructure. It also comes with a Network Access Control List (ACL) to only allow the required ports and network addresses in the VPC.

Feel free to update the user data script for the ASG Launch Template based on your use cases.

## Prerequisites

- You must have [Terraform](https://www.terraform.io/) installed on your computer.
- AWS CLI v2
- [AWS (Amazon Web Services)](http://aws.amazon.com/) account and its credentials set up for your AWS CLI.