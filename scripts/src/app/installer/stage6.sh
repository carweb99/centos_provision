#!/usr/bin/env bash

stage6(){
  debug "Starting stage 6: run ansible playbook"
  download_provision
  run_ansible_playbook
  clean_up
  show_successful_message
  if isset "$ANSIBLE_TAGS"; then
    debug "Ansible tags is set to ${ANSIBLE_TAGS} - skip printing credentials"
    if [[ "${ANSIBLE_TAGS}" =~ /upgrade/ ]]; then
      signal_successful_installation
    fi
  else
    signal_successful_installation
    show_credentials
  fi
}

signal_successful_installation() {
  debug "Signaling successful installation by writing 'installed' flag to the inventory file"
  VARS['installed']=true
  write_inventory_file
}
