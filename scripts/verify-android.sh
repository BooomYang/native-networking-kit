#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GRADLEW="${ROOT_DIR}/platforms/android/gradlew"
GRADLE_HOME="${ROOT_DIR}/.tmp/gradle"
ANDROID_USER_DIR="${ROOT_DIR}/.tmp/android"
JAVA_USER_HOME="${ROOT_DIR}/.tmp/home"
MAVEN_LOCAL_REPO="${ROOT_DIR}/.tmp/m2/repository"
DEFAULT_ANDROID_SDK="${HOME}/Library/Android/sdk"
ANDROID_SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-${DEFAULT_ANDROID_SDK}}}"

if [ ! -x "${GRADLEW}" ]; then
  echo "Android Gradle Wrapper is missing or not executable: ${GRADLEW}" >&2
  exit 1
fi

if [ ! -d "${ANDROID_SDK}" ]; then
  echo "Android SDK not found. Set ANDROID_HOME or ANDROID_SDK_ROOT, or install SDK at ${DEFAULT_ANDROID_SDK}." >&2
  exit 1
fi

mkdir -p "${GRADLE_HOME}" "${ANDROID_USER_DIR}" "${JAVA_USER_HOME}" "${MAVEN_LOCAL_REPO}"

GRADLE_USER_HOME="${GRADLE_HOME}" \
GRADLE_OPTS="-Duser.home=${JAVA_USER_HOME} -Dmaven.repo.local=${MAVEN_LOCAL_REPO}" \
HOME="${JAVA_USER_HOME}" \
ANDROID_HOME="${ANDROID_SDK}" \
ANDROID_SDK_ROOT="${ANDROID_SDK}" \
ANDROID_USER_HOME="${ANDROID_USER_DIR}" \
"${GRADLEW}" -p "${ROOT_DIR}/platforms/android" test lint :example:assembleDebug publishToMavenLocal
