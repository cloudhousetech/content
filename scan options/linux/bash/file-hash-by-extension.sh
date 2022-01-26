#!/usr/bin/env bash
# Get all files in all subdirectories
# find . -type f|sed 's/\.\///'|sort

/usr/bin/find . \! -type d -a \! -type s | sort | xargs md5sum

# Prints something like:
# 9ffdedb691b43906e2dc4a29b88f5f1c  ./cluster/prod/media/Makefile
# fa95448d456e4e8b5cfbeeb7e1f8b6d1  ./cluster/prod/media/context