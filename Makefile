APP_NAME     = testapp
APP_ID       = org.yourorg.testapp
APP_ID_PATH  = $(subst .,/,$(APP_ID))
API_VER      = 30
SOURCES_C    = src/main.c
SOURCES_JAVA = java/$(APP_ID_PATH)/MainActivity.java
ANDROID_SDK  = $(shell realpath ~/Android/Sdk)
JBR_BIN      = $(shell realpath ~/android-studio/jbr/bin)
BUILD_TOOLS  = $(ANDROID_SDK)/build-tools/36.0.0
NDK          = $(ANDROID_SDK)/ndk/29.0.13599879
PLATFORM     = $(ANDROID_SDK)/platforms/android-$(API_VER)
BUILD        = build
# Possbile Options: arm64-v8a, armeabi-v7a, x86, x86_64
TARGET_ARCH  = arm64-v8a

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
CFLAGS+=-D"JNI_FUNC(return, class, name)=JNIEXPORT return JNICALL Java_$(subst .,_,$(APP_ID))_\#\#class\#\#_\#\#name(JNIEnv *env, jobject obj)"
CFLAGS+=-I$(NDK)/sysroot/usr/include -I$(NDK)/sysroot/usr/include/android -I$(NDK)/toolchains/llvm/prebuilt/$(OS_NAME)/sysroot/usr/include -I$(NDK)/toolchains/llvm/prebuilt/$(OS_NAME)/sysroot/usr/include/android
LFLAGS=-Wl,--gc-sections -Wl,-Map=output.map -s -lm -lGLESv3 -lEGL -landroid -llog -lOpenSLES -shared -uANativeActivity_onCreate

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

java/$(APP_ID_PATH)/*.java: R_java $(BUILD)/aar/activity_1.10.1.aar
	@mkdir -p $(BUILD)/obj $(BUILD)/apk
	@echo "# Compile Java Code To Bytecode for JVM"
	@$(JBR_BIN)/javac --release 11 \
		-classpath "$(PLATFORM)/android.jar:$(BUILD)/aar/activity_1.10.1/classes.jar" \
		-d $(BUILD)/obj $(BUILD)/gen/$(APP_ID_PATH)/R.java \
		java/$(APP_ID_PATH)/MainActivity.java # Note: It seems that on Windows classpath separator is ; & on Linux it's : This might mess up things, So thought of adding this to make sure I don't kill myself over this
	@echo "# Convert JVM Bytecode To DEX Bytecode"
	@PATH="$(JBR_BIN):$$PATH" $(BUILD_TOOLS)/d8 --release --lib $(PLATFORM)/android.jar --output $(BUILD)/apk/ build/obj/$(APP_ID_PATH)/*.class

$(BUILD)/apk/lib/$(TARGET_ARCH)/lib$(APP_NAME).so: $(SOURCES_C)
	@echo "# Compile $^ To Native Code"
	@mkdir -p $(BUILD)/apk/lib/$(TARGET_ARCH)
	@bear --append --output $(BUILD)/compile_commands.json -- $(CC) $(CFLAGS) -o $@ $^ $(LFLAGS)

all: my-release-key.keystore dex_files so_files
	@echo "# Build APK"
	@$(BUILD_TOOLS)/aapt package -f -M AndroidManifest.xml -S res/ -I $(PLATFORM)/android.jar -F $(BUILD)/$(APK_FILE).unsigned $(BUILD)/apk/
	@echo "# Align APK On 4-Byte Boundaries"
	@$(BUILD_TOOLS)/zipalign -f -p 4 $(BUILD)/$(APK_FILE).unsigned $(BUILD)/$(APK_FILE).aligned
	@echo "# Sign APK"
	@PATH="$(JBR_BIN):$$PATH" $(BUILD_TOOLS)/apksigner sign --key-pass pass:password --ks-pass pass:password --ks my-release-key.keystore --out $(BUILD)/$(APK_FILE) $(BUILD)/$(APK_FILE).aligned

so_files: $(BUILD)/apk/lib/$(TARGET_ARCH)/lib$(APP_NAME).so
dex_files: $(SOURCES_JAVA)

R_java: AndroidManifest.xml
	@echo "# Generate R.java"
	@mkdir -p $(BUILD)/gen/
	@$(BUILD_TOOLS)/aapt package -f -m -J $(BUILD)/gen/ -S res -M AndroidManifest.xml -I $(PLATFORM)/android.jar

$(BUILD)/aar/activity_1.10.1.aar:
	@echo "# Download $@"
	@mkdir -p $(BUILD)/aar/ $(basename $@)
	@curl -L "https://dl.google.com/android/maven2/androidx/activity/activity/1.10.1/activity-1.10.1.aar" --output $@
	@unzip -d $(basename $@) $@

my-release-key.keystore:
	@echo "# Generate my-release-key.keystore"
	@$(JBR_BIN)/keytool -genkey -v -keystore $@ -alias standkey -keyalg RSA -keysize 2048 -validity 10000 -storepass password -keypass password -dname "CN=example.com, OU=ID, O=Example, L=Doe, S=John, C=GB"

.PHONY: clean
clean:
	@echo "# Clean"
	@$(RM) -rf $(BUILD) my-release-key.keystore

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
jni-call:
	$(eval class_name := $(if $(class_name),$(class_name),android.text.Html))
	@$(JBR_BIN)/javap --class-path "$(PLATFORM)/android.jar" -s -p "$(class_name)"
