TF_DIR = infra
ENV ?= dev
TF_BIN ?= terraform

.PHONY: all
all: run

.PHONY: run
run:
	poetry run functions-framework --target=main --source=src/main.py --port=8080 --debug

.PHONY: curl-test
curl-test:
	curl -X POST "http://localhost:8080" \
	-H "Content-Type: application/json" \
	-d '{"env": "test"}'

.PHONY: ruff-fmt
ruff-fmt:
	poetry run ruff format src/

.PHONY: ruff-check
ruff-check:
	poetry run ruff check --select I --fix

.PHONY: mypy
mypy:
	poetry run mypy src/

.PHONY: pylint
pylint:
	poetry run pylint src/

.PHONY: tests
tests:
	poetry run pytest -m "not integration" -vvs tests/

.PHONY: test-smokes
test-smokes:
	poetry run pytest -m "integration" -vvs tests/

.PHONY: tests-all
tests-all:
	poetry run pytest -vvs tests/

.PHONY: fmt
fmt: ruff-fmt tf-fmt

.PHONY: checks
checks: ruff-check mypy pylint tests tf-check tf-validate clean

.PHONY: requirements
requirements:
	echo "--extra-index-url https://europe-west4-python.pkg.dev/PROJECT-prod/ORGANISATION-libs/simple/" > requirements.txt && \
	poetry export -f requirements.txt --without-hashes --only main -o requirements.txt

# to run once per clone
.PHONY: pre-commit-install
pre-commit-install:
	poetry run pre-commit install

# to run the pre-commit on demand
.PHONY: pre-commit-run
pre-commit-run:
	poetry run pre-commit run --all-files --hook-stage manual

# format all terraform files in this repo (in-place)
.PHONY: tf-fmt
tf-fmt:
	@echo "Running terraform fmt (recursive)"
	@$(TF_BIN) fmt --recursive=true --check=true -list=false

# check that all terraform files are already formatted (no changes)
.PHONY: tf-check
tf-check:
	@echo "Checking terraform formatting (terraform fmt -recursive -check)"
	@$(TF_BIN) fmt --recursive=true --check=true -list=false

# validate all terraform modules (init -backend=false + validate)
.PHONY: tf-validate
tf-validate:
	@echo "Validating Terraform modules..."
	@set -e; \
	for dir in $(TF_DIRS); do \
		echo "  -> $$dir"; \
		cd $$dir; \
		$(TF_BIN) init -backend=false -input=false >/dev/null 2>&1 || exit $$?; \
		$(TF_BIN) validate -no-color || exit $$?; \
		cd - >/dev/null; \
	done
	@$(MAKE) clean
	@echo "All modules validated successfully."

# remove .terraform dirs and .terraform.lock.hcl files
.PHONY: clean
clean:
	@echo "Cleaning Terraform temp files (.terraform/, .terraform.lock.hcl)..."
	@find . -name '.terraform' -type d -prune -exec rm -rf {} + || true
	@find . -name '.terraform.lock.hcl' -type f -delete || true
	@find -type d -name ".virtualenv" -exec rm -rf {} +
	@find -type d -name "__pycache__" -exec rm -rf {} +
	@find -type d -name ".ruff_cache" -exec rm -rf {} +
	@echo "Cleanup done."

# Infrastructure 
infra-init-dev:
	cd infra/dev && terragrunt run --all init

infra-plan-dev:
	cd infra/dev && terragrunt run --all plan

infra-apply-dev:
	cd infra/dev && terragrunt run --all apply

infra-output-dev:
	cd infra/dev && terragrunt run --all output

# Environment variables
ENV ?= dev
FUNCTION ?= src
ZIP_NAME ?= pilot-cf-colocation-infra.zip

# Derived environment variables
PROJECT_ID := project-$(ENV)
GCS_BUCKET := cloud-functions-artifacts-$(ENV)
PACKAGE_DIRECTORY := $(FUNCTION)/package
SOURCE_DIRECTORY := $(FUNCTION)

.PHONY: zip
zip:
	@echo "Zipping Cloud Function: $(FUNCTION)..."
	@cd $(FUNCTION) && \
	rm -rf package/ && \
	mkdir -p package/ && \
	rsync -av \
		--exclude=package \
		--exclude='*.zip' \
		--exclude='.*/' \
		--exclude='.*' \
		--exclude='*.json' \
		--exclude=poetry.lock \
		--exclude=pyproject.toml \
		--exclude=__pycache__/ \
		--exclude=Makefile \
		. package/ && \
	cd package/ && \
	zip -r ../$(ZIP_NAME) . && \
	cd .. && \
	rm -rf package/
	@echo "✅ Zipped Cloud Function to: $(ZIP_NAME)"

.PHONY: upload
upload: zip
	@echo "☁️  Uploading to Google Cloud Storage project: $(PROJECT_ID)"
	gcloud config set project $(PROJECT_ID)
	@echo "☁️  Uploading to Google Cloud Storage: gs://$(GCS_BUCKET)/$(ZIP_NAME)..."
	gsutil cp $(FUNCTION)/$(ZIP_NAME) gs://$(GCS_BUCKET)/$(ZIP_NAME)
	@echo "✅ Upload complete"
	$(MAKE) clean-python

.PHONY: clean-python
clean-python:
	find -type d -name "package" -exec rm -rf {} +
	find -type d -name "__pycache__" -exec rm -rf {} +
	find -type d -name ".ruff_cache" -exec rm -rf {} +
	find -type d -name ".virtualenv" -exec rm -rf {} +
	find -type d -name ".venv" -exec rm -rf {} +
	find -type f -name "*.zip" -exec rm -f {} +
	@echo "✅ Cleaned up package directories and zip file(s)"
