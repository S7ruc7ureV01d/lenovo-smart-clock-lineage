#!/bin/bash
#
# Copyright (C) 2026 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#
# The things_mt8167s_som_dump keeps system files under system/system/, which
# extract_utils does not look in. Build a staging dir with the expected layout.
#
# Usage: ./stage-dump.sh <path-to-things_mt8167s_som_dump> [staging-dir]

set -e

DUMP="$(realpath "${1:?usage: $0 <dump> [staging-dir]}")"
STAGE="$(realpath -m "${2:-${DUMP}/../cd24501f-staging}")"

mkdir -p "${STAGE}"
ln -sfn "${DUMP}/system/system" "${STAGE}/system"
ln -sfn "${DUMP}/vendor" "${STAGE}/vendor"

echo "${STAGE}"
