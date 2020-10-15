# `infracontainer` pattern

Version 0.0.1 -- feedback welcomed

## What is in this file?

* Overview of `infracontainer` concept
* Step-by-step demo
* Description of `infracontainer` interface specification

## What is this repo?

Infracode is not useful until it has been integrated into an infrastructure orchestration system that will feed it configuration information and run it when required. Historically that integration has been tightly coupled to the choice of infrastructure-as-code tool. This meant that when Terraform needed to be supplemented with another tool, or hit some quirk or limitation, then the infrastructure orchestration system needed to be modified, even if only a small subset of the overall infrastructure was affected.

Imagine you could shield your infrastructure orchestration system from all the implementation details of Terraform, and even shield it from the fact that Terraform is (or is not) present at all. Imagine you could arbitrarily compose Terraform modules (or infracontainer images built from those modules) without worrying about provider interactions or any other quirks.

`infracontainer` is a standard way to present a Docker image which, when run with its configuration filled in, will deploy infrastructure. 

From the user's perspective, their infrastructure needs have been reduced to a single (or small number of) black boxes which they run to ensure that their required infrastructure is present. The underlying implementation and the overall organisation's architecture can scale into infinite complexity whilst retaining simplicity in every individual business context.

From an infracoder's perspective, it's still Terraform. You develop your Terraform config like normal, publish modules, etc. When it comes time to deploy to production or production-like environments, however, the option arises to package your Terraform stack as an `infracontainer`, thus allowing it to be consumed in a simple way. 

How the container does its work is nobody's business, unless something goes wrong and you go in to debug it like normal. The use of the `infracontainer` facade does not prevent you from `docker exec` or `ssh`-ing into the container to poke around. The contents of the container may be completely arbitrary; you can package Terragrunt or PowerShell or anything else you might find useful.

Overall, the purpose of this project is to separate the implementation of infrastructure as code from its presentation to users, by packaging infracode as a Docker container that implements a standard set of commands (based on `terraform` subcommands) in its entrypoint script. 

This repo contains templates and examples. Happy infracoding!

## How to run the demos

The demos are based on Azure. You can get a Free Trial subscription (roughly equivalent to an AWS account) from https://portal.azure.com which will be sufficient for this demo.

### Prerequisites

* This guide assumes that:
  * you have an Azure subscription where you are Owner and 
  * you have the ability to create service principals in the subscription's AAD tenant
    * A service principal is used for now, but the plan is to implement a mechanism where you can mount your `az login` credentials when running locally, and use service principals in production
* You will need the following software:
  * `docker`
  * `make`

### Prepare target environment and credentials

* Create a service principal (if you don't already have one) and stash its credentials:
```
$ az ad sp create-for-rbac -n icdemo > credentials.json
```
  * NOTE: by default the service principal will get Owner on the subscription, which will allow it to do things later.
* Create a resource group for the demo
```
$ az group create --location australiaeast --name icdemo
```
* Create a state bucket (a storage account and blob container for storing Terraform state files):
```
$ az storage account create -g icdemo -n someuniquenamenottoolong
$ az storage container create --account-name someuniquenamenottoolong --name tfstate
```
* Create a file `backend.json` and fill in the values:
```
{
  "type": "azurerm",
  "resource_group_name": "icdemo",
  "storage_account_name": "someuniquenamenottoolong",
  "container": "tfstate",
  "key": "icdemo.tfstate"
}
```

### Run the demo

* Build an infracontainer Docker image from a module, in this case the `resource-group` module:
```
$ make MODULE=resource-group
```
* Prepare an `inputs.json` to configure an instance of the module:
```

  "resource_group_name": "coolgroup",
  "azure_location": "australiaeast"
}
```
* Tets the infracontainer with Docker by viewing the help message:
```
$ docker run -it \
-v "$PWD"/../credentials.json:/in/credentials.json \
-v "$PWD"/sample-resource-group-backend.json:/in/backend.json \
-v "$PWD"/sample-resource-group-inputs.json:/in/inputs.json \
-v "$PWD"/demo-output:/out \
az_resource-group:0.01
```
* Run the infracontainer to deploy the infrastructure:
```
$ docker run -it \
-v "$PWD"/../credentials.json:/in/credentials.json \
-v "$PWD"/sample-resource-group-backend.json:/in/backend.json \
-v "$PWD"/sample-resource-group-inputs.json:/in/inputs.json \
-v "$PWD"/demo-output:/out \
az_resource-group:0.01 create
```
  * Note how the configuration files (`credentials.json`, `backend.json` and `inputs.json`) are bind-mounted, as well as a directory for the infracontainer's output to be written.

## `infracontainer` interface spec version 0.0.1

NOTE: The code in this repo does not yet fully implement the spec.

### Behaviour of an image

An `infracontainer` image must have an entrpoint script which implements the commands described below. This requires the image to have the directories `/in/`, `/out/` and `/logs/`, but makes no other prescription about the contents of the image.

Each command is initially defined by reference to a `terraform` CLI command, but the image may use any tool (e.g. CloudFormation or `curl`) to implement the behaviour.

Mandatory commands:

* `create` -- akin to `terraform apply`
* `update` -- same as `create`, but future versions may include some logic to assert existence/non-existence of state file
* `read` -- updates the state file in the backend with the current state of the deployed resource
* `destroy` -- akin to `terraform destroy`
* `plan` -- saves a file to `out/plan.json` which describes what the `create` or `update` command would have done

Optional commands:

* `console` -- runs an interactive shell containing an environment configured according to how it would be configured for a run of the `create` command
* `state-override` -- allow resources or attributes in state file to be deleted or modified, akin to `terraform state` but with greater granularity
* `adopt` -- akin to `terraform import`, generates a new state file to describe a pre-existing set of infrastructure

The following standard file paths are used for input and output of the infracontainer:
* `in/`
  * `backend.json` - configures where the infracontainer should store its state file, e.g. in an S3 bucket
  * `credentials.json` - contains credentials for accessing cloud control planes, e.g. Azure tenant ID, client ID and client secret
  * `inputs.json` - configures the deployed infrastructure, e.g. setting its name or size, or providing the IP address of another resource it should connect to
  * `logging-config.json` - tells the infracontainer where to send its logs
* `out/`
  * `plan.json` -- created by the `plan` command
  * `outputs.json` -- created by the `create`, `update` and `read` commands, this file describes selected attributes of the deployed infrastructure (e.g. the IP address of a virtual machine)
* `logs/`
  * Log files go here, unless they are shipped directly to somewhere else.

### Composing images

To produce an image C which deploys the combined infrastructure that would be deployed by images A and B, do the following:
* prepare a `mapping.json` file which maps outputs from image A to inputs to image B
* run `docker build -f combinator.Dockerfile -t ...` to produce an image which pulls in the contents of images A and B as well as `mapping.json` and `glue.sh`

When the resulting image is run, its entrypoint will be `glue.sh` which will:
* run module A in a chroot
* read `mapping.json` and copy information accordingly from `/modulea/out/outputs.json` to `/moduleb/in/inputs.json`
* run module B in a chroot
* write module B's outputs to `/out/outputs.json`

The overall result is that the combined image behaves like an infracontainer in its own right. I _think_ this process can be repeated with arbitrary numbers of layers, although the image will probably get very big.

## Future directions

* Test and iterate on the infracontainer interface, see if it is a good idea and how it can be made most convenient.
* Improve composition process to avoid duplicating files.
* Static analysis of Terraform configs and providers to enable the `terraform` binary or a provider to be replaced with a slimmed-down custom-compiled version, or with a shell script.
* ???
