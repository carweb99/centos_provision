#!/usr/bin/env bash

assert_config_relevant_or_upgrade_running(){
  debug 'Ensure configs has been genereated by relevant installer'
  if [[ "${RELEASE_VERSION}" == "${INSTALLED_VERSION}" ]]; then
    debug "Configs has been generated by recent version of installer ${RELEASE_VERSION}"
  elif is_upgrade_mode_set; then
    debug "Upgrade mode detected. Upgrading ${INSTALLED_VERSION} -> ${RELEASE_VERSION}"
  else
    fail "$(translate 'errors.upgrade_server')"
  fi
}
