#!/bin/sh
#
# This script will attempt to create the services required
# and then launch everything.
#

# this function will generate a random string, or bail if uuidgen is not available.
generate_string()
{
  if [ -z "$1" ] ; then
    if command -v uuidgen >/dev/null ; then
      NEW_STRING=$(uuidgen)
      export NEW_STRING
    else
      echo "cannot find uuidgen utility:  You will need to generate some random strings and put them in the CRON_KEY, HASH_SALT, and ROOT_USER_PASS environment variables, then re-run this script."
      exit 1
    fi
  fi
}

# If the user does not supply required data, generate some secrets.
generate_string "$CRON_KEY"
CRON_KEY=${CRON_KEY:-$NEW_STRING}

generate_string "$HASH_SALT"
HASH_SALT=${HASH_SALT:-$NEW_STRING}

generate_string "$ROOT_USER_PASS"
ROOT_USER_PASS=${ROOT_USER_PASS:-$NEW_STRING}

ROOT_USER_NAME=${ROOT_USER_NAME:-root}


# function to check if a service exists
service_exists()
{
  cf service "$1" >/dev/null 2>&1
}

# create services (if needed)
if service_exists "database" ; then
  echo database already created
else
  if [ "$1" = "prod" ] ; then
    cf create-service aws-rds medium-mysql database
  else
    cf create-service aws-rds shared-mysql database
  fi
fi

if service_exists "secrets" ; then
  echo secrets already created
else
  yes '' | cf create-user-provided-service secrets -p "{\"CRON_KEY\": \"$CRON_KEY\", \"HASH_SALT\": \"$HASH_SALT\", \"ROOT_USER_NAME\": \"$ROOT_USER_NAME\", \"ROOT_USER_PASS\": \"$ROOT_USER_PASS\"}"
fi

if service_exists "storage" ; then
  echo storage already created
else
  cf create-service s3 basic-sandbox storage
fi

# wait until the db is fully provisioned
until cf create-service-key database test-db-ok ; do
	echo waiting until database is live...
	sleep 20
done
cf delete-service-key database test-db-ok -f

# launch the apps
cf push

# tell people where to go
ROUTE=$(cf apps | grep web | awk '{print $6}')

echo
echo
echo "  to log into the drupal site, you will want to go to https://${ROUTE}/user/login and use"
echo "USERNAME:  ${ROOT_USER_NAME}"
echo "PASSWORD:  ${ROOT_USER_PASS}"
echo "  to get in.  Have fun!"
