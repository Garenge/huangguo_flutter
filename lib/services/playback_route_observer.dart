import 'package:flutter/widgets.dart';

final playbackRootObserver = RouteObserver<PageRoute<dynamic>>();

/// Each nested navigator needs its own observer instance.
RouteObserver<PageRoute<dynamic>> createPlaybackRouteObserver() =>
    RouteObserver<PageRoute<dynamic>>();
