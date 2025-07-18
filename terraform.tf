terraform {
  required_version = ">=1.9.0"

  required_providers {
    talos = {
      source  = "siderolabs/talos"
      version = "0.8.1"
    }

    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "1.51.0"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0.2"
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

provider "hcloud" {
  token         = var.hcloud_token
  poll_interval = "2s"
}

provider "helm" {
  kubernetes = {
    config_path = "kubeconfig"
  }
}
