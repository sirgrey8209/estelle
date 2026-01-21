@echo off
set "JAVA_HOME=C:\Program Files\Microsoft\jdk-17.0.17.10-hotspot"
set "ANDROID_HOME=C:\Users\sirgreyLocal\AppData\Local\Android\Sdk"
set "PATH=%JAVA_HOME%\bin;%ANDROID_HOME%\platform-tools;%PATH%"
cd /d C:\WorkSpace\estelle\estelle-mobile
call C:\WorkSpace\estelle\estelle-mobile\gradlew.bat assembleDebug --no-daemon
