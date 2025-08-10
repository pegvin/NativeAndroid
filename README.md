# NativeAndroid
Build Native Android Apps In C + Java, Without Gradle or
Android _Studio_.

---

This repository is a minimal example of building Android Apps
using C & Java without requiring Android Studio or Gradle in
the hopes of making it easier to port an already existing app
written in C/C++ to Android.

Few key points to note:
- You can build Android Apps using just C/C++, But I decided
  to include Java because Android APIs are only usable via
  Java, And whilst you can use JNI to interact with those
  APIs, The truth is that JNI is very messy & should be avoided
  as much as possible. This means that you should separate your
  code that interacts with Android APIs into Java Functions &
  then call those functions from C/C++ using JNI.
- Android Studio projects use `gradle` build system, which
  does all the dependency management for you. But this example
  uses a stupidly simple `Makefile`, Which means using libraries
  like AndroidX is not feasible but other self-sufficient
  libraries shouldn't be a hassle.
- Whilst you don't need Android Studio as promised, You will
  still need Android SDK. If you're on Linux you can run
  `setup_android.sh` which will install required SDK into your
  current working directory.

More technical aspects will be on my blog post soon.

---

# Thanks
