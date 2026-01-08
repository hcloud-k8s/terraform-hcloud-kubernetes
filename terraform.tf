terraform {
  required_version = ">=1.9.0"

  required_providers {
    talos = {
      source  = "siderolabs/talos"
      version = "0.10.0"
    }

    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "1.58.0"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.1.0"
    }

    http = {
      source  = "hashicorp/http"
      version = "~> 3.5.0"
    }

    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.1.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "~>3.7.2"
    }
  }
}
