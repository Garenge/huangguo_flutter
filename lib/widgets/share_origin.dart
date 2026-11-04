import 'package:flutter/widgets.dart';

/// 使用当前 Flutter 窗口中心作为分享锚点，不依赖异步操作前的按钮布局。
Rect shareOriginFor(BuildContext context) {
  final view = View.of(context);
  final size = view.physicalSize / view.devicePixelRatio;
  return Rect.fromCenter(center: size.center(Offset.zero), width: 1, height: 1);
}
