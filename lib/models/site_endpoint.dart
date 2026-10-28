class SiteEndpoint {
  final String url;
  final Duration? latency;
  final String? error;

  const SiteEndpoint({required this.url, this.latency, this.error});

  bool get isAvailable => latency != null && error == null;

  String get host => Uri.parse(url).host;
}
