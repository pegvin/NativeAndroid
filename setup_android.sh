#!/bin/sh

# NOTE: By using this script, You accept any License/Agreements
# required by the Android Project

set -eu

if [ -f ./cmdline_tools.zip ]; then
	echo "# cmdline_tools.zip Found"
else
	echo "# Download command line tools"
	wget -q --show-progress "https://dl.google.com/android/repository/commandlinetools-linux-13114758_latest.zip" -O ./cmdline_tools.zip
fi

if [ -d ./cmdline-tools/ ]; then
	echo "# cmdline-tools/ Found"
else
	echo "# Unzip cmdline_tools.zip"
	unzip ./cmdline_tools.zip

	mv ./cmdline-tools ./latest/
	mkdir ./cmdline-tools/
	mv ./latest ./cmdline-tools/

	# https://stackoverflow.com/a/45782695/14516016
	echo "# Accepting Licenses"
	yes | ./cmdline-tools/latest/bin/sdkmanager --sdk_root=./ --licenses
fi

PATH="$(realpath ./cmdline-tools/latest/bin):$PATH"
export PATH

echo "# Install build-tools v36.0.0"
sdkmanager --sdk_root=./ "build-tools;36.0.0"

echo "# Install ndk v27.2.12479018"
sdkmanager --sdk_root=./ "ndk;27.2.12479018"

echo "# Install platform android-21"
sdkmanager --sdk_root=./ "platforms;android-21"
