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

variable "image_name" {
    description = "The name of the image to test"
    type        = string
}

resource "google_compute_instance" "test" {
    boot_disk {
        initialize_params {
            image = var.image_name
        }
    }
    
    machine_type = "n1-standard-1"
    name         = "accentis-packer-test-bastion"
    zone         = "us-central1-a"
    
    network_interface {
        access_config {}
    }

    allow_stopping_for_update = false
    metadata = {
        ssh-keys = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDLn7TP1EVosXwyvm0ax0LSxxGR/wWn0FP8Nc3BAWeH99yallHNqjy4xJHbeJXramYgAUwCtFAY0NUFFw270NS7VK4AgOiughXuEZV+e6N4Q9CwjP3KY+HK71W1UQiSMPNl1bJaBZvlFtSkv5HzbP8AeogEIqSqVBJSLs43Ear4Y4kcdCz4ITfMgHQUpdWCFGTX4WufKsLPsTFSPAUeswDfEAy5ldDc1iAwZ/jsFVwqq/+c0+ahl1VkMIJTMVaHCSepevOoi3bIFBQrtciLSA37qjBGfTiMcs2F28zudBTJQEQWpibfv5P2XfY3EyCJQjWpCzNtk4KgYc5uCiOB1zIB ubuntu@server.local"
    }
    project = "accentis-288921"
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
