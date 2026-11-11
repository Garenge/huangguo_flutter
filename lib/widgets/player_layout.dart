import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 根据播放页正文空间计算高度，供在线和本地播放共用。
class PlayerLayout extends StatelessWidget {
  final Widget Function(BuildContext context, double playerHeight) builder;

  const PlayerLayout({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final platform = Theme.of(context).platform;
          final desktop =
              platform == TargetPlatform.macOS ||
              platform == TargetPlatform.windows ||
              platform == TargetPlatform.linux;
          final idealHeight = constraints.maxWidth * 9 / 16;
          final height = desktop
              ? math.min(idealHeight, constraints.maxHeight * 0.65)
              : idealHeight;
          return builder(context, height);
        },
      ),
    );
  }
}
