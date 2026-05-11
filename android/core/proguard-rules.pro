# Core module — JNI keep rules
# Prevent R8 full mode from removing classes accessed by native code

# Keep Core companion object — System.loadLibrary + all native method bindings
-keep class com.follow.clash.core.Core { *; }

# Keep JNI callback interfaces (annotated @Keep, but belt-and-suspenders for R8 full mode)
-keep class com.follow.clash.core.InvokeInterface { *; }
-keep class com.follow.clash.core.TunInterface { *; }

# Keep anything with @Keep annotation
-keep @androidx.annotation.Keep class * { *; }
-keepclassmembers class * {
    @androidx.annotation.Keep *;
}
