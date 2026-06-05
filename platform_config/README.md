# 平台原生設定片段

本機尚未安裝 Flutter，因此 `android/` 與 `ios/` native runner 尚未生成。
安裝 Flutter 後請執行：

```bash
flutter create . --org com.anaglobe --platforms android,ios
```

接著依下列片段補上權限（規格 §7.1）。

---

## Android — `android/app/src/main/AndroidManifest.xml`

於 `<manifest>` 內、`<application>` 之外加入：

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.USE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>
<uses-permission android:name="android.permission.CAMERA"/>
```

於 `<application>` 內，加入 flutter_local_notifications 的 receiver（精確鬧鐘）：

```xml
<receiver android:exported="false"
    android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"/>
<receiver android:exported="false"
    android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
  <intent-filter>
    <action android:name="android.intent.action.BOOT_COMPLETED"/>
    <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
    <action android:name="android.intent.action.QUICKBOOT_POWERON"/>
    <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
  </intent-filter>
</receiver>
```

`compileSdk` / `targetSdk` 建議 34（Android 14）；`minSdk` 21 以上。
url_launcher 撥號需在 `<queries>` 宣告：

```xml
<queries>
  <intent>
    <action android:name="android.intent.action.VIEW" />
    <data android:scheme="https" />
  </intent>
  <intent>
    <action android:name="android.intent.action.DIAL" />
    <data android:scheme="tel" />
  </intent>
  <intent>
    <action android:name="android.intent.action.VIEW" />
    <data android:scheme="geo" />
  </intent>
</queries>
```

---

## iOS — `ios/Runner/Info.plist`

於 `<dict>` 內加入：

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>用於在旅遊札記中附加相片。</string>
<key>NSCameraUsageDescription</key>
<string>用於在旅遊札記中拍攝相片。</string>
<key>LSApplicationQueriesSchemes</key>
<array>
  <string>tel</string>
  <string>maps</string>
  <string>comgooglemaps</string>
</array>
```

通知權限於執行期由 `flutter_local_notifications` 請求（見 `notification_service.dart`）。
`ios/Runner/AppDelegate.swift` 需註冊通知；deployment target 建議 12.0+。

```

```
