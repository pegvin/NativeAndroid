#!/bin/sh

set -eu

APP_NAME='testapp'
APP_ID='org.yourorg.testapp'
APP_ID_PATH="$(echo $APP_ID | tr '.' '/')"
API_VER='21'

SOURCES_C='src/main.c'
SOURCES_JAVA='java/MainActivity.java java/MainLib.java'

BUILD=${BUILD:-'build'}
TARGET_ARCH=${TARGET_ARCH:-'arm64-v8a'} # Possbile Options: arm64-v8a, armeabi-v7a, x86, x86_64
APK_FILE="$APP_NAME\_$TARGET_ARCH.apk"

ANDROID_SDK=${ANDROID_SDK:-"$(realpath ~/android-sdk)"}
BUILD_TOOLS=${BUILD_TOOLS:-"$ANDROID_SDK/build-tools/36.0.0"}
NDK=${NDK:-"$ANDROID_SDK/ndk/27.2.12479018"}

CMD_1=${1:-}
CMD_2=${2:-}

show_help() {
	echo "Usage: $0 [command]"
	echo "Commands: clean/get-class-signature-jni <class_name>/adb-log(--clear)/adb-push(--run) or none to just build."
}

if [ "$CMD_1" = "clean" ]; then
	rm -rf "$BUILD"
	exit 0
elif [ "$CMD_1" = "get-class-signature-jni" ]; then
	if [ "$CMD_2" = "" ]; then
		echo "Please provide a Java class name! Example: android.text.Html"
		show_help
		exit 1
	fi
	javap --class-path "$BUILD/android.jar" -s -p "$CMD_2"
	exit 0
elif [ "$CMD_1" = "adb-log" ]; then
	if [ "$CMD_2" = "--clear" ]; then
		adb logcat --clear
	fi
	adb logcat -b all -v color "ActivityManager:V $APP_ID:V *:S"
	exit 0
elif [ "$CMD_1" = "adb-push" ]; then
	echo "# Install application on target device"
	adb install -r "$BUILD/$APK_FILE"
	if [ "$CMD_2" = "--run" ]; then
		echo "# Run application on target device"
		adb shell am start -n "$APP_ID/$("$BUILD_TOOLS/aapt" dump badging "$BUILD/$APK_FILE" | grep "launchable-activity" | cut -f 2 -d"'")"
	fi
	exit 0
elif [ "$CMD_1" = "help" ]; then
	show_help
	exit 0
elif ! [ "$CMD_1" = "" ]; then
	echo "Invalid command '$CMD_1'"
	show_help
	exit 1
fi

KERNEL=$(uname -s)

if [ "$KERNEL" = 'Linux' ]; then
	OS_NAME='linux-x86_64'
elif [ "$KERNEL" = 'Darwin' ]; then
	OS_NAME='darwin-x86_64'
elif [ "$KERNEL" = 'Windows_NT' ] || [ "$(uname -o)" = 'Cygwin' ]; then
	OS_NAME='windows-x86_64'
else
	echo "Unknown Host Operating System '$(uname -s)'"
	exit 1
fi

CFLAGS="-Wall -Wpedantic -Os -ffunction-sections -fdata-sections -fvisibility=hidden -fPIC"
CFLAGS="$CFLAGS -DAPP_ID=\"$APP_ID\""
CFLAGS="$CFLAGS -I$NDK/toolchains/llvm/prebuilt/$OS_NAME/sysroot/usr/include"
LFLAGS='-Wl,--gc-sections -s -lm -lGLESv3 -lEGL -landroid -llog -lOpenSLES -shared -uANativeActivity_onCreate'

if [ "$TARGET_ARCH" = 'arm64-v8a' ]; then
	CC="$NDK/toolchains/llvm/prebuilt/$OS_NAME/bin/aarch64-linux-android$API_VER-clang"
	CFLAGS="$CFLAGS -m64"
	LFLAGS="-L$NDK/toolchains/llvm/prebuilt/$OS_NAME/sysroot/usr/lib/aarch64-linux-android/$API_VER $LFLAGS"
elif [ "$TARGET_ARCH" = 'armeabi-v7a' ]; then
	CC="$NDK/toolchains/llvm/prebuilt/$OS_NAME/bin/armv7a-linux-androideabi$API_VER-clang"
	CFLAGS="$CFLAGS -mfloat-abi=softfp -m32"
	LFLAGS="-L$NDK/toolchains/llvm/prebuilt/$OS_NAME/sysroot/usr/lib/arm-linux-androideabi/$API_VER $LFLAGS"
elif [ "$TARGET_ARCH" = 'x86' ]; then
	CC="$NDK/toolchains/llvm/prebuilt/$OS_NAME/bin/i686-linux-android$API_VER-clang"
	CFLAGS="$CFLAGS -march=i686 -mssse3 -mfpmath=sse -m32"
	LFLAGS="-L$NDK/toolchains/llvm/prebuilt/$OS_NAME/sysroot/usr/lib/i686-linux-android/$API_VER $LFLAGS"
elif [ "$TARGET_ARCH" = 'x86_64' ]; then
	CC="$NDK/toolchains/llvm/prebuilt/$OS_NAME/bin/x86_64-linux-android$API_VER-clang"
	CFLAGS="$CFLAGS -march=x86-64 -msse4.2 -mpopcnt -m64"
	LFLAGS="-L$NDK/toolchains/llvm/prebuilt/$OS_NAME/sysroot/usr/lib/x86_64-linux-android/$API_VER $LFLAGS"
else
	echo "Invalid Target Architecture '$TARGET_ARCH'"
	exit 1
fi

if [ -x "$(command -v bear)" ]; then BEAR="bear --append --output $BUILD/compile_commands.json --"; else BEAR=""; fi

# Copy or download required android.jar
if ! [ -f "$BUILD/android.jar" ]; then
	echo "# Get android.jar"
	mkdir -p "$BUILD"
	cp "$ANDROID_SDK/platforms/android-$API_VER/android.jar" "$BUILD/android.jar" || wget -q --show-progress "https://github.com/Sable/android-platforms/raw/refs/heads/master/android-$API_VER/android.jar" -O "$BUILD/android.jar"
fi

# Generate .keystore file if required
if ! [ -f "$BUILD/my-release-key.keystore" ]; then
	echo "# Generate my-release-key.keystore"
	mkdir -p "$BUILD"
	keytool -genkey -v -keystore "$BUILD/my-release-key.keystore" -alias standkey -keyalg RSA -keysize 2048 -validity 10000 -storepass password -keypass password -dname "CN=example.com, OU=ID, O=Example, L=Doe, S=John, C=GB"
fi

# Compile Java source
echo "# Generate R.java"
mkdir -p "$BUILD/gen/"
"$BUILD_TOOLS/aapt" package -f -m -J "$BUILD/gen/" -S res -M AndroidManifest.xml -I "$BUILD/android.jar"

echo "# Compile Java Code To JVM Bytecode"
mkdir -p "$BUILD/obj" "$BUILD/apk"
javac --release 11 \
	-classpath "$BUILD/android.jar" \
	-d "$BUILD/obj" "$BUILD/gen/$APP_ID_PATH/R.java" \
	$SOURCES_JAVA # Note: It seems that on Windows classpath separator is ; & on Linux it's : This might mess up things, So thought of adding this to make sure I don't kill myself over this

echo "# Convert JVM Bytecode To DEX Bytecode"
"$BUILD_TOOLS/d8" --release --lib "$BUILD/android.jar" --output "$BUILD/apk/" "$BUILD/obj/$APP_ID_PATH/"*.class

# Compile C source
echo "# Compile $SOURCES_C To Native Code"
mkdir -p "$BUILD/apk/lib/$TARGET_ARCH"
$BEAR "$CC" \
	"-DJNI_FUNC(return, class, name)=JNIEXPORT return JNICALL Java_$(echo $APP_ID | tr '.' '_')_##class##_##name(JNIEnv *env, jobject obj)" \
	$CFLAGS -o "$BUILD/apk/lib/$TARGET_ARCH/lib$APP_NAME.so" $SOURCES_C $LFLAGS

# Build apk
echo "# Build APK"
"$BUILD_TOOLS/aapt" package -f -M AndroidManifest.xml -S res/ -I "$BUILD/android.jar" -F "$BUILD/$APK_FILE.unsigned" "$BUILD/apk/"

echo "# Align APK On 4-Byte Boundaries"
"$BUILD_TOOLS/zipalign" -f -p 4 "$BUILD/$APK_FILE.unsigned" "$BUILD/$APK_FILE.aligned"

echo "# Sign APK"
"$BUILD_TOOLS/apksigner" sign --key-pass pass:password --ks-pass pass:password --ks "$BUILD/my-release-key.keystore" --out "$BUILD/$APK_FILE" "$BUILD/$APK_FILE.aligned"
