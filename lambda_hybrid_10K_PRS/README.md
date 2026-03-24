# Lambda Hybrid 10K RPS on AWS

This stack is an expanded Terraform implementation of the hybrid serverless architecture shown in the attached diagram.

Implemented request paths:

- sync path: `Route 53 -> CloudFront -> WAF -> API Gateway -> Lambda -> DynamoDB/S3`
- async path: `Route 53 -> CloudFront -> WAF -> API Gateway -> SQS -> Lambda Worker -> DynamoDB/S3`
- resilience path: `SQS -> DLQ`

The edge layer is optional and controlled by variables so the stack can still run without a custom domain.

## What Gets Created

- `API Gateway HTTP API`
- `POST /sync` route for synchronous processing
- `POST /async` route for direct `SQS` enqueueing
- `SQS` queue and `DLQ`
- sync `Lambda`
- async worker `Lambda`
- Lambda aliases and optional provisioned concurrency
- `DynamoDB` request table
- `S3` payload bucket
- `CloudWatch` log groups, alarms, and dashboard
- optional `SNS` alarm notifications
- `X-Ray` tracing for both Lambda functions
- `WAF` attached either to CloudFront or directly to API Gateway
- optional `CloudFront` distribution
- optional `CloudFront` access log bucket
- optional `WAF` log groups
- optional `Route 53` alias and `ACM` certificate for the edge domain
- optional `CodePipeline` plus `CodeBuild` packaging path for `SAM/CloudFormation`

## Structure

- `versions.tf` - Terraform and provider versions
- `providers.tf` - AWS providers, including `us-east-1` for edge resources
- `variables.tf` - stack settings and feature flags
- `locals.tf` - shared naming and tags
- `main.tf` - infrastructure resources
- `outputs.tf` - API, edge, observability, and CI/CD outputs
- `terraform.tfvars.example` - example variables
- `src/sync_handler.py` - sync Lambda sample with idempotent writes
- `src/worker_handler.py` - async worker Lambda sample with idempotent writes
- `sam/template.yaml` - optional SAM template used by the CI/CD scaffold
- `sam/buildspec.yml` - CodeBuild packaging steps for the SAM deployment path
- `scheme/` - architecture image

## Architecture Notes

### Edge layer

When `enable_edge_layer = true`, the stack creates:

- `CloudFront` in front of the HTTP API
- optional `ACM` certificate in `us-east-1`
- optional `Route 53` alias for a custom domain
- `WAF` attached to CloudFront

When the edge layer is disabled, the stack can still attach a regional `WAF` directly to the API stage.

### Observability

The stack now includes:

- Lambda log groups
- API Gateway access logs
- Lambda `X-Ray` tracing
- optional CloudFront access logs
- optional WAF logs to CloudWatch Logs
- alarms for Lambda errors, Lambda throttles, API `5xx`, and DLQ depth
- optional SNS alarm notifications
- a CloudWatch dashboard with API, Lambda, and SQS widgets

### Concurrency and throttling

The stack now includes:

- API Gateway default route throttling
- reserved concurrency for sync and worker Lambdas
- optional provisioned concurrency through Lambda aliases
- SQS batch controls for the worker Lambda

### Idempotency

Both sample Lambda handlers now use DynamoDB conditional writes to claim a `request_id` before processing. This prevents duplicate processing for repeated requests or SQS redelivery of already completed items.

## Quick Start

1. Go to the stack folder:

```bash
cd lambda_hybrid_10K_PRS
```

2. Create a variables file:

```bash
cp terraform.tfvars.example terraform.tfvars
```

3. Adjust values in `terraform.tfvars`.

4. If you want the full edge layer, set at least:

```hcl
enable_edge_layer = true
route53_zone_name = "example.com"
edge_domain_name  = "api.example.com"
```

5. For CI/CD, set real repository connection values before apply:

```hcl
cicd_enabled        = true
cicd_connection_arn = "arn:aws:codestar-connections:eu-central-1:111111111111:connection/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
cicd_repository_id  = "owner/repository"
```

6. Initialize and apply:

```bash
terraform init
terraform fmt -recursive
terraform plan
terraform apply
```

## Invocation Examples

After `apply`, Terraform outputs:

- `sync_invoke_url`
- `async_invoke_url`
- `edge_url` when the edge layer is enabled

Synchronous request:

```bash
curl -X POST "$SYNC_URL" \
  -H "content-type: application/json" \
  -d '{"request_id":"sync-001","type":"sync","payload":{"hello":"world"}}'
```

Asynchronous request:

```bash
curl -X POST "$ASYNC_URL" \
  -H "content-type: application/json" \
  -d '{"request_id":"async-001","type":"async","payload":{"hello":"queue"}}'
```

## CI/CD Scaffold

The stack includes an optional CI/CD layer controlled by `cicd_enabled`.

When enabled, Terraform creates:

- an artifact `S3` bucket
- an IAM role for CodePipeline
- an IAM role for CodeBuild
- a `CodeBuild` project that runs `sam build` and `sam package`
- a `CodePipeline` with:
  - source stage using `CodeStarSourceConnection`
  - build stage using `CodeBuild`
  - deploy stage using `CloudFormation`
  - `sam/template.yaml` as the application template
  - `sam/buildspec.yml` as the packaging instructions

This scaffold is disabled by default because it requires external repository connection details.

## Important Notes

- `CloudFront`, `Route 53`, and `ACM` are optional because they require domain ownership and DNS setup.
- `CloudFront` certificates for custom domains must be issued in `us-east-1`.
- The example `terraform.tfvars.example` intentionally enables edge and CI/CD using placeholder values. Replace them before use.
- Provisioned concurrency should be kept lower than or equal to reserved concurrency for each Lambda.
- The sample handlers implement idempotency using `request_id`; clients should send a stable `request_id` for best results.
- CloudFront access logging and WAF logging are optional but recommended for a production edge deployment.

## Remaining Gaps

This stack is much closer to the target diagram, but there are still practical production items you may want to add depending on your environment:

- custom error responses and stricter cache policies
- KMS for DynamoDB, S3, and SQS customer-managed encryption
- pager or incident routing beyond email and SNS
- load testing and capacity validation for your exact traffic profile