# Preserve flutter_local_notifications scheduled alarm models and receivers in release R8 builds.
-keep class com.dexterous.** { *; }
-keepclassmembers class com.dexterous.** { *; }
-keep enum com.dexterous.** { *; }

# Preserve Gson deserialization metadata for NotificationDetails JSON extras.
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
