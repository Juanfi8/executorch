#!/bin/bash
# Copyright (c) Meta Platforms, Inc. and affiliates.
# All rights reserved.
#
# This source code is licensed under the BSD-style license found in the
# LICENSE file in the root directory of this source tree.

set -ex

if [[ -z "${PYTHON_EXECUTABLE:-}" ]]; then
  PYTHON_EXECUTABLE=python3
fi
which "${PYTHON_EXECUTABLE}"

build_android_test() {
  mkdir -p extension/android/executorch_android/src/androidTest/resources
  cp extension/module/test/resources/add.pte extension/android/executorch_android/src/androidTest/resources
  pushd extension/android
  ANDROID_HOME="${ANDROID_SDK:-/opt/android/sdk}" ./gradlew :executorch_android:testDebugUnitTest
  ANDROID_HOME="${ANDROID_SDK:-/opt/android/sdk}" ./gradlew :executorch_android:assembleAndroidTest
  popd
}

collect_artifacts_to_be_uploaded() {
  ARTIFACTS_DIR_NAME="$1"
  # Collect Java library test
  JAVA_LIBRARY_TEST_DIR="${ARTIFACTS_DIR_NAME}/library_test_dir"
  mkdir -p "${JAVA_LIBRARY_TEST_DIR}"
  cp extension/android/executorch_android/build/outputs/apk/androidTest/debug/*.apk "${JAVA_LIBRARY_TEST_DIR}"
}

main() {
  build_android_test
  if [ -n "$ARTIFACTS_DIR_NAME" ]; then
    collect_artifacts_to_be_uploaded ${ARTIFACTS_DIR_NAME}
  fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
