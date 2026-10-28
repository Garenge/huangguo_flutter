import 'package:flutter/material.dart';
import 'models/drama.dart';
import 'models/episode.dart';
import 'models/playback_history.dart';
import 'pages/home_page.dart';
import 'pages/search_page.dart';
import 'pages/manual_parse_page.dart';
import 'pages/player_page.dart';
import 'pages/detail_page.dart';
import 'pages/download_page.dart';
import 'pages/settings_page.dart';
import 'services/huangguo_api.dart';
import 'services/html_parser.dart';
import 'services/source_loader.dart';
import 'services/image_decryptor.dart';
import 'services/download_service.dart';
import 'services/playback_history_service.dart';
import 'services/proxy_settings_service.dart';
import 'services/app_log.dart';
import 'services/site_endpoint_service.dart';

const _log = AppLog('MainShell');

void main() {
  runApp(const HuangguoApp());
}

class HuangguoApp extends StatelessWidget {
  const HuangguoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '黄果短剧',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.orange,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0D0D0D),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0D0D0D),
          elevation: 0,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF1A1A1A),
          selectedItemColor: Colors.orange,
          unselectedItemColor: Colors.grey,
        ),
      ),
      home: const MainShell(),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  late final Future<void> _networkReady;
  late final ProxySettingsService _proxyService;
  late final HuangguoApi _api;
  late final SourceLoader _sourceLoader;
  late final SiteEndpointService _siteService;
  final _imageDecryptor = ImageDecryptor();
  late HtmlParser _htmlParser;
  late DownloadService _downloadService;
  late PlaybackHistoryService _historyService;

  // Player state
  Episode? _pendingEpisode;
  List<Episode> _pendingEpisodes = [];
  String? _pendingDramaName;
  String? _pendingDramaId;
  Duration? _pendingStartPosition;

  // Nested navigator keys
  final _homeNavKey = GlobalKey<NavigatorState>();
  final _searchNavKey = GlobalKey<NavigatorState>();
  final _playerNavKey = GlobalKey<NavigatorState>();
  final _parseNavKey = GlobalKey<NavigatorState>();
  final _downloadNavKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _log.i('initState start');

    // 1) 先用平台默认值创建服务（不读磁盘，避免阻塞）
    _proxyService = ProxySettingsService();
    _api = HuangguoApi(proxySettings: _proxyService.settings);
    _sourceLoader = SourceLoader(proxySettings: _proxyService.settings);
    _siteService = SiteEndpointService(proxySettings: _proxyService.settings);
    _siteService.addListener(_onSiteChanged);
    _htmlParser = HtmlParser(_api.site);
    _downloadService = DownloadService(_api);
    _downloadService.init();
    _historyService = PlaybackHistoryService();

    // 先应用已保存的代理，再允许首页发起请求。
    _networkReady = _loadNetworkSettings();
    _log.i('initState done');
  }

  Future<void> _loadNetworkSettings() async {
    await _proxyService.load();
    _siteService.updateProxy(_proxyService.settings);
    await _siteService.load();
    _api.updateSite(_siteService.selectedUrl);
    _htmlParser.updateSite(_siteService.selectedUrl);
    if (!mounted) return;
    _onProxyChanged();
    _proxyService.addListener(_onProxyChanged);
  }

  void _onProxyChanged() {
    final s = _proxyService.settings;
    _log.i(
      'proxy changed: enabled=${s.enabled}, host=${s.host}, port=${s.port}',
    );
    _api.updateProxy(s);
    _sourceLoader.updateProxy(s);
    _siteService.updateProxy(s);
  }

  void _onSiteChanged() {
    final site = _siteService.selectedUrl;
    _api.updateSite(site);
    _htmlParser.updateSite(site);
  }

  @override
  void dispose() {
    _proxyService.removeListener(_onProxyChanged);
    _proxyService.dispose();
    _siteService.removeListener(_onSiteChanged);
    _siteService.dispose();
    super.dispose();
  }

  /// Switch to player tab and start playing
  void _playEpisode(
    Episode episode,
    List<Episode> allEpisodes, {
    String? dramaName,
    String? dramaId,
  }) {
    setState(() {
      _pendingEpisode = episode;
      _pendingEpisodes = allEpisodes;
      _pendingDramaName = dramaName;
      _pendingDramaId = dramaId;
      _pendingStartPosition = null;
      _currentIndex = 1;
    });
  }

  /// 从历史记录恢复播放
  void _playFromHistory(PlaybackHistoryEntry entry) {
    final episode = Episode(
      name: entry.episodeName,
      url: entry.url,
      ep: entry.ep,
    );
    setState(() {
      _pendingEpisode = episode;
      _pendingEpisodes = [episode];
      _pendingDramaName = entry.dramaName;
      _pendingDramaId = entry.dramaId;
      _pendingStartPosition = Duration(milliseconds: entry.positionMs);
      _currentIndex = 1;
    });
  }

  /// Push detail page within the given tab navigator
  void _openDetail(Drama drama, GlobalKey<NavigatorState> navKey) {
    navKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => DetailPage(
          drama: drama,
          api: _api,
          htmlParser: _htmlParser,
          imageDecryptor: _imageDecryptor,
          downloadService: _downloadService,
          onPlayEpisode: (ep, eps) =>
              _playEpisode(ep, eps, dramaName: drama.name, dramaId: drama.id),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildHomeTab(),
          _buildPlayerTab(),
          _buildSearchTab(),
          _buildParseTab(),
          _buildDownloadTab(),
          _buildSettingsTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: '首页'),
          BottomNavigationBarItem(
            icon: Icon(Icons.play_circle_rounded),
            label: '播放',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search_rounded),
            label: '搜索',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.code_rounded), label: '解析'),
          BottomNavigationBarItem(
            icon: Icon(Icons.download_rounded),
            label: '下载',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_rounded),
            label: '设置',
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTab() {
    return SettingsPage(
      proxyService: _proxyService,
      sourceLoader: _sourceLoader,
      api: _api,
      siteService: _siteService,
    );
  }

  Widget _buildHomeTab() {
    return Navigator(
      key: _homeNavKey,
      onGenerateRoute: (_) => MaterialPageRoute(
        builder: (_) => HomePage(
          networkReady: _networkReady,
          api: _api,
          sourceLoader: _sourceLoader,
          onParserReady: (parser) => _htmlParser = parser,
          onOpenDetail: (drama) => _openDetail(drama, _homeNavKey),
          onPlayEpisode: (ep, eps, dramaName) =>
              _playEpisode(ep, eps, dramaName: dramaName),
          downloadService: _downloadService,
        ),
      ),
    );
  }

  Widget _buildPlayerTab() {
    return Navigator(
      key: _playerNavKey,
      onGenerateRoute: (_) => MaterialPageRoute(
        builder: (_) => PlayerPage(
          api: _api,
          htmlParser: _htmlParser,
          initialEpisode: _pendingEpisode,
          allEpisodes: _pendingEpisodes,
          downloadService: _downloadService,
          historyService: _historyService,
          startPosition: _pendingStartPosition,
          dramaName: _pendingDramaName,
          dramaId: _pendingDramaId,
          onPlayFromHistory: _playFromHistory,
        ),
      ),
    );
  }

  Widget _buildSearchTab() {
    return Navigator(
      key: _searchNavKey,
      onGenerateRoute: (_) => MaterialPageRoute(
        builder: (_) => SearchPage(
          api: _api,
          htmlParser: _htmlParser,
          onOpenDetail: (drama) => _openDetail(drama, _searchNavKey),
        ),
      ),
    );
  }

  Widget _buildParseTab() {
    return Navigator(
      key: _parseNavKey,
      onGenerateRoute: (_) => MaterialPageRoute(
        builder: (_) => ManualParsePage(api: _api, htmlParser: _htmlParser),
      ),
    );
  }

  Widget _buildDownloadTab() {
    return Navigator(
      key: _downloadNavKey,
      onGenerateRoute: (_) => MaterialPageRoute(
        builder: (_) => DownloadPage(
          downloadService: _downloadService,
          api: _api,
          htmlParser: _htmlParser,
          onOpenDetail: (drama) {
            setState(() => _currentIndex = 0);
            _openDetail(drama, _homeNavKey);
          },
        ),
      ),
    );
  }
}
