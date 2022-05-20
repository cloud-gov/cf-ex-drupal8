#!/bin/bash
set -euo pipefail

SECRETS=$(echo "$VCAP_SERVICES" | jq -r '.["user-provided"][] | select(.name == "secrets") | .credentials')
APP_NAME=$(echo "$VCAP_APPLICATION" | jq -r '.name')
APP_ROOT=$(dirname "${BASH_SOURCE[0]}")
DOC_ROOT="$APP_ROOT/web"
APP_ID=$(echo "$VCAP_APPLICATION" | jq -r '.application_id')

DB_NAME=$(echo "$VCAP_SERVICES" | jq -r '.["aws-rds"][] | .credentials.db_name')
DB_USER=$(echo "$VCAP_SERVICES" | jq -r '.["aws-rds"][] | .credentials.username')
DB_PW=$(echo "$VCAP_SERVICES" | jq -r '.["aws-rds"][] | .credentials.password')
DB_HOST=$(echo "$VCAP_SERVICES" | jq -r '.["aws-rds"][] | .credentials.host')
DB_PORT=$(echo "$VCAP_SERVICES" | jq -r '.["aws-rds"][] | .credentials.port')

S3_BUCKET=$(echo "$VCAP_SERVICES" | jq -r '.["s3"][]? | select(.name == "storage") | .credentials.bucket')
export S3_BUCKET
S3_REGION=$(echo "$VCAP_SERVICES" | jq -r '.["s3"][]? | select(.name == "storage") | .credentials.region')
export S3_REGION
if [ -n "$S3_BUCKET" ] && [ -n "$S3_REGION" ]; then
  # Add Proxy rewrite rules to the top of the htaccess file
  sed "s/^#RewriteRule .s3fs/RewriteRule ^s3fs/" "$DOC_ROOT/template-.htaccess" > "$DOC_ROOT/.htaccess"
else
  cp "$DOC_ROOT/template-.htaccess" "$DOC_ROOT/.htaccess"
fi

install_drupal() {
    ROOT_USER_NAME=$(echo "$SECRETS" | jq -r '.ROOT_USER_NAME')
    ROOT_USER_PASS=$(echo "$SECRETS" | jq -r '.ROOT_USER_PASS')

    : "${ROOT_USER_NAME:?Need and root user name for Drupal}"
    : "${ROOT_USER_PASS:?Need and root user pass for Drupal}"

    drupal site:install \
        --no-interaction \
        --account-name="$ROOT_USER_NAME" \
        --account-pass="$ROOT_USER_PASS" \
        --langcode="en"
    # Delete some data created in the "standard" install profile
    # See https://www.drupal.org/project/drupal/issues/2583113
    drupal entity:delete shortcut_set default --no-interaction
    drupal config:delete active field.field.node.article.body --no-interaction
    # Set site uuid to match our config
    UUID=$(grep uuid "$DOC_ROOT"/sites/default/config/system.site.yml | cut -d' ' -f2)
    drupal config:override system.site --key uuid --value "$UUID"
}

if [ "${CF_INSTANCE_INDEX:-''}" == "0" ] && [ "${APP_NAME}" == "web" ]; then
  if [ "$APP_ID" = "docker" ] ; then
    # make sure database is created
    echo "create database if not exists $DB_NAME;" | mysql --host="$DB_HOST" --port="$DB_PORT" --user="$DB_USER" --password="$DB_PW" || true
  fi

  # Go into the Drupal web root directory
  cd "$DOC_ROOT"

  drupal list | grep "config:import" > /dev/null || install_drupal
  # Mild data migration: fully delete database entries related to these
  # modules. These plugins (and the dependencies) can be removed once they've
  # been uninstalled in all environments

  # Sync configs from code
  drupal config:import --directory "$DOC_ROOT/sites/default/config"

  # Secrets
  ADMIN_EMAIL=$(echo "$SECRETS" | jq -r '.ADMIN_EMAIL')
  drupal config:override system.site --key mail --value "$ADMIN_EMAIL" > /dev/null
  drupal config:override update.settings --key notification.emails.0 --value "$ADMIN_EMAIL" > /dev/null

  # Import initial content
  drush default-content-deploy:import --folder "$DOC_ROOT/sites/default/content" --no-interaction

  # Clear the cache
  drupal cache:rebuild --no-interaction
fi
