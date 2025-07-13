# Add project specific ProGuard rules here.
# You can control the set of applied configuration files using the
# proguardFiles setting in build.gradle.

# For more details, see
#   http://developer.android.com/guide/developing/tools/proguard.html

# If your project uses WebView with JS, uncomment the following
# and specify the fully qualified class name to the JavaScript interface
# class:
#-keepclassmembers class fqcn.of.javascript.interface.for.webview {
#   public *;
#}

# Uncomment this to preserve the line number information for
# debugging stack traces.
#-keepattributes SourceFile,LineNumberTable

# If you keep the line number information, uncomment this to
# hide the original source file name.
#-renamesourcefileattribute SourceFile

# ============ LITERT-LM / MEDIAPIPE GENAI RULES ============
# Keep all MediaPipe GenAI classes and methods
-keep class com.google.mediapipe.tasks.genai.** { *; }
-keep interface com.google.mediapipe.tasks.genai.** { *; }

# Keep LLM Inference API classes
-keep class com.google.mediapipe.tasks.genai.llminference.** { *; }

# Keep Google AI Edge LiteRT classes (modern replacement for TensorFlow Lite)
-keep class com.google.ai.edge.litert.** { *; }
-keep interface com.google.ai.edge.litert.** { *; }

# Keep native methods and JNI interfaces
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep MediaPipe framework classes
-keep class com.google.mediapipe.framework.** { *; }
-keep class com.google.mediapipe.calculator.** { *; }

# Keep protobuf classes (used by MediaPipe)
-keep class com.google.protobuf.** { *; }
-dontwarn com.google.protobuf.**

# ============ KOTLIN COROUTINES ============
# Keep coroutines classes
-keep class kotlinx.coroutines.** { *; }
-dontwarn kotlinx.coroutines.**

# ============ GEMMA MODEL RUNNER ============
# Keep our custom GemmaLiteRTRunner class (real LiteRT implementation)
-keep class com.example.test_gemma3n_flutter.GemmaLiteRTRunner { *; }
# Keep legacy mock runner for backwards compatibility
-keep class com.example.test_gemma3n_flutter.GemmaLiteRunner { *; }

# ============ FLUTTER INTEGRATION ============
# Keep Flutter MethodChannel classes
-keep class io.flutter.plugin.common.** { *; }
-keep class io.flutter.embedding.** { *; }

# ============ ANDROID PERFORMANCE ============
# Keep classes related to performance monitoring
-keep class android.os.** { *; }
-keep class java.lang.Runtime { *; }

# ============ GENERAL ANDROID RULES ============
# Keep custom Application class
-keep public class * extends android.app.Application

# Keep activity classes
-keep public class * extends android.app.Activity
-keep public class * extends androidx.fragment.app.Fragment

# Keep annotation classes
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# Keep enums
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Keep serialization classes
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# ============ SUPPRESS WARNINGS ============
# Suppress warnings for optional dependencies
-dontwarn javax.annotation.**
-dontwarn org.checkerframework.**
-dontwarn edu.umd.cs.findbugs.annotations.**