#!/usr/bin/env python3
"""Applies ⅄music's Android customisations on top of `flutter create` output.

- copies android_overrides/ into android/
- sets minSdk 24
- wires a release signing config read from android/key.properties
  (falls back to debug signing when the file is missing)
"""
import pathlib
import re
import shutil
import sys

root = pathlib.Path(__file__).resolve().parent.parent
android = root / "android"
overrides = root / "android_overrides"

if not android.exists():
    sys.exit("android/ missing: run `flutter create --platforms=android .` first")

# 1. overrides
for src in overrides.rglob("*"):
    if src.is_file():
        dst = android / src.relative_to(overrides)
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)
        print("override", dst.relative_to(root))

# Remove any MainActivity generated under a different package path.
for f in (android / "app/src/main").rglob("MainActivity.*"):
    if "tech/varsen/ymusic" not in f.as_posix():
        f.unlink()
        print("removed stray", f.relative_to(root))

# 2/3. build.gradle.kts
gradle = android / "app/build.gradle.kts"
if not gradle.exists():
    sys.exit("expected android/app/build.gradle.kts (Kotlin DSL)")
s = gradle.read_text()

if "keystorePropertiesFile" not in s:
    s = "import java.io.FileInputStream\nimport java.util.Properties\n\n" + s
    s = s.replace(
        "\nandroid {",
        '''
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {''',
        1,
    )
    s = s.replace(
        "    buildTypes {",
        '''    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {''',
        1,
    )
    new, n = re.subn(
        r'signingConfig\s*=\s*signingConfigs\.getByName\("debug"\)',
        'signingConfig = if (keystorePropertiesFile.exists()) signingConfigs.getByName("release") else signingConfigs.getByName("debug")',
        s,
    )
    if n == 0:
        sys.exit("could not find the release signingConfig line in build.gradle.kts")
    s = new

s, n = re.subn(r"minSdk\s*=\s*[^\n]+", "minSdk = 24", s, count=1)
if n == 0:
    sys.exit("could not find minSdk in build.gradle.kts")

gradle.write_text(s)
print("---- android/app/build.gradle.kts ----")
print(s)
