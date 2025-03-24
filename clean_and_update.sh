#!/bin/bash
# This source code is licensed under the BSD-style license found in the
# LICENSE file in the root directory of this source tree.

# Before doing anything, cd to the directory containing this script.

# Cleaning the build system

./install_requirements.sh --clean
git submodule sync
git submodule update --init
./install_executorch.sh
