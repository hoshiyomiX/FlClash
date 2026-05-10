# Consumer rules for app module — keep AIDL interfaces from service
-keep class com.follow.clash.service.I*Interface { *; }
-keep class com.follow.clash.service.I*Interface$Stub { *; }
-keep class com.follow.clash.service.I*Interface$Stub$Proxy { *; }
