include "root" {
  path = find_in_parent_folders("root.hcl")
  expose = true
}

locals {
  modules_repo_base = get_env(
    "TF_MODULES_REPO_BASE",
    "ssh://git@github.com/olivierbenard/gcp-terraform-modules.git"
  )
  
  environment = include.root.locals.environment
  env_config  = include.root.locals.env_config

  # name of the current stack folder, e.g. "cloud-function-A", "cloud-function-B", ...
  stack_name = basename(get_terragrunt_dir())

  # directory where YAML configs live, relative to this terragrunt.hcl
  config_dir = "${get_terragrunt_dir()}/../../config"

  # read the YAML configuration file, <stack_name>.<environment>.yaml
  cfg = yamldecode(
    file("${local.config_dir}/${local.stack_name}.${local.environment}.yaml")
  )

  defaults = local.cfg.defaults
  fn       = local.cfg.function

  # Merge env vars & labels
  env_vars = merge(
    lookup(local.defaults, "environment_variables", {}),
    lookup(local.fn, "environment_variables", {})
  )

  secret_env_vars = concat(
    lookup(local.defaults, "secret_env_vars", []),
    lookup(local.fn, "secret_env_vars", [])
  )

  labels = merge(
    lookup(local.defaults, "labels", {}),
    local.env_config.labels
  )

  scheduler_cfg = lookup(local.env_config, "scheduler", {})
  scheduler_defaults = lookup(local.defaults, "scheduler", {})

  schedules = [
    for s in lookup(local.fn, "schedules", []) : {
      name             = s.name
      cron             = s.cron
      timezone         = try(s.timezone, "")
      paused           = try(s.paused, false)
      http_method      = try(s.http_method, "")
      attempt_deadline = try(s.attempt_deadline, "")
      payload          = try(s.payload, {})
      raw_body         = try(s.raw_body, "")
      headers          = try(s.headers, {})
    }
  ]
}

terraform {
  source = "git::${local.modules_repo_base}//cloud_function_http?ref=main"
}

remote_state {
  backend = "gcs"

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }

  config = {
    bucket = local.env_config.state_bucket
    prefix = "state/${local.environment}/cloud-function/${local.fn.name}"
  }
}

inputs = {
  project      = local.env_config.project
  region       = local.env_config.region
  service_name = local.fn.name

  source_bucket = local.fn.storage_source.bucket
  source_object = local.fn.storage_source.object

  runtime        = coalesce(try(local.fn.runtime, null), local.defaults.runtime)
  entry_point    = coalesce(try(local.fn.entry_point, null), local.defaults.entry_point)
  available_cpu  = coalesce(try(local.fn.available_cpu, null), local.defaults.available_cpu)
  memory         = coalesce(try(local.fn.memory, null), local.defaults.memory)
  timeout_seconds  = coalesce(try(local.fn.timeout_seconds, null), local.defaults.timeout_seconds)
  ingress_settings = coalesce(try(local.fn.ingress_settings, null), local.defaults.ingress_settings)

  min_instance_count = coalesce(try(local.fn.min_instances, null), local.defaults.min_instances)
  max_instance_count = coalesce(try(local.fn.max_instances, null), local.defaults.max_instances)

  environment_variables = local.env_vars
  secret_env_vars       = local.secret_env_vars

  labels = local.labels

  # SA: create or reuse
  service_account_email    = try(local.fn.service_account_email, null)
  cf_service_account_roles = lookup(local.defaults, "cf_service_account_roles", [])

  extra_invokers = []

  scheduler_region = coalesce(
    try(local.scheduler_defaults.region, null),
    local.scheduler_cfg.region
  )

  scheduler_service_account_email = coalesce(
    try(local.scheduler_defaults.service_account_email, null),
    local.scheduler_cfg.service_account_email
  )

  default_schedule_timezone         = coalesce(try(local.scheduler_defaults.timezone, null), "Europe/Berlin")
  default_schedule_http_method      = coalesce(try(local.scheduler_defaults.http_method, null), "POST")
  default_schedule_attempt_deadline = coalesce(try(local.scheduler_defaults.attempt_deadline, null), "60s")
  default_schedule_headers          = lookup(local.scheduler_defaults, "headers", { "Content-Type" = "application/json" })

  schedules = local.schedules
}
