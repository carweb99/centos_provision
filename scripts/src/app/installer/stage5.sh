#!/usr/bin/env bash

stage5(){
  debug "Starting stage 5: run ansible playbook"
  download_provision
  run_ansible_playbook
  run_ssl_enabler
  clean_up
  show_successful_message
  remove_log_files
}
