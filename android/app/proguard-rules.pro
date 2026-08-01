# R8 / ProGuard rules for release builds.
#
# The Flutter engine and the plugins in use ship their own consumer rules, so
# this file only needs to cover what R8 cannot infer. Keep it small — every
# broad `-keep` here is code that can no longer be shrunk.

# Flutter's embedding is reached reflectively from the generated plugin
# registrant and from native code, so it must survive shrinking.
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.** { *; }

# Play Core is referenced by Flutter's deferred-components support. This app
# does not use deferred components, so the classes are absent at compile time
# and R8 would otherwise fail on the dangling references.
-dontwarn com.google.android.play.core.**
