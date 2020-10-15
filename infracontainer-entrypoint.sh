#!/bin/bash

#
# infracontainer entrypoint script
#
# Implements `infracontainer` interface wrapped around a Terraform module in `/app/module`
#

# Configure Terraform module
cd /app/module

# To parse credentials.json
export ARM_CLIENT_ID="$(cat /in/credentials.json | jq '.appId' -r)"
export ARM_CLIENT_SECRET="$(cat /in/credentials.json | jq '.password' -r)"
export ARM_TENANT_ID="$(cat /in/credentials.json | jq '.tenant' -r)"

# Log in as service principal
az login --service-principal -t $ARM_TENANT_ID -u $ARM_CLIENT_ID -p "$ARM_CLIENT_SECRET" >/dev/null 2>&1

# Get default subscription ID
export ARM_SUBSCRIPTION_ID="$(az account show | jq '.id' -r)"

# To parse backend.json
(eval "$(cat /in/backend.json  | jq '. | to_entries | .[] | "\(.key)=\(.value)"' -r)"; printf "terraform {\n  backend \"$type\" {\n    resource_group_name = \"$resource_group_name\"\n    storage_account_name = \"$storage_account_name\"\n    container_name = \"$container_name\"\n    key = \"$key\"\n  }\n}\n") > backend.tf

# To parse inputs.json
cat /in/inputs.json | jq '. | to_entries | .[] | "\(.key) = \"\(.value)\""' -r > terraform.tfvars

# Process command
operation="$1"
shift

case "$operation" in
help)
    echo "For help, see https://github.com/pacon-vib/infracontainer-demo"
    exit 0
    ;;
create)
    echo "Time to create"
    set +x
    terraform init
    terraform apply -input=false -auto-approve
    terraform output -json > /out/outputs.json
    exit 0
    ;;
destroy)
    echo "Time to destroy"
    set +x
    terraform init
    terraform destroy -input=false -auto-approve
    terraform output -json > /out/outputs.json
    exit 0
    ;;
*)
    echo "$operation not implemented"
    exit 1
    ;;
esac

echo "If you see this then it means Pat stuffed up his select-case block lol"
exit 1
