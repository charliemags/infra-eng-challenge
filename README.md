# infra-eng-challenge

A static website on AWS, provisioned with Terraform.

**[Live website](https://d2bgkazvb3wnbb.cloudfront.net)** · [CI](https://github.com/charliemags/infra-eng-challenge/actions/workflows/terraform.yml)

`Browser → CloudFront (HTTPS) → private S3 bucket`

S3 stores the HTML page. CloudFront provides HTTPS and reads S3 through Origin
Access Control (OAC). Public S3 access stays blocked. Terraform manages both the
infrastructure and page, with no servers to maintain.

## Deploy

You need Terraform 1.10 or later (v1.x), AWS CLI 2.32+, Git, curl, and a non-root AWS profile
with S3 and CloudFront management permissions. Use temporary credentials.
The [policy example](infra/deployment-policy.example.json) contains a placeholder
account ID; review its CloudFront creation wildcards and narrow management access
to the created resources after deployment.

```sh
git clone https://github.com/charliemags/infra-eng-challenge.git
cd infra-eng-challenge

# Sign in using your usual method; for console-based access:
aws login --profile your-profile
export AWS_PROFILE=your-profile
aws sts get-caller-identity

cp infra/terraform.tfvars.example infra/terraform.tfvars
```

Set `aws_account_id` in `infra/terraform.tfvars` to the account returned above.
The example sets `site_owner` to Charlie Magnarelli and `aws_region` to `us-east-1`.
Bucket names receive a unique suffix automatically.

```sh
terraform -chdir=infra init
terraform -chdir=infra fmt -check
terraform -chdir=infra validate
terraform -chdir=infra plan -out=tfplan
```

Review the plan: a fresh deployment should add ten resources. Then apply it:

```sh
terraform -chdir=infra apply tfplan
terraform -chdir=infra output -raw website_url
```

CloudFront takes a few minutes to deploy. Preserve local Terraform state;
inputs, plans, and state are ignored by Git. The provider lock file is committed.

## Verify

```sh
site_url="$(terraform -chdir=infra output -raw website_url)"
origin_url="$(terraform -chdir=infra output -raw origin_object_url)"

curl --fail "$site_url"
curl --head "$site_url"
curl --head "http://${site_url#https://}"
curl --silent --output /dev/null --write-out '%{http_code}\n' "$origin_url"
terraform -chdir=infra plan -detailed-exitcode
```

Expect your name on the page, HTTPS **200**, HTTP **301**, direct S3 **403**, and
no Terraform changes (exit 0). Headers should include CSP, HSTS,
X-Frame-Options, and X-Content-Type-Options.

These checks passed on November 24, 2026 with Terraform 1.17.2 and AWS provider
6.74.0. The page also opened in Firefox. A clean checkout passed initialization,
validation, and planning. CI runs formatting and validation without AWS credentials.

## Update and clean up

Edit `site/index.html.tftpl` or `site_owner`, then plan and apply again.
The page has a 60-second cache lifetime.

```sh
terraform -chdir=infra plan -destroy -out=destroy.tfplan
terraform -chdir=infra apply destroy.tfplan
```

The cleanup plan was reviewed but not applied; the site remains live for
assessment. Keep state until cleanup finishes. Operator IAM access is managed
separately. S3 and CloudFront usage can incur charges; free-tier coverage is not
assumed. See [S3 pricing](https://aws.amazon.com/s3/pricing/) and
[CloudFront pricing](https://aws.amazon.com/cloudfront/pricing/).

## Alternatives

- **Public S3 website:** fewer components, but its website endpoint lacks HTTPS
  and cannot use OAC.
- **Amplify Hosting:** useful for frontend builds and previews; unnecessary for
  one HTML file.
- **EC2, ECS, or Kubernetes:** useful for server-side workloads, but add runtime
  maintenance and cost without helping this static page.

## With more time

Test a complete rebuild and destruction in a sandbox. Add secret and IaC scanning
to CI. For a custom domain, provision an ACM certificate in `us-east-1`, validate
DNS, configure the CloudFront alias, and select a stronger viewer TLS policy.

## Production and multiple teams

These are proposed improvements:

- **Ownership:** service owners, CODEOWNERS, short ADRs, and runbooks for clear handoffs.
- **Self-service:** versioned Terraform modules and templates with safe defaults.
- **Isolation and state:** separate environment accounts and roles; encrypted,
  versioned S3 state with locking and serialized applies.
- **Delivery:** OIDC-based CI credentials, reviewed production changes, immutable
  release artifacts, and tested rollback.
- **Operations:** agreed availability and recovery targets, access logs, synthetic
  checks, actionable alerts, retention policies, and recovery exercises.
- **Security and cost:** least privilege, scanning, appropriate WAF/rate limits,
  ownership tags, budgets, and cost alerts.

The exercise uses local state, manual deployment, and one regional origin.

## AI use

Codex helped brainstorm the approach, draft Terraform and this README, deploy,
and verify the result. The goals were simplicity, reproducibility, and secure
defaults. Generated IAM permissions needed narrowing, and Linux CI caught a
provider-checksum issue missed by local checks.

My feedback:

> it was a great brainstormer but ultimately up to the engineer (me) to make decisions on direction.
