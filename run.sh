#!/bin/bash
set -eu${DEBUG:+x}o pipefail

# Determine the absolute path of the directory containing this script
root_directory="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Create temporary directory for this execution and set a trap to delete it
work_directory=$(mktemp -d $root_directory/work-XXXXXXXX)
trap "rm -rf $work_directory" EXIT

#
# accentis_vault_usable:
#   This function looks for an environment variable containing the Accentis
#   Vault endpoint.  If it finds it, it then looks for an environment variable
#   containing a Vault token.  If both of these environment variables are
#   found, it attempts to validate the Vault token.  If this last step passes
#   the function returns with a success status, indicating that the Vault is
#   already up and running and can be used to obtain credentials.
#
function accentis_vault_usable {
    if [[ ${ACCENTIS_VAULT_ADDR:+x} == x ]] && [[ ${ACCENTIS_VAULT_TOKEN:+} == x ]]; then
        if curl -f -H "X-Vault-Token: $ACCENTIS_VAULT_TOKEN" $ACCENTIS_VAULT_ADDR/v1/auth/token/lookup-self > /dev/null ; then
            return 0
        fi
    fi

    return 1
}

#
# accentis_vault:
#   This function is a convenient wrapper that runs Vault commands using a
#   container, so that the Vault client doesn't need to be installed on the
#   workstation.  This function passes all of its arguments to the container
#   as vault arguments.
#
function accentis_vault {
    docker run -it \
        -e VAULT_TOKEN=$ACCENTIS_VAULT_TOKEN \
        -e VAULT_ADDR=$ACCENTIS_VAULT_ADDR \
        -e SKIP_SETCAP=1 \
        vault:latest \
        vault "$@"
}

#
# gcp_login:
#   This function ensures that Google Cloud application default credentials are
#   in place under the temporary directory.  As a convenience, the current
#   user's home directory will be examined for an existing application default
#   credentials file, and if one is found the operator will be given the option
#   to use those credentials.  If the operator declines using the credentials
#   that were found, or none exist, a login operation will be launched.
#
function gcp_login {
    # Create a subdirectory for the GCP credentials.
    mkdir -p $work_directory/gcp_creds

    # Look for Application Default Credentials already on the workstation
    if stat $HOME/.config/gcloud/application_default_credentials.json > /dev/null ; then
        echo "Google Cloud application default credentials already exist on this workstation."
        echo "You can choose to use these, or complete 2-legged OAuth exchange to obtain new credentials (the existing workstation credentials won't be affected)."
        read -p "Do you want to use the existing credentials? (Y/n): " answer

        if [[ ${answer:0:1} != n ]] && [[ ${answer:0:1} != N ]]; then
            # Create a symbolic link to the workstations GCP credentials directory.
            cp $HOME/.config/gcloud/application_default_credentials.json $work_directory/gcp_creds/
            return 0
        fi
    fi

    docker run -it \
        --mount type=bind,source="$work_directory/gcp_creds",target=/root/.config/gcloud \
        gcr.io/google.com/cloudsdktool/cloud-sdk:latest \
        gcloud auth application-default login
}

#
# packer:
#   This function is a convenient wrapper that runs Packer using a container,
#   so that Packer doesn't need to be installed on the workstation.  This
#   function relies on proper GCP credentials being in place in the
#   $work_directory/gcp_creds directory.
#
#   The following variables also need to be set: $root_directory and
#   $commit_hash.
#
function packer {
    docker run -it \
        --rm \
        -e GOOGLE_APPLICATION_CREDENTIALS=/root/.config/gcloud/application_default_credentials.json \
        --mount type=bind,source="$work_directory/gcp_creds",target=/root/.config/gcloud,readonly \
        --mount type=bind,source="$root_directory",target=/work,readonly \
        -w /work \
        hashicorp/packer:1.6.2 \
        build \
        -force \
        -var root_password=$root_password \
        -var commit_hash="$commit_hash" \
        -var project=accentis-288921 \
        "/work/template.pkr.hcl"
}

#
# terraform:
#   This function creates and configures a Docker container so that Terraform
#   can be run inside. This container contains a copy of the verify directory
#   rather than volume mounting it; this will keep the local Terraform state
#   file inside the container and not contaminate the verify directory when
#   multiple images are being tested in parrallel.
#
function terraform {
    if [ ! "${skip_terraform_init+x}" ]; then
        docker run -it \
            --rm \
            -e GOOGLE_APPLICATION_CREDENTIALS=/root/.config/gcloud/application_default_credentials.json \
            --mount type=bind,source=$work_directory/gcp_creds,target=/root/.config/gcloud,readonly \
            --mount type=bind,source=$root_directory/verify,target=/work \
            -w /work \
            hashicorp/terraform:0.13.2 \
            init
    fi

    docker run -it \
        --rm \
        -e GOOGLE_APPLICATION_CREDENTIALS=/root/.config/gcloud/application_default_credentials.json \
        --mount type=bind,source=$work_directory/gcp_creds,target=/root/.config/gcloud,readonly \
        --mount type=bind,source=$root_directory/verify,target=/work \
        -w /work \
        hashicorp/terraform:0.13.2 \
        "$@"
}

#
# to_list_string:
#   This function takes any number of positional parameters and concatenates
#   them into a single string.  The elements in the string are separated by
#   commas (,) and also surrounded by quotation marks (").
#
function to_list_string {
    string=
    while [ $1 ]; do
        string=$string,"$1"
        shift
    done

    echo ${string:1}
}

commit_hash=$(git rev-parse --short HEAD)

if accentis_vault_usable ; then
    root_password="$( accentis_vault kv get -field=root_password build-secrets/packer )"

    mkdir -p $work_directory/gcp_creds
    accentis_vault read -field=private_key_data gcp/key/terraform-bootstrap | base64 --decode > $work_directory/gcp_creds/application_default_credentials.json
else
    read -s -p "Enter password to set for root account in image (will be hidden): " root_password

    gcp_login
fi

packer
image_names=($(jq '[.builds[].artifact_id][]' manifest.json | tr '\n' ' ' | tr -d '"'))
image_names_list=$(to_list_string ${image_names[@]})

# Provision the test instances.
terraform apply -auto-approve -var 'image_names=['$image_names_list']'

ip_addresses=($(skip_terraform_init=1 terraform output -no-color -json instance_ip | tr -d '[]"' | tr ',' ' '))

verify_failed=()
i=0
while [ $i -lt ${#ip_addresses[@]}; do
    build_name=$(jq -r '.builds[]|select(.artifact_id=="'${image_names[$i]}'").name')
    skip_vars=$(jq -r '.'$build_name'[]|keys[]' justifications.json 2> /deb/null | sed -e 's/^/export SKIP_' -e 's/$/=1/' -e 's/\./_/g' | tr '\n' ';' | sed 's/;/; /g')
    echo "Verifying $build_name"
    scp $root_directory/verify/audit.sh ubuntu@${ip_addresses[$i]}:/tmp/audit.sh
    ssh ubuntu@ip_address sudo bash -c 'chmod +x /tmp/audit.sh; '$skip_vars' /tmp/audit.sh' || verify_failed+=($build_name)
    i=$(expr $i + 1)
done

# Destroy the test instances.
terraform destroy -auto-approve -var 'image_names=['$image_names_list']'

# Clean up Terraform related files.
rm -rf $root_directory/verify/.terraform $root_directory/verify/terraform.tfstate*

# If the verify_failed array contains any elements, return an unsuccessful code
if [ ${#verify_failed[@]} -gt 0 ]; then
    echo '**********************************************'
    echo ' FAILURE SUMMARY'
    echo '----------------------------------------------'
    for x in ${verify_failed[@]}; do
        echo "$x"
    done
    echo '**********************************************'
    exit 1
fi
