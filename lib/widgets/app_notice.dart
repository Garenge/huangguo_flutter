import 'dart:async';

import 'package:flutter/material.dart';

OverlayEntry? _activeNoticeEntry;
Timer? _noticeTimer;

/// 统一的应用内顶部通知，避免提示遮挡底部操作区域。
void showAppNotice(
  BuildContext context,
  String message, {
  Color? backgroundColor,
  SnackBarAction? action,
  Duration duration = const Duration(seconds: 2),
}) {
  _noticeTimer?.cancel();
  _activeNoticeEntry?.remove();

  final width = MediaQuery.sizeOf(context).width;
  final horizontal = width * 0.15;
  final top = MediaQuery.paddingOf(context).top + 12;
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => Positioned(
      top: top,
      left: horizontal,
      right: horizontal,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
          decoration: BoxDecoration(
            color: backgroundColor ?? const Color(0xFF303030),
            borderRadius: BorderRadius.circular(10),
            boxShadow: const [
              BoxShadow(color: Color(0x55000000), blurRadius: 12, offset: Offset(0, 4)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (action != null)
                TextButton(onPressed: action.onPressed, child: Text(action.label)),
            ],
          ),
        ),
      ),
    ),
  );
  _activeNoticeEntry = entry;
  Overlay.of(context, rootOverlay: true).insert(entry);
  _noticeTimer = Timer(duration, () {
    if (entry.mounted) entry.remove();
    if (identical(_activeNoticeEntry, entry)) _activeNoticeEntry = null;
  });
}
