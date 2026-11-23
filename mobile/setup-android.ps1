# One-time setup for the Flutter app: adds the android folder, internet permission and a safe memory setting.
Set-Location $PSScriptRoot
if (-not (Test-Path "android")) { flutter create --platforms=android . }
$f = "android\app\src\main\AndroidManifest.xml"
$t = Get-Content $f -Raw
if ($t -notmatch "android.permission.INTERNET") {
  $t = $t.Replace("<application", "<uses-permission android:name=`"android.permission.INTERNET`"/>`n    <application android:usesCleartextTraffic=`"true`"")
  Set-Content $f $t
}
$g = "android\gradle.properties"
if (Test-Path $g) { (Get-Content $g) -replace '-Xmx8G','-Xmx2G' -replace 'MaxMetaspaceSize=4G','MaxMetaspaceSize=1G' -replace 'ReservedCodeCacheSize=512m','ReservedCodeCacheSize=256m' | Set-Content $g }
flutter pub get
