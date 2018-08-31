#!/usr/bin/env bash
set -e

# Nginx config file path
NGINX_CONFIG_FILE_PATH="${NGINX_CONFIG_FILE_PATH:-/etc/nginx/nginx.conf}";
# Nginx http configs directory path
NGINX_HTTP_CONFIGS_DIR_PATH="${NGINX_HTTP_CONFIGS_DIR_PATH:-/etc/nginx/conf.d}";

NGINX_CONFIG_OVERRIDE="${NGINX_CONFIG_OVERRIDE:-}";
NGINX_HTTP_CONFIGS="${NGINX_HTTP_CONFIGS:-}";
WWW_DATA_ACCESSIBLE_DIRS="${WWW_DATA_ACCESSIBLE_DIRS:-}";
WWW_DATA_USER="${WWW_DATA_USER:-www-data}";
WWW_DATA_GROUP="${WWW_DATA_GROUP:-www-data}";

#cp -f ./data/config/nginx.conf ./nginx.conf; NGINX_CONFIG_FILE_PATH="./nginx.conf"; # for debug

# Make replaces using pattern in a file. Pattern must looks like: '%ENV_VAR_NAME|default value%', where:
# - 'ENV_VAR_NAME' - Environment variable name for replacing
# - 'default value' - Value for setting, if environment variable was not found (can be empty)
function make_replaces() {
  local FILE_PATH="$1"; # Path to the file (string)

  # Extract lines with variables from config file
  local found_variables=$(grep -oP '%[A-Za-z0-9_]+\|.*?%' "$FILE_PATH");
  #echo -e "DEBUG: Found variables in config file:\n$found_variables"; # for debug

  local name default_value env_value value;

  # Iterate found variables
  while read -r variable; do
    if [[ ! -z "$variable" ]]; then
      name=$(echo "$variable" | sed -n 's^.*%\(.*\)|.*%.*^\1^p');
      default_value=$(echo "$variable" | sed -n 's^.*%.*|\(.*\)%.*^\1^p');
      env_value=$(eval "echo \$${name}");
      value="${env_value:-$default_value}";

      # Make replaces
      if [[ ! -z "$name" ]]; then
        echo "INFO: [$FILE_PATH] Set \"%$name%\" to \"$value\"";

        sed -i "s^%$name|[^%]*%^${value//\&/\\\&}^gi" "$FILE_PATH";
      else
        (>&2 echo "ERROR: Variable named \"$name\" has no default value or invalid.");
      fi;
    fi;
  done <<< "$found_variables";
}

# Print nginx banner
function show_banner() {
  local extra="$1"; # Extra string (string)
  echo '  __              _             __  ';
  echo ' / /  _ __   __ _(_)_ __ __  __ \ \ ';
  echo '/ /  | "_ \ / _" | | "_ \\ \/ /  \ \';
  echo '\ \  | | | | (_| | | | | |>  <   / /';
  echo ' \_\ |_| |_|\__, |_|_| |_/_/\_\ /_/ ';
  echo "            |___/  [v$(nginx -v 2>&1 | sed -n 's~.*nginx\/\(.*\)~\1~p')]";
  echo "                   $extra";
  echo;
}

# Override main nginx config (if needed)
if [[ ! -z "$NGINX_CONFIG_OVERRIDE" ]]; then
  if [ -f "$NGINX_CONFIG_OVERRIDE" ]; then
    echo "INFO: Copy main config file \"$NGINX_CONFIG_OVERRIDE\" to \"$NGINX_CONFIG_FILE_PATH\"";

    cp -pf "$NGINX_CONFIG_OVERRIDE" "$NGINX_CONFIG_FILE_PATH" || (
      >&2 echo "ERROR: Cannot copy file \"$NGINX_CONFIG_OVERRIDE\" to \"$NGINX_CONFIG_FILE_PATH\".";
    );
  else
    echo "WARNING: Skip main config file \"$NGINX_CONFIG_OVERRIDE\" (file not exists)";
  fi;
fi;

# Make main nginx config file replaces
make_replaces "$NGINX_CONFIG_FILE_PATH";
#echo -e "DEBUG: Nginx config file content: $(cat $NGINX_CONFIG_FILE_PATH)"; # for debug

# Make copy extra http configs
if [[ ! -z "$NGINX_HTTP_CONFIGS" ]]; then
  for http_config_path in $(echo "${NGINX_HTTP_CONFIGS}" | tr [:space:] ' '); do
    if [ -f "$http_config_path" ]; then
      echo "INFO: Copy file \"$http_config_path\" into \"$NGINX_HTTP_CONFIGS_DIR_PATH\"";

      cp -pf "$http_config_path" "$NGINX_HTTP_CONFIGS_DIR_PATH" || (
        >&2 echo "ERROR: Cannot copy file \"$http_config_path\" into \"$NGINX_HTTP_CONFIGS_DIR_PATH\".";
      );
    else
      echo "WARNING: Skip file \"$http_config_path\" (file not exists)";
    fi;
  done;
fi;

# Set owner 'www-data' for listed directories
if [[ ! -z "$WWW_DATA_ACCESSIBLE_DIRS" ]]; then
  for directory_path in $(echo "${WWW_DATA_ACCESSIBLE_DIRS}" | tr [:space:] ' '); do
    if [ -d "$directory_path" ]; then
      echo "INFO: Change owner of \"$directory_path\" to \"$WWW_DATA_USER:$WWW_DATA_GROUP\"";

      chown -R "$WWW_DATA_USER:$WWW_DATA_GROUP" "$directory_path" || (
        >&2 echo "ERROR: Cannot change directory \"$directory_path\" owner to \"$WWW_DATA_USER:$WWW_DATA_GROUP\".";
      );
    else
      echo "WARNING: Skip directory owner changing \"$directory_path\" (directory not exists)";
    fi;
  done;
fi;

if nginx -t; then
  show_banner "Starting daemon..";
fi;

exec "$@";
