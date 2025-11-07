# --- Razorpay keep rules ---
-keep class com.razorpay.** { *; }
-dontwarn com.razorpay.**

# Annotations & reflection
-keepattributes *Annotation*
-dontwarn proguard.annotation.**
-keep class proguard.annotation.** { *; }

# Payment callbacks via reflection
-keepclasseswithmembers class * {
    public void onPayment*(...);
}
