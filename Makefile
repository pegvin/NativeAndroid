APP_NAME     = testapp
APP_ID       = org.yourorg.testapp
APP_ID_PATH  = $(subst .,/,$(APP_ID))
API_VER      = 21
SOURCES_C    = src/main.c
SOURCES_JAVA = java/MainActivity.java java/MainLib.java
ANDROID_SDK  = $(shell realpath ~/android-sdk)
BUILD_TOOLS  = $(ANDROID_SDK)/build-tools/36.0.0
NDK          = $(ANDROID_SDK)/ndk/27.2.12479018
BUILD        = build
# Possbile Options: arm64-v8a, armeabi-v7a, x86, x86_64
TARGET_ARCH  = arm64-v8a

BEAR =
ifneq (,$(shell which bear))
	BEAR=bear --append --output $(BUILD)/compile_commands.json --
endif

ifeq ($(shell uname),Linux)
	OS_NAME=linux-x86_64
else ifeq ($(shell uname),Darwin)
	OS_NAME=darwin-x86_64
else ifeq ($(OS),Windows_NT)
	OS_NAME=windows-x86_64
else
$(error Failed to detect the operating system)
endif

CFLAGS=-ffunction-sections -Os -fdata-sections -Wall -Wpedantic -fvisibility=hidden -fPIC -DAPP_ID=\"$(APP_ID)\"
CFLAGS+=-D'JNI_FUNC(return, class, name)=JNIEXPORT return JNICALL Java_$(subst .,_,$(APP_ID))_\#\#class\#\#_\#\#name(JNIEnv *env, jobject obj)'
CFLAGS+=-I$(NDK)/toolchains/llvm/prebuilt/$(OS_NAME)/sysroot/usr/include
LFLAGS=-Wl,--gc-sections -s -lm -lGLESv3 -lEGL -landroid -llog -lOpenSLES -shared -uANativeActivity_onCreate

TARGET=$(BUILD)/lib/$(TARGET_ARCH)/lib$(APP_NAME).so
APK_FILE=$(APP_NAME)_$(TARGET_ARCH).apk

ifeq ($(TARGET_ARCH),arm64-v8a)
	CC=$(NDK)/toolchains/llvm/prebuilt/$(OS_NAME)/bin/aarch64-linux-android$(API_VER)-clang
	CFLAGS:=$(CFLAGS) -m64
	LFLAGS:=-L$(NDK)/toolchains/llvm/prebuilt/$(OS_NAME)/sysroot/usr/lib/aarch64-linux-android/$(API_VER) $(LFLAGS)
else ifeq ($(TARGET_ARCH),armeabi-v7a)
	CC=$(NDK)/toolchains/llvm/prebuilt/$(OS_NAME)/bin/armv7a-linux-androideabi$(API_VER)-clang
	CFLAGS:=$(CFLAGS) -mfloat-abi=softfp -m32
	LFLAGS:=-L$(NDK)/toolchains/llvm/prebuilt/$(OS_NAME)/sysroot/usr/lib/arm-linux-androideabi/$(API_VER) $(LFLAGS)
else ifeq ($(TARGET_ARCH),x86)
	CC=$(NDK)/toolchains/llvm/prebuilt/$(OS_NAME)/bin/i686-linux-android$(API_VER)-clang
	CFLAGS:=$(CFLAGS) -march=i686 -mssse3 -mfpmath=sse -m32
	LFLAGS:=-L$(NDK)/toolchains/llvm/prebuilt/$(OS_NAME)/sysroot/usr/lib/i686-linux-android/$(API_VER) $(LFLAGS)
else ifeq ($(TARGET_ARCH),x86_64)
	CC=$(NDK)/toolchains/llvm/prebuilt/$(OS_NAME)/bin/x86_64-linux-android$(API_VER)-clang
	CFLAGS:=$(CFLAGS) -march=x86-64 -msse4.2 -mpopcnt -m64
	LFLAGS:=-L$(NDK)/toolchains/llvm/prebuilt/$(OS_NAME)/sysroot/usr/lib/x86_64-linux-android/$(API_VER) $(LFLAGS)
else
$(error Invalid target architecture)
endif

$(BUILD)/android.jar:
	@echo "# Get android.jar"
	@mkdir -p $(BUILD)
	@cp $(ANDROID_SDK)/platforms/android-$(API_VER)/android.jar $(BUILD)/android.jar || wget "https://github.com/Sable/android-platforms/raw/refs/heads/master/android-$(API_VER)/android.jar" -O $(BUILD)/android.jar

java_files: $(BUILD)/android.jar AndroidManifest.xml $(SOURCES_JAVA)
	@echo "# Generate R.java"
	@mkdir -p $(BUILD)/gen/
	@$(BUILD_TOOLS)/aapt package -f -m -J $(BUILD)/gen/ -S res -M AndroidManifest.xml -I $(BUILD)/android.jar
	@echo "# Compile Java Code To JVM Bytecode"
	@mkdir -p $(BUILD)/obj $(BUILD)/apk
	@javac --release 11 \
		-classpath "$(BUILD)/android.jar" \
		-d $(BUILD)/obj $(BUILD)/gen/$(APP_ID_PATH)/R.java \
		$(SOURCES_JAVA) # Note: It seems that on Windows classpath separator is ; & on Linux it's : This might mess up things, So thought of adding this to make sure I don't kill myself over this
	@echo "# Convert JVM Bytecode To DEX Bytecode"
	@$(BUILD_TOOLS)/d8 --release --lib $(BUILD)/android.jar --output $(BUILD)/apk/ $(BUILD)/obj/$(APP_ID_PATH)/*.class

c_files: $(SOURCES_C)
	@echo "# Compile $^ To Native Code"
	@mkdir -p $(BUILD)/apk/lib/$(TARGET_ARCH)
	@$(BEAR) $(CC) $(CFLAGS) -o $(BUILD)/apk/lib/$(TARGET_ARCH)/lib$(APP_NAME).so $^ $(LFLAGS)

$(BUILD)/my-release-key.keystore:
	@echo "# Generate my-release-key.keystore"
	@mkdir -p $(BUILD)
	@keytool -genkey -v -keystore $@ -alias standkey -keyalg RSA -keysize 2048 -validity 10000 -storepass password -keypass password -dname "CN=example.com, OU=ID, O=Example, L=Doe, S=John, C=GB"

all: c_files java_files $(BUILD)/my-release-key.keystore
	@echo "# Build APK"
	@$(BUILD_TOOLS)/aapt package -f -M AndroidManifest.xml -S res/ -I $(BUILD)/android.jar -F $(BUILD)/$(APK_FILE).unsigned $(BUILD)/apk/
	@echo "# Align APK On 4-Byte Boundaries"
	@$(BUILD_TOOLS)/zipalign -f -p 4 $(BUILD)/$(APK_FILE).unsigned $(BUILD)/$(APK_FILE).aligned
	@echo "# Sign APK"
	@$(BUILD_TOOLS)/apksigner sign --key-pass pass:password --ks-pass pass:password --ks $(BUILD)/my-release-key.keystore --out $(BUILD)/$(APK_FILE) $(BUILD)/$(APK_FILE).aligned

.PHONY: clean
clean:
	@echo "# Clean"
	@$(RM) -rf $(BUILD)

push: all
	@echo "# Install APK On Target Devices"
	@adb install -r $(BUILD)/$(APK_FILE)

run: push
	@echo "# Send Run Command On Target Devices"
	$(eval ACTIVITYNAME:=$(shell $(BUILD_TOOLS)/aapt dump badging $(BUILD)/$(APK_FILE) | grep "launchable-activity" | cut -f 2 -d"'"))
	@adb shell am start -n $(APP_ID)/$(ACTIVITYNAME)

adb-log-clear:
	@adb logcat --clear

adb-log:
	@adb logcat -b all -v color "ActivityManager:V $(APP_ID):V *:S"

# Convert Class Name To Something Usable By JNI
# Usage: make jni-call class_name=android.text.AutoText
jni-call: $(BUILD)/android.jar
	$(eval class_name := $(if $(class_name),$(class_name),android.text.Html))
	@javap --class-path "$(BUILD)/android.jar" -s -p "$(class_name)"
