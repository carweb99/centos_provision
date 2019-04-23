#!/usr/bin/env bash
#






assert_server_configuration_relevant(){
  debug 'Ensure configs was genereated by relevant installer'
  if isset "$SKIP_CHECKS"; then
    debug "SKIP: аctual check of installer version in ${INVENTORY_FILE} disabled"
  else
    installed_version=$(detect_installed_version)
    if [[ "${RELEASE_VERSION}" == "${installed_version}" ]]; then
      debug "Configs was generated by recent version of installer ${RELEASE_VERSION}"
    else
      debug "Configs was generated by old version of installer iv=${installed_version} rv=${RELEASE_VERSION}"
      fail "$(translate 'errors.contact_support_team')"
    fi
  fi
}

detect_installed_version(){
  local version=""
  if is_file_exist ${INVENTORY_FILE}; then
    version=$(grep "^installer_version=" ${INVENTORY_FILE} | sed s/^installer_version=//g)
  fi
  if empty "$version"; then
    version="0.9"
  fi
  echo "$version"
}
