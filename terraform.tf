terraform {
  required_version = ">=1.9.0"

  required_providers {
    talos = {
      source  = "registry.terraform.io/siderolabs/talos"
      version = "0.9.0"
    }

    hcloud = {
      source  = "registry.terraform.io/hetznercloud/hcloud"
      version = "1.59.0"
    }

    helm = {
      source  = "registry.terraform.io/hashicorp/helm"
      version = "~> 3.1.0"
    }

    http = {
      source  = "registry.terraform.io/hashicorp/http"
      version = "~> 3.5.0"
    }

    tls = {
      source  = "registry.terraform.io/hashicorp/tls"
      version = "~> 4.1.0"
    }

    random = {
      source  = "registry.terraform.io/hashicorp/random"
      version = "~>3.7.2"
    }

  }
}
