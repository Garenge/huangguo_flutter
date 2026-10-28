# huangguo_flutter

Flutter 短剧浏览、在线播放与下载管理应用。

## 播放器

在线播放和下载播放统一使用 `lib/widgets/app_video_player.dart`。
页面负责解析地址、创建与释放 `VideoPlayerController`，公共组件负责手势、
控制栏、全屏路由和屏幕方向；全屏切集通过共享状态更新，不重新进出全屏。

- 单击画面显示或隐藏控制栏；播放时 3 秒无操作自动隐藏，暂停时保持显示。
- 双击画面或点击全屏按钮进入横屏全屏；返回后恢复竖屏。
- 左右滑动预览目标时间，松手执行一次跳转；一屏最多调整 120 秒。
- 拖动进度条显示时间预览，结束后恢复拖动前的播放或暂停状态。
- 播放时长按临时使用 2 倍速，松开、取消或进入后台时恢复原倍速。
- 全屏快速上滑下一集、下滑上一集；内嵌模式保留页面纵向滚动。
- 支持倍速选择、缓冲进度、播放错误重试；离线播完停留，可点击播放重播。

历史进度只在进入对应剧集时恢复，手动或自动切集从头播放。
当前预览为时间预览，尚未实现视频缩略帧；保留在线 HLS、
本地视频文件和本地 HTTP 服务播放离线 HLS 的原有路径。

## 验证

```sh
flutter analyze --no-pub --no-fatal-infos
flutter test --no-pub
flutter build ios --debug --no-codesign --no-pub
```

播放器测试覆盖控制栏显隐、进度拖动、取消手势、临时倍速恢复、
全屏源更新及窄屏布局。实际解码、网络片源与真机旋转仍需在设备上验收。

本机 Xcode 27 要求部署版本至少为 iOS 15，现有 Runner/Pods 的旧部署版本会
阻止默认 iOS 构建。此次仅用以下命令临时覆盖部署版本完成无签名编译验证，
未修改工程的最低系统版本；正式兼容范围仍需单独确定。

```sh
xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner \
  -configuration Debug -sdk iphoneos -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO IPHONEOS_DEPLOYMENT_TARGET=15.0 build
```
