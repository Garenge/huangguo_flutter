import 'playback_session.dart';

/// Ownership includes loading players, preventing late initialization from
/// restarting an online video after local playback has taken over.
class PlaybackCoordinator {
  final Set<PlaybackSession> _sessions = {};
  PlaybackSession? _owner;

  void register(PlaybackSession session) => _sessions.add(session);

  Future<void> claim(PlaybackSession session) async {
    _owner = session;
    await Future.wait([
      for (final other in _sessions.toList())
        if (other != session) other.interrupt(),
    ]);
  }

  bool owns(PlaybackSession session) => _owner == session;

  void remove(PlaybackSession session) {
    _sessions.remove(session);
    if (_owner == session) _owner = null;
  }
}
