locals {
  relative_path = path_relative_to_include()
  path_parts    = compact(split("/", local.relative_path))
  environment   = length(local.path_parts) > 0 ? local.path_parts[0] : ""

  # ORG-WIDE ENV CONFIG (same for all repos)
  environments = {
    dev = {
      project      = "project-dev"
      region       = "europe-west4"
      state_bucket = "dev_org-terraform_state"

      labels = {
        env  = "dev"
        team = "data-analytics"
      }

      scheduler = {
        region               = "europe-west3"
        service_account_email = "scheduler-invoker-dev@project-dev.iam.gserviceaccount.com"
      }
    }

    prod = {
      project      = "project-prod"
      region       = "europe-west4"
      name  = "pilot-colocation-prod"
      state_bucket = "prod_org-terraform_state"
      labels = {
        env  = "prod"
        team = "data-analytics"
      }

      scheduler = {
        region               = "europe-west3"
        service_account_email = "scheduler-invoker-prod@project-prod.iam.gserviceaccount.com"
      }
    }
  }

  env_config = can(local.environments[local.environment]) ? local.environments[local.environment] : error(
    format(
      "No Terragrunt environment configuration found for '%s'. Ensure the directory name matches an entry in locals.environments.",
      local.environment
    )
  )

  labels = merge(
    { env = local.environment },
    lookup(local.env_config, "labels", {})
  )
}

# Shared Terraform + provider config for all stacks that include this root
generate "versions" {
  path      = "versions.tf"
  if_exists = "overwrite"
  contents  = <<-EOF
  terraform {
    required_version = "= 1.12.2"

    required_providers {
      google = {
        source  = "hashicorp/google"
        version = "~> 6.42.0"
      }
    }
  }
  EOF
}

generate "provider" {
  path      = "providers.tf"
  if_exists = "overwrite"
  contents  = <<-EOF
  provider "google" {
    project = "${local.env_config.project}"
    region  = "${local.env_config.region}"
  }
  EOF
}
