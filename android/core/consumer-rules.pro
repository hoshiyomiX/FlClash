# Consumer rules for core module — propagate JNI keep rules to app
-keep class com.follow.clash.core.Core { *; }
-keep class com.follow.clash.core.InvokeInterface { *; }
-keep class com.follow.clash.core.TunInterface { *; }
-keep @androidx.annotation.Keep class * { *; }
-keepclassmembers class * {
    @androidx.annotation.Keep *;
}
