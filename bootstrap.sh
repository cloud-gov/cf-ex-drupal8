#!/bin/bash 
set -euo pipefail

fail() {
  echo FAIL: "$@"
  exit 1
}

SECRETS=$(echo $VCAP_SERVICES | jq -r '.["user-provided"][] | select(.name == "secrets") | .credentials') ||
  fail "Unable to parse SECRETS from VCAP_SERVICES"
APP_NAME=$(echo $VCAP_APPLICATION | jq -r '.name') ||
  fail "Unable to parse APP_NAME from VCAP_SERVICES"
APP_ROOT=$(dirname "${BASH_SOURCE[0]}")

S3_FAKE=$(echo $VCAP_SERVICES | jq -r '.["s3"][] | select(.name == "storage") | .s3fake')
[ "$S3_FAKE" != "null" ] && echo "Using fake S3"

S3_BUCKET=$(echo $VCAP_SERVICES | jq -r '.["s3"][] | select(.name == "storage") | .credentials.bucket') ||
  fail "Unable to parse S3_BUCKET from VCAP_SERVICES"
S3_REGION=$(echo $VCAP_SERVICES | jq -r '.["s3"][] | select(.name == "storage") | .credentials.region') ||
  fail "Unable to parse S3_REGION from VCAP_SERVICES"

if [ -n "$S3_BUCKET" ] && [ -n "$S3_REGION" ]; then
  # Add Proxy rewrite rules to the top of the htaccess file
  sed -e "s/S3_BUCKET/$S3_BUCKET/g; s/S3_REGION/$S3_REGION/g" \
     < $APP_ROOT/web/.htaccess.in > $APP_ROOT/web/.htaccess
else
  fail "Unable to rewrite .htaccess without S3_BUCKET S3_REGION"
fi

install_drupal() {
    ROOT_USER_NAME=$(echo $SECRETS | jq -r '.ROOT_USER_NAME')
    ROOT_USER_PASS=$(echo $SECRETS | jq -r '.ROOT_USER_PASS')

    : "${ROOT_USER_NAME:?Need and root user name for Drupal}"
    : "${ROOT_USER_PASS:?Need and root user pass for Drupal}"

    drupal site:install \
        --root=$APP_ROOT/web \
        --no-interaction \
        --account-name="$ROOT_USER_NAME" \
        --account-pass="$ROOT_USER_PASS" \
        --langcode="en"
    # Delete some data created in the "standard" install profile
    # See https://www.drupal.org/project/drupal/issues/2583113
    drupal --root=$APP_ROOT/web entity:delete shortcut_set default --no-interaction
    drupal --root=$APP_ROOT/web config:delete active field.field.node.article.body --no-interaction
    # Set site uuid to match our config
    UUID=$(grep uuid $APP_ROOT/web/sites/default/config/system.site.yml | cut -d' ' -f2)
    drupal --root=$APP_ROOT/web config:override system.site uuid $UUID
}

if [ "${CF_INSTANCE_INDEX:-''}" == "0" ] && [ "${APP_NAME}" == "web" ]; then
  drupal --root=$APP_ROOT/web list | grep database > /dev/null || install_drupal
  # Mild data migration: fully delete database entries related to these
  # modules. These plugins (and the dependencies) can be removed once they've
  # been uninstalled in all environments

  # Sync configs from code
  drupal --root=$APP_ROOT/web config:import

  # Secrets
  ADMIN_EMAIL=$(echo $SECRETS | jq -r '.ADMIN_EMAIL')
  CRON_KEY=$(echo $SECRETS | jq -r '.CRON_KEY')
  drupal --root=$APP_ROOT/web config:override scheduler.settings lightweight_cron_access_key $CRON_KEY > /dev/null
  drupal --root=$APP_ROOT/web config:override system.site mail $ADMIN_EMAIL > /dev/null
  drupal --root=$APP_ROOT/web config:override update.settings notification.emails.0 $ADMIN_EMAIL > /dev/null

  # Import initial content
  drush --root=$APP_ROOT/web default-content-deploy:import --no-interaction

  # Clear the cache
  drupal --root=$APP_ROOT/web cache:rebuild --no-interaction

#  # Copy local files to S3"
#  drush --root=$APP_ROOT/web s3fs:copy-local --no-interaction
fi
