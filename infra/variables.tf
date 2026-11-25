variable "aws_account_id" {
  description = "Expected deployment account; the provider refuses a different account."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "Set aws_account_id to your 12-digit AWS account ID."
  }
}

variable "aws_region" {
  description = "AWS region for the S3 origin. CloudFront is global."
  type        = string
  default     = "us-east-1"
}

variable "site_owner" {
  description = "Name to display on the public website."
  type        = string

  validation {
    condition     = length(trimspace(var.site_owner)) > 0 && length(var.site_owner) <= 100
    error_message = "Set site_owner to a non-empty name of at most 100 characters."
  }
}
