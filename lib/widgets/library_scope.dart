import 'package:flutter/widgets.dart';

import '../services/library_service.dart';

class LibraryScope extends InheritedNotifier<LibraryService> {
  const LibraryScope({
    super.key,
    required LibraryService library,
    required super.child,
  }) : super(notifier: library);

  static LibraryService? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LibraryScope>()?.notifier;
}
