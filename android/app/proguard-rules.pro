# ML Kit Text Recognition Proguard Rules
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.mlkit.**
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
-keep class com.google_mlkit_text_recognition.** { *; }

# StudentHub Application, Activities and Home Screen Widget Providers
-keep class com.example.studenthold_app.** { *; }
-keep class es.antonborri.home_widget.** { *; }
-keep class com.dexterous.flutterlocalnotifications.** { *; }
