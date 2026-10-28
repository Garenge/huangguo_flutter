import 'package:flutter/foundation.dart';

class AppLog {
  final String tag;

  const AppLog(this.tag);

  void d(String msg) => debugPrint('[\u001b[36m$tag\u001b[0m] $msg');
  void i(String msg) => debugPrint('[\u001b[32m$tag\u001b[0m] $msg');
  void w(String msg) => debugPrint('[\u001b[33m$tag\u001b[0m] ⚠ $msg');
  void e(String msg, [Object? error, StackTrace? stack]) {
    debugPrint('[\u001b[31m$tag\u001b[0m] ❌ $msg');
    if (error != null) debugPrint('   error: $error');
    if (stack != null) debugPrint('   stack: $stack');
  }
}
