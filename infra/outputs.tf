output "website_url" {
  description = "Public HTTPS URL."
  value       = "https://${aws_cloudfront_distribution.site.domain_name}"
}

output "distribution_id" {
  description = "Distribution identifier, for status checks or cache invalidation."
  value       = aws_cloudfront_distribution.site.id
}

output "origin_object_url" {
  description = "Direct S3 URL; anonymous requests should return 403."
  value       = "https://${aws_s3_bucket.site.bucket_regional_domain_name}/${aws_s3_object.index.key}"
}
