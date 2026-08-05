#!/bin/bash

set -e

mkdir -p "$(dirname "$PT_path")"
touch "$PT_path"

if [ ! -z "$PT_owner" ]; then chown "$PT_owner" "$PT_path"; fi
if [ ! -z "$PT_group" ]; then chgrp "$PT_group" "$PT_path"; fi
if [ ! -z "$PT_mode"  ]; then chmod "$PT_mode"  "$PT_path"; fi

if [ ! -z "$PT_chown_r" ]; then
  chown -R "$PT_owner":"$PT_group" "$PT_chown_r"
fi

if [ ! -z "$PT_base64_content" ]; then
  # Binary content cannot be passed as a String, so it arrives base64-encoded.
  # No trailing newline here -- it would corrupt the decoded file.
  printf '%s' "$PT_base64_content" | base64 -d > "$PT_path"
else
  printf '%s\n' "$PT_content" > "$PT_path"
fi

