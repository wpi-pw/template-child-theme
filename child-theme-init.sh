#!/bin/bash

# WPI Child theme
# by DimaMinka (https://dima.mk)
# https://github.com/wpi-pw/app

# Get config files and put to array
wpi_confs=()
for ymls in wpi-config/*
do
  wpi_confs+=("$ymls")
done

# Get wpi-source for yml parsing, noroot, errors etc
source <(curl -s https://raw.githubusercontent.com/wpi-pw/template-workflow/master/wpi-source.sh)

# Get the child theme and run install by type
printf "${GRN}==================================================${NC}\n"
printf "${GRN}Installing child theme $(wpi_yq themes.child.name)${NC}\n"
printf "${GRN}==================================================${NC}\n"
zip="^(https|git)(:\/\/|@)([^\/:]+)[\/:]([^\/:]+)\/([^\/:]+)\/([^\/:]+)\/(.+).zip$"
cur_env=$1
version=""
package=$(wpi_yq themes.child.name)
package_ver=$(wpi_yq themes.child.ver)
repo_name=$(echo ${package} | cut -d"/" -f2)
no_dev="--no-dev"
dev_commit=$(echo ${package_ver} | cut -d"#" -f1)
ver_commit=$(echo ${package_ver} | cut -d"#" -f2)
# Check the workflow type
content_dir=$([ "$(wpi_yq init.workflow)" == "bedrock" ] && echo "app" || echo "wp-content")

if [ "$(wpi_yq themes.child.generate_scaffold)" == "true" ]; then
    # Generate child theme via wp cli scaffold
    wp scaffold child-theme $package --parent_theme=$(wpi_yq themes.parent.name) --quiet --force
# Running child theme install via wp-cli
elif [ "$(wpi_yq themes.child.package)" == "wp-cli" ]; then
  # Install from zip
  if [[ $(wpi_yq themes.child.zip) =~ $zip ]]; then
    wp theme install $(wpi_yq themes.child.zip) --quiet
  else
    # Get child theme version from config
    if [ "$package_ver" != "null" ] && [ "$package_ver" != "*" ]; then
      version="--version=$package_ver --force"
    fi
    # Default child theme install via wp-cli
    wp theme install $package --quiet ${version}
  fi

  # Run renaming process
  if [ "$(wpi_yq themes.child.rename)" != "null" ]; then
    # Run rename command
    mv ${PWD}/web/$content_dir/themes/$package ${PWD}/web/$content_dir/themes/$(wpi_yq themes.child.rename)
  fi
fi

# Get child theme version from config
if [ "$package_ver" != "null" ] && [ "$package_ver" != "*" ]; then
  json_ver=$package_ver
  # check for commit version
  if [ "$dev_commit" == "dev-master" ]; then
    json_ver="dev-master"
  fi
else
  # default versions
  json_ver="dev-master"
  package_ver="dev-master"
  ver_commit="master"
fi

# Running child theme install via composer from bitbucket/github
if [ "$(wpi_yq themes.child.package)" == "bitbucket" ] || [ "$(wpi_yq themes.child.package)" == "github" ]; then
  # Install child theme from private/public repository via composer
  # Check for setup settings
  if [ "$(wpi_yq themes.child.setup)" != "null" ]; then
    name=$(wpi_yq themes.child.setup)

    # OAUTH for bitbucket via key and secret
    if [ "$(wpi_yq themes.child.package)" == "bitbucket" ] && [ "$(wpi_yq init.setup.$name.bitbucket.key)" != "null" ] && [ "$(wpi_yq init.setup.$name.bitbucket.secret)" != "null" ]; then
      composer config --global --auth bitbucket-oauth.bitbucket.org $(wpi_yq init.setup.$name.bitbucket.key) $(wpi_yq init.setup.$name.bitbucket.secret)
    fi

    # OAUTH for github via key and secret
    if [ "$(wpi_yq themes.child.package)" == "github" ] && [ "$(wpi_yq init.setup.$name.github-token)" != "null" ] && [ "$(wpi_yq init.setup.$name.github-token)" != "null" ]; then
      composer config -g github-oauth.github.com $(wpi_yq init.setup.$name.github-token)
    fi
  fi

  # Build package url by package type
  if [ "$(wpi_yq themes.child.package)" == "bitbucket" ]; then
    package_url="https://bitbucket.org/$package"
    package_zip="https://bitbucket.org/$package/get/$ver_commit.zip"
  elif [ "$(wpi_yq themes.child.package)" == "github" ]; then
    package_url="git@github.com:$package.git"
    package_zip="https://github.com/$package/archive/$ver_commit.zip"
  fi

  # Rename the package if config exist
  if [ "$(wpi_yq themes.child.rename)" != "null" ]; then
      package=$(wpi_yq themes.child.rename)
  fi

  # Get GIT for local and dev
  if [ "$cur_env" != "production" ] && [ "$cur_env" != "staging" ]; then
    # Reset --no-dev
    no_dev=""

    # Composer config and install - GIT version
    composer config repositories.$package '{"type":"package","package": {"name": "'$package'","version": "'$json_ver'","type": "wordpress-theme","source": {"url": "'$package_url'","type": "git","reference": "master"}}}'
    composer require $package:$package_ver --update-no-dev --quiet
  else
    # Remove the package from composer cache
    if [ -d ~/.cache/composer/files/$package ]; then
      rm -rf ~/.cache/composer/files/$package
    fi

    # Composer config and install - ZIP version
    composer config repositories.$package '{"type":"package","package": {"name": "'$package'","version": "'$package_ver'","type": "wordpress-theme","dist": {"url": "'$package_zip'","type": "zip"}}}'
    composer require $package:$package_ver --update-no-dev --quiet
  fi
fi

# Child theme setup variarable
name=$(wpi_yq themes.child.setup)
# Check if setup exist
if [ "$(wpi_yq init.setup.$name.composer)" != "null" ]; then
  composer=$(wpi_yq init.setup.$name.composer)
  # Run install composer script in the child theme
  if [ "$composer" != "null" ] && [ "$composer" == "install" ] || [ "$composer" == "update" ]; then
    composer $composer -d ${PWD}/web/$content_dir/themes/$repo_name $no_dev --quiet
  elif [ "$composer" != "null" ] && [ "$composer" == "dump-autoload" ]; then
    composer -d ${PWD}/web/$content_dir/themes/$repo_name dump-autoload -o --quiet
  fi
fi

# Run npm scripts
if [ "$(wpi_yq init.setup.$name.npm)" != "null" ]; then
  # run npm install
  npm i ${PWD}/web/$content_dir/themes/$repo_name &> /dev/null
  if [ "$cur_env" == "production" ] || [ "$cur_env" == "staging" ]; then
    eval $(wpi_yq init.setup.$name.npm.prod) --prefix ${PWD}/web/$content_dir/themes/$repo_name
  else
    eval $(wpi_yq init.setup.$name.npm.dev) --prefix ${PWD}/web/$content_dir/themes/$repo_name
  fi
fi
