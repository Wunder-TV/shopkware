#!/usr/bin/env bash
set -e

composer install # --no-dev currently doesn't work

touch .env # Make sure .env file exists this makes sure that shopware loads the env variables (an empty file is fine)

# Check if config/jwt contains pem files otherwise create jwt secrets
PEM_FILES=$(find config/jwt/ -name '*.pem')
if [[ -z "$PEM_FILES" ]]; then
    echo "Generate jwt secret"
    ./bin/console system:generate-jwt-secret
fi

# Finish Update
./bin/console system:update:finish

./bin/console sales-channel:list -q 2>/dev/null || exit 0 # if sales channels are not accessible, most probably shopware is not installed yet. Stop execution for preventing docker build failure.

./bin/console cache:clear
./bin/console bundle:dump
SHOPWARE_SKIP_BUNDLE_DUMP=1 SHOPWARE_SKIP_ASSET_COPY=1 DISABLE_ADMIN_COMPILATION_TYPECHECK=1 ./bin/build-administration.sh
SHOPWARE_SKIP_BUNDLE_DUMP=1 SHOPWARE_SKIP_ASSET_COPY=1 SHOPWARE_SKIP_THEME_COMPILE=1 ./bin/build-storefront.sh
./bin/console assets:install
./bin/console theme:compile

