#include <stdlib.h>
#include <jni.h>
#include <android/log.h>

#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, APP_ID, __VA_ARGS__)
#define LOGW(...) __android_log_print(ANDROID_LOG_WARN,  APP_ID, __VA_ARGS__)
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO,  APP_ID, __VA_ARGS__)
#define LOGD(...) __android_log_print(ANDROID_LOG_DEBUG, APP_ID, __VA_ARGS__)

static const char *const messages[] = {
	"Hello, world!",
	"Hej världen!",
	"Bonjour, monde!",
	"Hallo Welt!"
};

JNI_FUNC(jstring, MainLib, getMessage) {
	LOGE("MainLib.getMessage() called!");

	#define SZ 1000
	int i = rand() % (sizeof(messages) / sizeof(messages[0]));
	char buf[SZ] = {0};
	snprintf(buf, SZ, "%s - %d", messages[i], rand());
	jstring str = (*env)->NewStringUTF(env, buf);

	return str;
}
