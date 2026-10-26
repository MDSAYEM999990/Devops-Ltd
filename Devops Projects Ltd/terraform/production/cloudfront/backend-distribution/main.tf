
module "cloudfront" {
  source  = "terraform-aws-modules/cloudfront/aws"
  version = "6.7.1"


  # --------------------------------------------------
  # Distribution settings
  # --------------------------------------------------
  aliases = ["api.sayem.xyz"]

  comment         = "CloudFront for Eks internal ALB"
  enabled         = true
  http_version    = "http2and3"
  is_ipv6_enabled = true
  price_class     = "PriceClass_All"
  create_monitoring_subscription = true



  # --------------------------------------------------
  # TLS certificate (ACM অবশ্যই us-east-1 এ থাকতে হবে
  # এবং সব site এর domain কভার করতে হবে)
  # --------------------------------------------------
  viewer_certificate = {
    acm_certificate_arn      = module.acm.acm_certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }


  # Geo restriction: allow all countries
  # Both buckets must allow this distribution through OAC.
  # --------------------------------------------------
  restrictions = {
    geo_restriction = {
      restriction_type = "none"
    }
  }



  # --------------------------------------------------
  # VPC Origin for internal EKS ALB
  # HTTP is retained from your original configuration.
  # Change to https-only after configuring ALB HTTPS
  # listener and a matching certificate.
  # --------------------------------------------------
  vpc_origin = {
    alb = {
      name = "internal-alb-origin"

      arn        = module.alb.arn
      http_port  = 80
      https_port = 443

      # Use HTTP initially unless the ALB origin hostname
      # has a certificate that CloudFront can validate.
      origin_protocol_policy = "http-only"

      origin_ssl_protocols = {
        items    = ["TLSv1.2"]
        quantity = 1
      }

      timeouts = {
        create = "20m"
        update = "20m"
        delete = "20m"
      }
    }
  }

  # --------------------------------------------------
  # Origins
  # --------------------------------------------------
  origin = {
   
    # EKS APIs: internal ALB through CloudFront VPC Origin
    app = {
      origin_id   = "app"
      domain_name = module.alb.dns_name
      vpc_origin_config = {
        vpc_origin_key = "alb"
      }
    }
  }

  # --------------------------------------------------
  # Default behavior: React frontend from S3
  # --------------------------------------------------

default_cache_behavior = {
    target_origin_id       = "app"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = [
      "GET", "HEAD", "OPTIONS",
      "PUT", "POST", "PATCH", "DELETE"
    ]

    cached_methods = ["GET", "HEAD"]
    compress       = true

    cache_policy_name          = "Managed-CachingDisabled"
    origin_request_policy_name = "Managed-AllViewerExceptHostHeader"

    response_headers_policy_id = "67f7725c-6f97-4210-82d7-5512b31e9d03"
  }


  # --------------------------------------------------
  # CloudFront standard logging v2
  # --------------------------------------------------
  enable_v2_logging = true

  v2_logging = {
    name = "API-cloudfront-logs"

    delivery_destination_configuration = {
      destination_resource_arn = "${module.log_bucket.s3_bucket_arn}/cloudfront"
    }

    delivery_destination_type = "S3"
    output_format             = "parquet"

    s3_delivery_configuration = {
      enable_hive_compatible_path = true
      suffix_path                 = "{DistributionId}/{yyyy}/{MM}/{dd}/{HH}"
    }
  }

}


 