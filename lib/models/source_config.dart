class TabItem {
  final String name;
  final String id;

  const TabItem({required this.name, required this.id});

  @override
  String toString() => 'TabItem(name: $name, id: $id)';
}

class SourceConfig {
  final String site;
  final String ua;
  final List<TabItem> tabs;
  final String rawSource;

  const SourceConfig({
    required this.site,
    required this.ua,
    required this.tabs,
    required this.rawSource,
  });

  @override
  String toString() =>
      'SourceConfig(site: $site, tabs: ${tabs.length}, ua: ${ua.substring(0, 50)}...)';
}
