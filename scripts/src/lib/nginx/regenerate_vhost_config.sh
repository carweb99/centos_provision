#!/usr/bin/env bash
#






regenerate_vhost_config(){
  local domain="${1}"
  local message_key="${2}"
  local generating_message="$(translate "${message_key}")"
  local command=""
  local changes=""
  local vhost_path="$(get_vhost_path "$domain")"
  local vhost_backup_path="$(get_vhost_backup_path "$domain")"
  if is_file_exist "$vhost_path" no; then
    debug "Backing up nginx config for ${domain} to ${vhost_backup_path}"
    cp "${vhost_path}" "${vhost_backup_path}"
  fi
  if need_to_regenerate_host_config "$vhost_path"; then
    command="${command}cp ${NGINX_KEITARO_CONF} "$vhost_path" && "
    changes="${changes}$(build_sed_expression_from_nginx_setting_block "listen 80" "listen 80 .*")"
    changes="${changes}$(build_sed_expression_from_nginx_setting_block "server_name ${domain}")"
  fi
  while isset "${3}"; do
    changes="${changes}$(build_sed_expression_from_nginx_setting_block "${3}")"
    shift
  done
  command="${command}sed -i${changes} ${vhost_path}"
  run_command "${command}" "${generating_message} ${domain}" "hide_output"
}


need_to_regenerate_host_config(){
  local vhost_path="${1}"
  ! is_file_exist "$vhost_path" no || ! vhost_config_relevant "$vhost_path"
}


vhost_config_relevant(){
  local vhost_path="${1}"
  grep -q -P "^# Generated by Keitaro .* v${RELEASE_VERSION}" "${vhost_path}"
}


get_vhost_path(){
  local domain="${1}"
  echo "${NGINX_VHOSTS_DIR}/${domain}.conf"
}

get_vhost_backup_path(){
  local domain="${1}"
  echo "${NGINX_VHOSTS_DIR}/${domain}.conf.$(date +%Y%m%d%H%M%S)"
}


build_sed_expression_from_nginx_setting_block(){
  local setting="${1}"
  local search_pattern="${2}"
  read name value <<< "$setting"
  if empty "$search_pattern"; then
    search_pattern="${name} .*"
  fi
  echo " -e 's|${search_pattern}|${name} ${value};|g'"
}
