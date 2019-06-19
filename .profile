#!/bin/sh
# this code is executed while initializing the app:
# https://docs.cloudfoundry.org/devguide/deploy-apps/deploy-app.html#profile

S3_BUCKET=$(echo "$VCAP_SERVICES" | jq -r '.["s3"][]? | select(.name == "storage") | .credentials.bucket')
export S3_BUCKET
S3_REGION=$(echo "$VCAP_SERVICES" | jq -r '.["s3"][]? | select(.name == "storage") | .credentials.region')
export S3_REGION

if [ -f /app/web/.htaccess ] ; then
  if [ -n "$S3_BUCKET" ] && [ -n "$S3_REGION" ]; then
    # Add Proxy rewrite rules to the top of the htaccess file
    sed "s/^#RewriteRule .s3fs/RewriteRule ^s3fs/" /app/web/template-.htaccess > /app/web/.htaccess
  else
    cp /app/web/template-.htaccess /app/web/.htaccess
  fi
else
  echo "cannot find .htaccess!"
  exit 1
fi

