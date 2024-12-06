adb shell am force-stop net.osmand

adb push wuzz.render.xml /sdcard/Android/data/net.osmand/files/rendering
adb push pranatahouse.render.xml /sdcard/Android/data/net.osmand/files/rendering

adb shell am start -n net.osmand/.plus.activities.MapActivity

@REM pause
