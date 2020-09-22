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

resource "google_compute_instance" "test" {
    count = length(var.image_names)

    boot_disk {
        initialize_params {
            image = var.image_names[count.index]
        }
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

output "instance_ip" {
    value = google_compute_instance.test[*].network_interface.0.access_config.0.nat_ip
}
