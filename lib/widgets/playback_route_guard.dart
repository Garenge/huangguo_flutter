import 'package:flutter/widgets.dart';

import '../services/playback_session.dart';

/// Page routes affect playback; menus/dialogs and the player's fullscreen
/// transition do not count as leaving the video.
class PlaybackRouteGuard extends StatefulWidget {
  const PlaybackRouteGuard({
    super.key,
    required this.child,
    this.session,
    this.ignoreCover,
  });

  final Widget child;
  final PlaybackSession? session;
  final bool Function()? ignoreCover;

  @override
  State<PlaybackRouteGuard> createState() => _PlaybackRouteGuardState();
}

class _PlaybackRouteGuardState extends State<PlaybackRouteGuard>
    with RouteAware {
  RouteObserver<PageRoute<dynamic>>? _observer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _observer?.unsubscribe(this);
    final observers = Navigator.of(
      context,
    ).widget.observers.whereType<RouteObserver<PageRoute<dynamic>>>();
    _observer = observers.isEmpty ? null : observers.first;
    final route = ModalRoute.of(context);
    if (route is PageRoute<dynamic>) _observer?.subscribe(this, route);
  }

  @override
  void didPushNext() {
    if (widget.ignoreCover?.call() != true) {
      widget.session?.setRouteVisible(false);
    }
  }

  @override
  void didPopNext() => widget.session?.setRouteVisible(true);

  @override
  void dispose() {
    _observer?.unsubscribe(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
