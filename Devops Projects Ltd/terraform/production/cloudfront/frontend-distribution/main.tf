
module "cloudfront" {
  source  = "terraform-aws-modules/cloudfront/aws"
  version = "6.7.1"

 

  # --------------------------------------------------
  # Distribution settings
  # --------------------------------------------------
  aliases = ["sayem.xyz"]

  comment         = "CloudFront for React frontend"
  enabled         = true
  http_version    = "http2and3"
  is_ipv6_enabled = true
  price_class     = "PriceClass_All"

  default_root_object = "index.html"

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
  # S3 Origin Access Control
  # শুধু CloudFront private frontend bucket পড়তে পারবে।
  # দুই bucket এর policy তে প্রতিটি distribution এর ARN অনুমোদন করতে হবে।
  # --------------------------------------------------

  origin_access_control = {
    s3 = {
      description      = "CloudFront access to React frontend"
      origin_type      = "s3"
      signing_behavior = "always"
      signing_protocol = "sigv4"
    }
  }

 

  # --------------------------------------------------
  # Origins
  # --------------------------------------------------
  origin = {
    # React frontend: private S3 bucket
    s3 = {
      origin_id                 = "s3"
      domain_name               = module.frontend_bucket.s3_bucket_bucket_regional_domain_name
      origin_access_control_key = "s3"
    }

    # Backup React frontend
    s3_backup = {
      origin_id                 = "s3-backup"
      domain_name               = module.frontend_backup_bucket.s3_bucket_bucket_regional_domain_name
      origin_access_control_key = "s3"
    }

    
  }

  # S3 Origin Failover
  # Primary: s3
  # Secondary: s3-backup
  # --------------------------------------------------
  origin_group = {
    frontend_failover = {
      origin_id = "frontend-origin-group"

      failover_criteria = {
        status_codes = [
          403,
          404,
          500,
          502,
          503,
          504
        ]
      }

      member = [
        {
          origin_id = "s3"
        },
        {
          origin_id = "s3-backup"
        }
      ]
    }
  }

  # ==================================================
  # CloudFront Function: React SPA URL rewrite
  # ==================================================
  cloudfront_functions = {
    spa-route-rewrite = {
      runtime = "cloudfront-js-2.0"
      comment = "Rewrite React SPA routes to index.html"
      code    = file("${path.module}/functions/spa-route-rewrite.js")
      publish = true
    }
  }



  # --------------------------------------------------
  # Default behavior: React frontend from S3
  # --------------------------------------------------
  default_cache_behavior = {
    target_origin_id       = "frontend-origin-group"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = [
      "GET",
      "HEAD",
      "OPTIONS"
    ]

    cached_methods = [
      "GET",
      "HEAD"
    ]

    compress             = true

    # Cache static frontend content
    cache_policy_name = "Managed-CachingOptimized"


    # Security response headers
    response_headers_policy_id = "67f7725c-6f97-4210-82d7-5512b31e9d03"

    function_association = {
      viewer-request = {
        function_key = "spa-route-rewrite"
      }
    }
  }

  # --------------------------------------------------
  # API behavior: /api/* -> Internal ALB -> EKS
  # --------------------------------------------------
  ordered_cache_behavior = [
   

    {
      # ----------------------------------------------
      # Static assets
      # ----------------------------------------------
      path_pattern           = "/static/*"
      target_origin_id       = "s3"
      viewer_protocol_policy = "redirect-to-https"
      allowed_methods = [
        "GET",
        "HEAD",
        "OPTIONS"
      ]
      cached_methods       = ["GET", "HEAD"]
      compress             = true      
      cache_policy_name    = "Managed-CachingOptimized"
     
    },

     {
      path_pattern           = "/assets/*"
      target_origin_id       = "s3"
      viewer_protocol_policy = "redirect-to-https"

      allowed_methods = ["GET", "HEAD", "OPTIONS"]
      cached_methods  = ["GET", "HEAD"]
      compress        = true

      cache_policy_name = "Managed-CachingOptimized"
    }
  ]



  # --------------------------------------------------
  # CloudFront standard logging v2
  # --------------------------------------------------
  enable_v2_logging = true

  v2_logging = {
    name = "frontend-cloudfront-logs"

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


 