# dynamic-inventory

# AWS Infrastructure with Terraform

This repository contains Terraform code that creates an AWS infrastructure to run a web application which wewill use to test ansible dynamic inventory.

## Requirements

To use this code, you need to have the following software installed:

- Terraform
- AWS CLI

## Usage

1. Clone the repository to your local machine.
2. Change directory to the cloned repository.

4. Initialize the working directory with `terraform init`.
5. Plan the changes with `terraform plan`.
6. Apply the changes with `terraform apply`.

## Infrastructure

The Terraform code in this repository creates the following infrastructure:

- A VPC with public subnet
- An Internet Gateway
- A Route Table with default route via IGW
- A Security Group for the web instances
- EC2 instances running Amazon Linux 2
- install ansible, boto3, and aws ec2 ansible plugin
- copy the secret key to the ansible master server

## License

This code is released under the [MIT License](LICENSE.md).
