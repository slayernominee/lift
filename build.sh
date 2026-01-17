#!/bin/bash

# test
flutter test

# android
flutter build apk --release --no-tree-shake-icons
shasum -a 256 build/app/outputs/flutter-apk/app-release.apk > build/app/outputs/flutter-apk/app-release.apk.sha256
flutter build appbundle --no-tree-shake-icons
