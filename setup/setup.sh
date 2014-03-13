#!/bin/bash

# Get absolute path to main directory
ABSPATH=$(cd "${0%/*}" 2>/dev/null; echo "${PWD}/${0##*/}")
SOURCE_DIR=`dirname "${ABSPATH}"`


if [ -z ${ENVIRONMENT} ]; then
     echo "Illegal environment code - set Environment Variable ENVIRONMENT"
     exit 1
fi
if [ -z ${WEBGROUP} ]; then
     echo "WEBGROUP Missing - set Environment Variable WEBGROUP"
     exit 1
fi
if [ -z ${WEBUSER} ]; then
     echo "WEBUSER Missing - set Environment Variable WEBUSER"
     exit 1
fi

if [ -z ${CONTEXT} ]; then
     echo "CONTEXT not set - using dev context"
     CONTEXT="dev"
fi

echo "Dir "
echo $SOURCE_DIR

cd $SOURCE_DIR/..

echo " Apply Settings"
echo " --------------"
php vendor/aoepeople/envsettingstool/apply.php ${ENVIRONMENT} setup/env-settings.csv || exit 1



# TODO - cache clear and warmu need --env=prod --no-debug
# Maybe move this to deployment Workflow configuration

echo " Clear Cache"
echo " --------------"
php app/console cache:clear --env="${CONTEXT}" || exit 1

echo " Warmup Cache"
echo " --------------"
php app/console cache:warmup  --env="${CONTEXT}" || exit 1

echo " Symlink Assets Cache"
echo " --------------"
php app/console assets:install --symlink --relative  --env="${CONTEXT}" || exit 1


echo " Call Doctrine Migrations"
echo " --------------"
#php app/console doctrine:migrations:migrate --no-interaction --env="${CONTEXT}" || exit 1

echo "Fix Permissions"
echo " --------------"
mkdir -p app/cache/dev
mkdir -p g+ws app/cache/prod
chgrp -R $WEBGROUP .
chmod -R g+ws app/cache
chmod -R g+ws app/logs
chown -R $WEBUSER .