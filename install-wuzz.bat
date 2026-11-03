@REM pindah ke direktori skrip ini
cd /d "%~dp0"

adb shell am force-stop net.osmand

adb push styles\wuzz.render.xml /sdcard/Android/data/net.osmand/files/rendering

adb shell am start -n net.osmand/.plus.activities.MapActivity

@REM pause
