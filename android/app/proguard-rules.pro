# Flutter
-keep class io.flutter.** { *; }
-keep class com.google.firebase.** { *; }

# Paystack WebView
-keepattributes JavascriptInterface
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# QR Scanner
-keep class com.google.mlkit.** { *; }

# Flutter references Play Core internally for deferred components
# don't need dynamic delivery so safe to suppress.
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }