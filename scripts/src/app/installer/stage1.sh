#!/usr/bin/env bash

stage1(){
  debug "Starting stage 1: initial script setup"
  parse_options "$@"
  setup_vars
  set_ui_lang
}
