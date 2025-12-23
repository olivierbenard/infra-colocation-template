include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

locals {

  modules_repo_base = get_env(
    "TF_MODULES_REPO_BASE",
    "ssh://git@github.com/olivierbenard/gcp-terraform-modules.git"
  )
  # this comes from root.hcl:
  environment = include.root.locals.environment
  env_config  = include.root.locals.env_config

  # name of the current stack folder, e.g. "bucket", "bucket-primary", "bucket-logs", ...
  stack_name = basename(get_terragrunt_dir())

  # directory where YAML configs live, relative to this terragrunt.hcl
  config_dir = "${get_terragrunt_dir()}/../../config"

  # read the YAML configuration file, <stack_name>.<environment>.yaml
  cfg = yamldecode(
    file("${local.config_dir}/${local.stack_name}.${local.environment}.yaml")
  )

  defaults = lookup(local.cfg, "defaults", {})
  bucket   = lookup(local.cfg, "bucket", {})

  # merge env-specific labels from root + defaults.labels + bucket.labels (if any)
  labels = merge(
    lookup(local.defaults, "labels", {}),
    lookup(local.env_config, "labels", {}),
    lookup(local.bucket, "labels", {})
  )

  lifecycle_rules = lookup(local.bucket, "lifecycle_rules", [])
}

terraform {
  source = "git::${local.modules_repo_base}//bucket?ref=main"
}

remote_state {
  backend = "gcs"

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }

  config = {
    bucket = local.env_config.state_bucket
    prefix = "state/${local.environment}/bucket/${local.bucket.name}"
  }
}

inputs = {
  project = local.env_config.project

  # Bucket name & location
  name     = local.bucket.name
  location = coalesce(
    try(local.bucket.location, null),
    try(local.defaults.location, null),
    "EU"
  )

  storage_class = coalesce(
    try(local.bucket.storage_class, null),
    try(local.defaults.storage_class, null),
    "STANDARD"
  )

  labels = local.labels

  versioning = try(local.bucket.versioning, false)

  uniform_bucket_level_access = coalesce(
    try(local.bucket.uniform_bucket_level_access, null),
    try(local.defaults.uniform_bucket_level_access, null),
    true
  )

  lifecycle_rules = local.lifecycle_rules
}
