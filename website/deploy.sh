#!/bin/bash

# =============================================
# MORTGAGE GUARDIAN WEBSITE DEPLOYMENT SCRIPT
# Deploy to AWS S3 + CloudFront
# =============================================

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DOMAIN_NAME="mortgage-guardian.com"
BUCKET_NAME="mortgage-guardian-website"
CLOUDFRONT_DISTRIBUTION_ID=""
REGION="us-east-1"
PROFILE="default"

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    # Check if AWS CLI is installed
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed. Please install it first."
        exit 1
    fi

    # Check if jq is installed (for JSON parsing)
    if ! command -v jq &> /dev/null; then
        log_warning "jq is not installed. Installing via brew..."
        if command -v brew &> /dev/null; then
            brew install jq
        else
            log_error "Please install jq manually or install Homebrew first."
            exit 1
        fi
    fi

    # Check AWS credentials
    if ! aws sts get-caller-identity --profile $PROFILE &> /dev/null; then
        log_error "AWS credentials not configured. Please run 'aws configure' first."
        exit 1
    fi

    log_success "Prerequisites check passed"
}

# Create S3 bucket for website hosting
create_s3_bucket() {
    log_info "Creating S3 bucket for website hosting..."

    # Check if bucket already exists
    if aws s3api head-bucket --bucket $BUCKET_NAME --profile $PROFILE 2>/dev/null; then
        log_warning "S3 bucket $BUCKET_NAME already exists"
    else
        # Create bucket
        aws s3api create-bucket \
            --bucket $BUCKET_NAME \
            --region $REGION \
            --profile $PROFILE

        log_success "S3 bucket $BUCKET_NAME created"
    fi

    # Disable block public access first
    aws s3api put-public-access-block \
        --bucket $BUCKET_NAME \
        --public-access-block-configuration \
            "BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false" \
        --profile $PROFILE

    # Enable static website hosting
    aws s3api put-bucket-website \
        --bucket $BUCKET_NAME \
        --website-configuration '{
            "IndexDocument": {"Suffix": "index.html"},
            "ErrorDocument": {"Key": "404.html"}
        }' \
        --profile $PROFILE

    # Set bucket policy for public read access
    aws s3api put-bucket-policy \
        --bucket $BUCKET_NAME \
        --policy '{
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Sid": "PublicReadGetObject",
                    "Effect": "Allow",
                    "Principal": "*",
                    "Action": "s3:GetObject",
                    "Resource": "arn:aws:s3:::'"$BUCKET_NAME"'/*"
                }
            ]
        }' \
        --profile $PROFILE

    log_success "S3 bucket configured for static website hosting"
}

# Upload website files to S3
upload_website() {
    log_info "Uploading website files to S3..."

    # Sync files to S3
    aws s3 sync . s3://$BUCKET_NAME \
        --exclude "deploy.sh" \
        --exclude "*.md" \
        --exclude ".git/*" \
        --exclude ".DS_Store" \
        --delete \
        --profile $PROFILE

    # Set cache control headers
    log_info "Setting cache control headers..."

    # CSS and JS files - cache for 1 year
    aws s3 cp s3://$BUCKET_NAME/css/ s3://$BUCKET_NAME/css/ \
        --recursive \
        --metadata-directive REPLACE \
        --cache-control "max-age=31536000, public" \
        --profile $PROFILE

    aws s3 cp s3://$BUCKET_NAME/js/ s3://$BUCKET_NAME/js/ \
        --recursive \
        --metadata-directive REPLACE \
        --cache-control "max-age=31536000, public" \
        --profile $PROFILE

    # Images - cache for 1 week
    aws s3 cp s3://$BUCKET_NAME/assets/ s3://$BUCKET_NAME/assets/ \
        --recursive \
        --metadata-directive REPLACE \
        --cache-control "max-age=604800, public" \
        --profile $PROFILE

    # HTML files - cache for 1 hour
    aws s3 cp s3://$BUCKET_NAME/index.html s3://$BUCKET_NAME/index.html \
        --metadata-directive REPLACE \
        --cache-control "max-age=3600, public" \
        --content-type "text/html" \
        --profile $PROFILE

    log_success "Website files uploaded to S3"
}

# Create CloudFront distribution
create_cloudfront_distribution() {
    log_info "Creating CloudFront distribution..."

    # Check if distribution already exists
    existing_distribution=$(aws cloudfront list-distributions \
        --query "DistributionList.Items[?Comment=='Mortgage Guardian Website'].Id" \
        --output text \
        --profile $PROFILE)

    if [ ! -z "$existing_distribution" ]; then
        log_warning "CloudFront distribution already exists: $existing_distribution"
        CLOUDFRONT_DISTRIBUTION_ID=$existing_distribution
    else
        # Create distribution
        distribution_config='{
            "CallerReference": "mortgage-guardian-'$(date +%s)'",
            "Comment": "Mortgage Guardian Website",
            "DefaultCacheBehavior": {
                "TargetOriginId": "S3-'$BUCKET_NAME'",
                "ViewerProtocolPolicy": "redirect-to-https",
                "TrustedSigners": {
                    "Enabled": false,
                    "Quantity": 0
                },
                "ForwardedValues": {
                    "QueryString": false,
                    "Cookies": {"Forward": "none"}
                },
                "MinTTL": 0,
                "Compress": true
            },
            "Origins": {
                "Quantity": 1,
                "Items": [
                    {
                        "Id": "S3-'$BUCKET_NAME'",
                        "DomainName": "'$BUCKET_NAME'.s3-website-'$REGION'.amazonaws.com",
                        "CustomOriginConfig": {
                            "HTTPPort": 80,
                            "HTTPSPort": 443,
                            "OriginProtocolPolicy": "http-only"
                        }
                    }
                ]
            },
            "Enabled": true,
            "PriceClass": "PriceClass_100",
            "DefaultRootObject": "index.html",
            "CustomErrorResponses": {
                "Quantity": 1,
                "Items": [
                    {
                        "ErrorCode": 404,
                        "ResponsePagePath": "/404.html",
                        "ResponseCode": "404",
                        "ErrorCachingMinTTL": 300
                    }
                ]
            }
        }'

        distribution_result=$(aws cloudfront create-distribution \
            --distribution-config "$distribution_config" \
            --profile $PROFILE)

        CLOUDFRONT_DISTRIBUTION_ID=$(echo $distribution_result | jq -r '.Distribution.Id')

        log_success "CloudFront distribution created: $CLOUDFRONT_DISTRIBUTION_ID"
    fi
}

# Request SSL certificate
request_ssl_certificate() {
    log_info "Requesting SSL certificate..."

    # Check if certificate already exists
    existing_cert=$(aws acm list-certificates \
        --region us-east-1 \
        --query "CertificateSummaryList[?DomainName=='$DOMAIN_NAME'].CertificateArn" \
        --output text \
        --profile $PROFILE)

    if [ ! -z "$existing_cert" ]; then
        log_warning "SSL certificate already exists: $existing_cert"
    else
        # Request certificate
        cert_result=$(aws acm request-certificate \
            --domain-name $DOMAIN_NAME \
            --subject-alternative-names "www.$DOMAIN_NAME" \
            --validation-method DNS \
            --region us-east-1 \
            --profile $PROFILE)

        cert_arn=$(echo $cert_result | jq -r '.CertificateArn')

        log_success "SSL certificate requested: $cert_arn"
        log_warning "You need to validate the certificate via DNS before it can be used"
        log_info "Check your ACM console for validation records"
    fi
}

# Create Route 53 hosted zone
create_route53_zone() {
    log_info "Creating Route 53 hosted zone..."

    # Check if hosted zone already exists
    existing_zone=$(aws route53 list-hosted-zones-by-name \
        --dns-name $DOMAIN_NAME \
        --query "HostedZones[?Name=='$DOMAIN_NAME.'].Id" \
        --output text \
        --profile $PROFILE)

    if [ ! -z "$existing_zone" ]; then
        log_warning "Route 53 hosted zone already exists: $existing_zone"
    else
        # Create hosted zone
        zone_result=$(aws route53 create-hosted-zone \
            --name $DOMAIN_NAME \
            --caller-reference "mortgage-guardian-$(date +%s)" \
            --profile $PROFILE)

        zone_id=$(echo $zone_result | jq -r '.HostedZone.Id')

        log_success "Route 53 hosted zone created: $zone_id"
        log_info "Don't forget to update your domain's nameservers with your registrar"
    fi
}

# Invalidate CloudFront cache
invalidate_cloudfront() {
    if [ ! -z "$CLOUDFRONT_DISTRIBUTION_ID" ]; then
        log_info "Invalidating CloudFront cache..."

        aws cloudfront create-invalidation \
            --distribution-id $CLOUDFRONT_DISTRIBUTION_ID \
            --paths "/*" \
            --profile $PROFILE

        log_success "CloudFront cache invalidation initiated"
    fi
}

# Generate 404 page
create_404_page() {
    log_info "Creating 404 error page..."

    cat > 404.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Page Not Found - Mortgage Guardian</title>
    <link rel="stylesheet" href="css/styles.css">
</head>
<body>
    <div class="container" style="text-align: center; padding: 100px 20px;">
        <h1 style="font-size: 72px; color: #0066CC; margin-bottom: 20px;">404</h1>
        <h2>Page Not Found</h2>
        <p>The page you're looking for doesn't exist.</p>
        <a href="/" class="btn btn-primary">Return Home</a>
    </div>
</body>
</html>
EOF

    log_success "404 error page created"
}

# Create robots.txt
create_robots_txt() {
    log_info "Creating robots.txt..."

    cat > robots.txt << EOF
User-agent: *
Allow: /

Sitemap: https://$DOMAIN_NAME/sitemap.xml
EOF

    log_success "robots.txt created"
}

# Create sitemap.xml
create_sitemap() {
    log_info "Creating sitemap.xml..."

    cat > sitemap.xml << EOF
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
    <url>
        <loc>https://$DOMAIN_NAME/</loc>
        <lastmod>$(date +%Y-%m-%d)</lastmod>
        <changefreq>weekly</changefreq>
        <priority>1.0</priority>
    </url>
    <url>
        <loc>https://$DOMAIN_NAME/#features</loc>
        <lastmod>$(date +%Y-%m-%d)</lastmod>
        <changefreq>monthly</changefreq>
        <priority>0.8</priority>
    </url>
    <url>
        <loc>https://$DOMAIN_NAME/#pricing</loc>
        <lastmod>$(date +%Y-%m-%d)</lastmod>
        <changefreq>monthly</changefreq>
        <priority>0.8</priority>
    </url>
    <url>
        <loc>https://$DOMAIN_NAME/#contact</loc>
        <lastmod>$(date +%Y-%m-%d)</lastmod>
        <changefreq>monthly</changefreq>
        <priority>0.6</priority>
    </url>
</urlset>
EOF

    log_success "sitemap.xml created"
}

# Main deployment function
deploy() {
    log_info "Starting Mortgage Guardian website deployment..."

    check_prerequisites
    create_404_page
    create_robots_txt
    create_sitemap
    create_s3_bucket
    upload_website
    create_cloudfront_distribution
    request_ssl_certificate
    create_route53_zone
    invalidate_cloudfront

    log_success "Deployment completed!"
    log_info "Website URL: http://$BUCKET_NAME.s3-website-$REGION.amazonaws.com"

    if [ ! -z "$CLOUDFRONT_DISTRIBUTION_ID" ]; then
        cloudfront_domain=$(aws cloudfront get-distribution \
            --id $CLOUDFRONT_DISTRIBUTION_ID \
            --query 'Distribution.DomainName' \
            --output text \
            --profile $PROFILE)
        log_info "CloudFront URL: https://$cloudfront_domain"
    fi

    log_info "Custom domain: https://$DOMAIN_NAME (after DNS setup)"
}

# Parse command line arguments
case "${1:-deploy}" in
    "deploy")
        deploy
        ;;
    "upload")
        upload_website
        invalidate_cloudfront
        ;;
    "invalidate")
        invalidate_cloudfront
        ;;
    "help")
        echo "Usage: $0 [command]"
        echo "Commands:"
        echo "  deploy     - Full deployment (default)"
        echo "  upload     - Upload files only"
        echo "  invalidate - Invalidate CloudFront cache only"
        echo "  help       - Show this help message"
        ;;
    *)
        log_error "Unknown command: $1"
        echo "Run '$0 help' for usage information"
        exit 1
        ;;
esac