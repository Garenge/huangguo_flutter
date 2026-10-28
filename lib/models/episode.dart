class Episode {
  final String name;
  final String url;
  final String ep;

  const Episode({
    required this.name,
    required this.url,
    required this.ep,
  });

  @override
  bool operator ==(Object other) =>
      other is Episode && other.ep == ep && other.url == url;

  @override
  int get hashCode => Object.hash(ep, url);

  @override
  String toString() => 'Episode(name: $name, ep: $ep)';
}
