# Pilot CF Colocation Infra - Cloud Infrastructure & Deployment Guide

This pilot project illustrates a modern, simple, predictable and scalable approach for building and deploying cloud services in your organisation using Terragrunt on top of Terraform.  
It is intentionally written to be fully understandable by **non-technical stakeholders** while remaining highly practical and detailed for **engineers**.  

## What This Template Does

This project shows how to reliably deploy cloud resources—such as Cloud Functions, Cloud Run services, buckets, Pub/Sub topics, and scheduled jobs—using:
- **Terraform** (to define infrastructure as code)
- **Terragrunt** (to simplify, structure, and automate Terraform)
- **YAML recipes** (human‑friendly configuration files)

Infrastructure modules (the terraform parts) are maintained in a separate repository.  
This repository exposes terraform **resources** (an _atomic unit_ of terraform which directly represents one real object in the cloud and not re-usable on its own) as reusable **modules** (a package of resources i.e. a reusable, parametrized template) and **wrappers** (composed modules tailored for specific patterns):
* https://github.com/olivierbenard/gcp-terraform-modules

The goal is to:
* Minimize cognitive load for developers onboarding a new cloud service.
* Standardize cloud deployments across teams and team members.
* Make infrastructure understandable to non-engineers.
* Support future automation and CI/CD integration.

In other words, most services depend on one or more cloud components (Cloud Functions, Cloud Run services, Pub/Sub topics, GCS buckets, Cloud Scheduler jobs, etc.).  

This template enables developers to instantiate these resources effortlessly through:
* a consistent, DRY folder structure;
* environment-aware Terragrunt stacks;
* and YAML "recipes" that ergonomically describe resource configuration.

Together, these conventions make it straightforward to add new cloud resources, keep environments uniform, and maintain infrastructure-as-code that is predictable, auditable, and developer-friendly.

## How to Use This Template

Whether you're a developer or not, this repository helps you understand:

- **What the service does**
- **Which cloud resources it uses**
- **How to deploy or update it**

For engineers, it also provides:

- **Predictable environment separation**: `infra/dev` and `infra/prod` mirror each other for a clean separation of deployments.
- **Declarative YAML resource definitions for config-driven infrastructure:** service behaviour is defined in YAML (`cloud-function.dev.yaml`, `bucket.dev.yaml`, etc.).
- **Reusable Terragrunt stacks infra recipes**: i.e. standard Terragrunt wrappers for Cloud Functions, GCS buckets, schedulers, Pub/Sub topics, etc. based on standard modules and terraform wrappers shared across the company.
- **Minimal boilerplate**: when adding a new cloud resource, only create a small folder with `infra/<env>/<resource_name>/terragrunt.hcl` + YAML.
- **Easy in-team onboarding**: consistent patterns across all service repos to reduce the cognitive load.

It therefore provides a clean layout ready for automation.

## Repository Structure Overview

This repository uses a clear, predictable structure designed to be understandable for **non‑technical** readers/observers while remaining powerful and efficient for **experienced engineers**. Users can quickly see where everything lives.  

### Example 1: 1 Service Using 1 Cloud Function and 1 GCS Bucket

This is the _happy path_, where 1 repo = 1 service = 1 CF.  

```
.
├── infra/
│   ├── root.hcl
│   │   Shared environment logic (project IDs, regions, labels, env detection).
│   │   This file stays the same across all services and enforces consistency.
│   │
│   ├── config/
│   │   YAML "recipes" describing cloud resources for each environment.
│   │   These files keep infrastructure human-readable and reduce Terraform complexity.
│   │
│   │   ├── cloud-function.dev.yaml     # Cloud Function definition for DEV
│   │   ├── cloud-function.prod.yaml    # Cloud Function definition for PROD
│   │   ├── bucket.dev.yaml             # Bucket definition for DEV
│   │   └── bucket.prod.yaml            # Bucket definition for PROD
│   │
│   ├── dev/
│   │   Infrastructure stacks for the DEV environment.
│   │   Each resource (function, bucket, topic…) gets its own folder.
│   │
│   │   ├── cloud-function/             # Cloud Function stack (DEV)
│   │   │   └── terragrunt.hcl          # Terragrunt wrapper using the CF recipe
│   │   │
│   │   └── bucket/                     # Bucket stack (DEV)
│   │       └── terragrunt.hcl          # Terragrunt wrapper using the bucket recipe
│   │
│   └── prod/
│       Infrastructure stacks for the PROD environment.
│       Mirrors the structure of the DEV environment for consistency.
│
│       ├── cloud-function/             # Cloud Function stack (PROD)
│       │   └── terragrunt.hcl
│       │
│       └── bucket/                     # Bucket stack (PROD)
│           └── terragrunt.hcl
│
├── src/
│   Source code for the service (Python, Go, Node...).  
│   Only business logic lives here.
│
├── tests/
│   Automated tests.
│
├── Makefile
│   Developer shortcuts: deploy, plan, destroy...
│
└── README.md
```

### For non‑technical readers

- **`infra/`:** The folder containing everything related to cloud infrastructure.  
- **`root.hcl`:** The "common rules" all environments use (think of it as shared settings - e.g. default environment variables to configure terragrunt are defined here).  
- **`config/`:** Simple YAML files describing what each cloud resource should look like. Can overwrite the `root.hcl` default environment variables values when colliding. No deep technical knowledge required.  
- **`dev/`** & **`prod/`:** two environments:  
  - *`dev`* = test/sandbox  
  - *`prod`* = live/production  
- Each cloud resource (e.g. a Cloud Function or a bucket) has its **own small folder**, making the setup clean and easy to understand.

Then, Terragrunt/Terraform take the YAML description and **build the actual infrastructure** in Google Cloud.  

### For technical users

- Terragrunt uses `root.hcl` to derive environment, project, region, and shared provider settings.  
- Each resource folder under `dev/` or `prod/` is a **self‑contained Terragrunt stack** pointing to a Terraform module.  
- `config/*.yaml` acts as a declarative configuration interface — meaning:  
  - stacks remain extremely lightweight,  
  - resource definitions stay DRY and easy to diff,  
  - modules receive a clean, structured input layer.  
- The folder layout enables atomic stacks, consistent run‑all plans, and safe parallel operations.

### Example 2: 1 Service Using 2 Cloud Functions

This is the case when a repo contains one **business service**, but that service is implemented with **two cloud functions**:
* `public-api` - HTTP CF exposed to the outside world
* `worker` - background CF triggered by a scheduler or Pub/Sub

```
.
├── infra/
│   ├── root.hcl
│   ├── config/
│   │   ├── public-api.dev.yaml        # Cloud Function "public-api" (DEV)
│   │   ├── public-api.prod.yaml       # Cloud Function "public-api" (PROD)
│   │   ├── worker.dev.yaml            # Cloud Function "worker" (DEV)
│   │   ├── worker.prod.yaml           # Cloud Function "worker" (PROD)
│   │   ├── bucket.dev.yaml            # Example shared bucket (DEV)
│   │   └── bucket.prod.yaml           # Example shared bucket (PROD)
│   │
│   ├── dev/
│   │   ├── public-api/                # Cloud Function "public-api" stack (DEV)
│   │   │   └── terragrunt.hcl
│   │   │
│   │   ├── worker/                    # Cloud Function "worker" stack (DEV)
│   │   │   └── terragrunt.hcl
│   │   │
│   │   └── bucket/                    # Shared bucket stack (DEV)
│   │       └── terragrunt.hcl
│   │
│   └── prod/
│       ├── public-api/                # Cloud Function "public-api" stack (PROD)
│       │   └── terragrunt.hcl
│       │
│       ├── worker/                    # Cloud Function "worker" stack (PROD)
│       │   └── terragrunt.hcl
│       │
│       └── bucket/                    # Shared bucket stack (PROD)
│           └── terragrunt.hcl
...
```

Each building block has its own folder under `infra/dev` and `infra/prod`, but everything still belongs to the same service.  

## Deploying the Service

### 1. Initialize (first time only)

```bash
make infra-init-dev
make infra-init-prod
```

### 2. Plan

```bash
make infra-plan-dev
make infra-plan-prod
```

### 3. Apply

```bash
make infra-apply-dev
make infra-apply-prod
```

Terragrunt uses `run-all`, so all resource stacks (cloud-function, bucket, pubsub, etc.) are deployed in dependency order.

---

## Resource Recipes (Adding New Cloud Objects)

You can instantiate new cloud objects simply by:

1. Creating a config YAML - e.g. `infra/config/bucket.dev.yaml`
2. Creating a `terragrunt.hcl` stack folder - e.g. `infra/dev/bucket/terragrunt.hcl`
3. Reusing the root logic automatically, using `make infra-apply-dev` to create the new stack.

### Example: Creating a New GCS Bucket

#### Step 1 — Create YAML recipes

`infra/config/bucket.dev.yaml`:

```yaml
defaults:
  location: EU
  storage_class: STANDARD
bucket:
  name: service-dev-data
```

`infra/config/bucket.prod.yaml`:

```yaml
defaults:
  location: EU
  storage_class: STANDARD
bucket:
  name: service-prod-data
  versioning: true
```

#### Step 2 — Add a DEV stack

`infra/dev/bucket/terragrunt.hcl`

```hcl
include "root" {
  path = find_in_parent_folders("root.hcl")
  expose = true
}

locals {
  environment = include.root.locals.environment
  cfg = yamldecode(file("${get_parent_terragrunt_dir()}/../config/bucket.${local.environment}.yaml"))
  defaults = local.cfg.defaults
  bucket   = local.cfg.bucket
}

terraform {
  source = "git::https://github.com/olivierbenard/gcp-terraform-modules.git//bucket?ref=main"
}

inputs = {
  project  = include.root.locals.env_config.project
  name     = local.bucket.name
  location = local.defaults.location
}
```

Do the same under `infra/prod/bucket/`.

#### Step 3 — Apply

```bash
make infra-apply-dev
```

Done! Bucket exists.

### Example: Creating a new Cloud Function using YAML

The existing CF module supports:

- env vars
- secret env vars
- scheduler triggers
- CPU/memory/timeouts
- labels
- min/max instances
- custom service account

All configurable via YAML:

```yaml
function:
  name: invoice-processor
  entry_point: main
  storage_source:
    bucket: functions-artifacts-dev
    object: invoice-processor.zip
  env_vars:
    ENV: dev
  secret_env_vars:
    - key: API_TOKEN
      secret: api-token
      project_id: project-dev
      version: latest
  schedules:
    - name: nightly
      cron: "0 2 * * *"
```

And wired in a minimal Terragrunt:

```hcl
terraform {
  source = "git::https://github.com/olivierbenard/gcp-terraform-modules.git//cloud_function_http?ref=main"
}
```

Terragrunt passes all YAML fields into the Terraform module.

## Add any other resource type easily

Prior the condition that the modules are exposed in the [gcp-terraform-modules](https://github.com/olivierbenard/gcp-terraform-modules) repo, this pattern supports adding:

### Pub/Sub Topic

```
infra/dev/topic/terragrunt.hcl
infra/config/topic.dev.yaml
infra/config/topic.prod.yaml
```

### Cloud Scheduler

Scheduler jobs are automatically deployed by the cloud-function module if `schedules:` are defined inside the YAML.

### Cloud Run

If you create a stack:

```
infra/dev/cloud-run/
  terragrunt.hcl
```

and point it to a Cloud Run module, everything else (project/region/state bucket/env detection/labels) is inherited automatically.

# CI/CD Ready

This structure is compatible with:

- GitHub Actions  
- GitLab CI  
- Cloud Build  

Triggers can easily run:

```
make infra-plan-dev
make infra-apply-dev
```

and use the generated state bucket automatically.

## Why This Structure Works

- **Reproducible** across repos  
- **Predictable**: every stack derives environment from folder prefix (`dev/*` or `prod/*`)
- **Extensible**: adding resources = adding small `terragrunt.hcl` file recipes across folders + YAML  
- **No duplication** due to central `root.hcl`
- **Human-friendly**: infra changes live in version control, diffable, code-reviewed
- **Low cognitive load**: developers only edit YAML + minimal Terragrunt

## Conventions

- Environment folders: `infra/dev`, `infra/prod`
- One stack per cloud object type under each env
- YAML drives behaviour; `terragrunt.hcl` is just glue
- Secret Manager access is handled through:
  - per-function SA permissions  
  - `cf_service_account_roles` in YAML  

## Usage Workflow for Developers

Example of the single Cloud Function business case:

1. Edit Cloud Function code under `/src`.
2. Update YAML config under `/infra/config`.
3. Upload new CF zip (CI or manual).
4. Run:
   ```bash
   make infra-plan-dev
   make infra-apply-dev
   ```
5. Deploy to prod when validated:
   ```bash
   make infra-plan-prod
   make infra-apply-prod
   ```

## Conclusion

With this template:

- New services can be created in minutes  
- New cloud resources can be added safely and declaratively  
- Environments remain consistent and predictable  
- Terragrunt does all the heavy lifting  

You now have:

- A predictable folder structure  
- Reproducible infrastructure deployments  
- A YAML-driven configuration model  
- An extendable template  
- Support for any Terraform module from the Organisation catalogue  
  