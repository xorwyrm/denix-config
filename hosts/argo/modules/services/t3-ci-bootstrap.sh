#!/usr/bin/env bash
set -euo pipefail
install -d -o runner -g runner /opt/actions-runner /opt/hostedtoolcache /opt/android-sdk /home/runner/.cache
curl --fail --location --retry 3 --output /opt/actions-runner/runner.tar.gz https://github.com/actions/runner/releases/download/v2.338.2/actions-runner-linux-x64-2.338.2.tar.gz
printf '%s  %s\n' baebf204307bac6193480852732f0aba2ae97b6c5597c244f4d5558390147c40 /opt/actions-runner/runner.tar.gz | sha256sum --check -
tar -xzf /opt/actions-runner/runner.tar.gz -C /opt/actions-runner
/opt/actions-runner/bin/installdependencies.sh
curl --fail --location --retry 3 --output /opt/android-sdk/commandlinetools.zip https://dl.google.com/android/repository/commandlinetools-linux-16111833_latest.zip
printf '%s  %s\n' e025545c62a8e64c7559119566a569fb1dec5f60 /opt/android-sdk/commandlinetools.zip | sha1sum --check -
install -d /opt/android-sdk/cmdline-tools
unzip -q /opt/android-sdk/commandlinetools.zip -d /opt/android-sdk/cmdline-tools
mv /opt/android-sdk/cmdline-tools/cmdline-tools /opt/android-sdk/cmdline-tools/latest
# Reuse the Android SDK license already accepted in the fleet's Nix configuration.
install -d /opt/android-sdk/licenses
printf '%s\n' 24333f8a63b6825ea9c5514f83c2829b004d1fee > /opt/android-sdk/licenses/android-sdk-license
/opt/android-sdk/cmdline-tools/latest/bin/sdkmanager --sdk_root=/opt/android-sdk 'platform-tools'
cat > /opt/actions-runner/.env <<'ENV'
AGENT_TOOLSDIRECTORY=/opt/hostedtoolcache
RUNNER_TOOL_CACHE=/opt/hostedtoolcache
ANDROID_HOME=/opt/android-sdk
ANDROID_SDK_ROOT=/opt/android-sdk
JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
ENV
chown -R runner:runner /opt/actions-runner /opt/hostedtoolcache /opt/android-sdk
python3 - <<'CLEAN'
from pathlib import Path
for name in ['/opt/actions-runner/runner.tar.gz', '/opt/android-sdk/commandlinetools.zip']:
    path = Path(name)
    if path.exists():
        path.unlink()
CLEAN
