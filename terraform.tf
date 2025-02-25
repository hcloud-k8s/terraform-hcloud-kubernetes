terraform {
  required_version = ">=1.7.0"

  required_providers {
    talos = {
      source  = "siderolabs/talos"
      version = "0.7.1"
    }

    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "1.50.0"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.17.0"
    }

    http = {
      source  = "hashicorp/http"
      version = "~>3.4.0"
    }

    tls = {
      source  = "hashicorp/tls"
      version = "~>4.0.0"
    }
  }
}

provider "hcloud" {
  token         = var.hcloud_token
  poll_interval = "2s"
}

provider "helm" {
  kubernetes {
    config_path = "kubeconfig"
  }
}
