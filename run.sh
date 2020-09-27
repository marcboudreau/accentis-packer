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
# accentis_gcloud: 
#   This function is a convenient wrapper that runs gcloud commands using a
#   container, so that Google Cloud SDK doesn't need to be installed on the
#   workstation.  This function passes all of its arguments to the container
#   as gcloud arguments.  This function also ensures that the directory
#   $work_directory/gcp_creds exists, and bind mounts that directory as a
#   volume into the container.
#
function accentis_gcloud {
    mkdir -p $work_directory/gcp_creds

    docker run -it \
        --mount type=bind,source=$work_directory/gcp_creds,target=/root/.config/gcloud \
        gcr.io/google.com/cloudsdktool/cloud-sdk:latest \
        gcloud "@$@"
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
# generate_ssh_key:
#   This function generates a new SSH key pair that will be configured onto the
#   test instances.  This key pair will be used to run the verification test
#   suite.  The key pair is generated in the temporary work directory, so it is
#   automatically deleted when the script exits.
#
function generate_ssh_keys {
    ssh-keygen -q -b 2048 -t rsa -N '' -C '' -f $work_directory/id_rsa
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
        --mount type=bind,source="$root_directory",target=/work \
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
    while [ $# -gt 0 ]; do
        string="$string,\"$1\""
        shift
    done

    echo ${string:1}
}

#
# promote_image:
#   This function creates a new GCE Image using the candidate image as the
#   source and assigns it to the specified image family.  Once the image has
#   been successfully completed, the candidate image is deleted.
#
function promote_image {
    local candidate_name=$1
    local family_name=$2
    local release_name=${candidate_name/"candidate-"/}

    # Clone the candidate image as an image in the specified image family and
    #   if successful, delete the candidate image.
    gcloud compute images create $release_name \
            --source-image $candidate_name \
            --family $family_name --quiet && \
        gcloud compute images delete $candidate_name --quiet

    # Obtain list of images from the specified image family and trim off the
    # first two items.  These images will be permanently deleted.
    excess_images=($(gcloud compute images list \
            --filter "family: $family_name" \
            --sort-by "~creationTimestamp" \
            --format "value(name)" \
            --quiet | \
            awk '{print $1}' | tail +3))

    if [ ${#excess_images[@]} -gt 0 ]; then
        for excess_image in ${excess_images[@]}; do
            gcloud compute images delete $excess_image --quiet
        done
    fi
}

commit_hash=$(git rev-parse --short HEAD)

if accentis_vault_usable ; then
    root_password="$( accentis_vault kv get -field=root_password build-secrets/packer )"

    mkdir -p $work_directory/gcp_creds
    accentis_vault read -field=private_key_data gcp/key/terraform-bootstrap | base64 --decode > $work_directory/gcp_creds/application_default_credentials.json
else
    if [ ! "${PACKER_ROOT_PASSWORD:-}" ]; then
        read -s -p "Enter password to set for root account in image (will be hidden): " root_password
    else
        root_password=$PACKER_ROOT_PASSWORD
    fi

    gcp_login
fi

# Run Packer to build the images.
packer

# Extract the produced image names.
last_run_uuid=$(jq -r '.last_run_uuid' manifest.json)
image_names=($(jq '[.builds[]|select(.packer_run_uuid=="'$last_run_uuid'").artifact_id][]' manifest.json | tr '\n' ' ' | tr -d '"'))
image_names_list=$(to_list_string ${image_names[@]})

# Generate temporary SSH keys for this execution.
generate_ssh_keys

# Provision the test instances.
terraform apply -auto-approve -var 'image_names=['$image_names_list']' -var public_ssh_key="$(cat $work_directory/id_rsa.pub)"
ip_addresses=($(skip_terraform_init=1 terraform output -no-color -json instance_ip | tr -d '[]"\r' | tr ',' ' '))

# The verify_failed array contains the names of failed images.
verify_failed=()

(
    # Iterate over each produced image to run the verification test suite.
    i=0
    while [ $i -lt ${#ip_addresses[@]} ]; do
        ip_address=${ip_addresses[$i]}
        image_name=${image_names[$i]}

        # Build up the verify.env file (contains the SKIP_ environment variables).
        build_name=$(jq -r '.builds[]|select(.packer_run_uuid=="'$last_run_uuid'")|select(.artifact_id=="'$image_name'").name' manifest.json)
        jq -r '.'$build_name'[]|keys[]' justifications.json 2> /dev/null | sed -e 's/^/SKIP_/' -e 's/$/=x/' -e 's/\./_/g' > $work_directory/verify.env

        # Wait until port 22 is open at the remote IP address.
        tries=0
        while ! nc -z $ip_address 22 > /dev/null 2>&1 ; do
            tries=$(($tries + 1))
            if (( $tries > 100 )); then
                echo "Maximum number of attempts to reach port 22 on $ip_address to verify $build_name image: moving on."
                verify_failed+=($build_name)
                continue 2
            fi

            sleep 1
        done

        # Upload the audit.sh script and the verify.env exemption file.
        scp -q -i $work_directory/id_rsa -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no "$root_directory/verify/audit.sh" "ubuntu@${ip_addresses[$i]}:/tmp/audit.sh"
        scp -q -i $work_directory/id_rsa -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no "$work_directory/verify.env" "ubuntu@$ip_address:/tmp/verify.env"

        failed=0

        # Adjust permissions and ownership of the audit.sh file and run it.
        ssh -i $work_directory/id_rsa -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o LogLevel=ERROR "ubuntu@$ip_address" "sudo chmod 0755 /tmp/audit.sh"
        ssh -i $work_directory/id_rsa -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o LogLevel=ERROR "ubuntu@$ip_address" "sudo chown root:root /tmp/audit.sh"
        ssh -i $work_directory/id_rsa -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o LogLevel=ERROR "ubuntu@$ip_address" "sudo bash /tmp/audit.sh" || failed=1
        
        if [[ $failed == 1 ]]; then
            verify_failed+=($build_name)
        else
            promote_image $image_name $build_name
        fi

        i=$(($i + 1))
    done
) || true

# Destroy the test instances.
skip_terraform_init=1 terraform destroy -auto-approve -var 'image_names=['$image_names_list']' -var public_ssh_key="$(cat $work_directory/id_rsa.pub)"

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
