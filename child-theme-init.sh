#!/bin/bash

# Theme Init - Wp Pro Club
# by DimaMinka (https://dimaminka.com)
# https://github.com/wp-pro-club/init

source ${PWD}/lib/app-init.sh

version=""
zip="^(https|git)(:\/\/|@)([^\/:]+)[\/:]([^\/:]+)\/([^\/:]+)\/([^\/:]+)\/(.+).zip$"
# Get the child theme and run install by type
printf "${GRN}=============================================${NC}\n"
printf "${GRN}Installing child theme $conf_app_child_theme_name${NC}\n"
printf "${GRN}=============================================${NC}\n"
if [ "$conf_app_child_theme_generate_scaffold" == "true" ]; then
    # Generate child theme via wp cli scaffold
    wp scaffold child-theme $conf_app_child_theme_name --parent_theme=$conf_app_theme_name --force
elif [ "$conf_app_child_theme_package" == "wp-cli" ]; then
    # Running child theme install via wp-cli
    if [[ $conf_app_child_theme_zip =~ $zip ]]; then
        # Install from zip
        wp theme install $conf_app_child_theme_zip
    else
        # Get child theme version from config
        if [ "$conf_app_child_theme_ver" != "*" ]; then
            version="--version=$conf_app_child_theme_ver --force"
        fi
        # Default child theme install via wp-cli
        wp theme install $conf_app_child_theme_name ${version}
    fi
elif [ "$conf_app_child_theme_package" == "wpackagist" ]; then
    # Install child theme from wpackagist via composer
    composer require wpackagist-theme/$conf_app_child_theme_name:$conf_app_child_theme_ver --update-no-dev
elif [ "$conf_app_child_theme_package" == "composer_bitbucket" ]; then
    ## Install plugin from private bitbucket repository via composer
    project=$conf_app_child_theme_name
    project_ver=$conf_app_child_theme_ver
    project_zip="https://bitbucket.org/$project/get/$project_ver.zip"
    composer config repositories.$project '{"type":"package","package": {"name": "'$project'","version": "'$project_ver'","type": "wordpress-theme","dist": {"url": "'$project_zip'","type": "zip"}}}'
    composer require $project:dev-master --update-no-dev
fi
