terraform {
    backend "local" {
    }

    required_version = "~> 0.13"

    required_providers {
        google = {
            version = "~> 3.39.0"
            source  = "hashicorp/google"
        }
    }
}

provider "google" {
    region = "us-central1"
}

variable "image_names" {
    description = "A list of names for images to test"
    type        = list(string)
}

variable "public_ssh_key" {
    description = "The public SSH key to configure on the instances."
    type        = string
}

variable "ssh_username" {
    description = "The username to configure the public_ssh_key with."
    type        = string
    default     = "ubuntu"
}

variable "project" {
    description = "The GCP project ID"
    type        = string
    default     = "accentis-288921"
}

data "google_kms_key_ring" "test" {
    name     = "${var.project}-keyring"
    location = "global"
    project  = var.project
}

data "google_kms_crypto_key" "test" {
    name     = "disk-encryption"
    key_ring = data.google_kms_key_ring.test.self_link
}

resource "google_compute_instance" "test" {
    count = length(var.image_names)

    boot_disk {
        initialize_params {
            image = var.image_names[count.index]
        }
        kms_key_self_link = data.google_kms_crypto_key.test.self_link
    }
    
    machine_type = "n1-standard-1"
    name         = "accentis-packer-${var.image_names[count.index]}"
    zone         = "us-central1-a"
    
    network_interface {
        network = "default"

        access_config {}
    }

    allow_stopping_for_update = false
    metadata = {
        ssh-keys = "${var.ssh_username}:${var.public_ssh_key}"
    }
    project = var.project
    scheduling {
        preemptible       = true
        automatic_restart = false
    }
    shielded_instance_config {
        enable_secure_boot          = true
        enable_vtpm                 = true 
        enable_integrity_monitoring = true
    }
}

output "instance_ip" {
    value = google_compute_instance.test[*].network_interface.0.access_config.0.nat_ip
}
