# pindah ke direktori skrip ini
cd "$(dirname "$0")"

# update rendering di osmand android
adb shell am force-stop net.osmand
adb push wuzz.render.xml /sdcard/Android/data/net.osmand/files/rendering
adb shell am start -n net.osmand/.plus.activities.MapActivity
