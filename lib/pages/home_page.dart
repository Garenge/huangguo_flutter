import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/drama.dart';
import '../models/channel_page.dart';
import '../models/episode.dart';
import '../models/source_config.dart';
import '../services/source_loader.dart';
import '../services/huangguo_api.dart';
import '../services/html_parser.dart';
import '../services/image_decryptor.dart';
import '../services/download_service.dart';
import '../services/app_log.dart';
import '../widgets/drama_card.dart';
import '../widgets/loading_indicator.dart';

const _log = AppLog('HomePage');

class _ListCacheEntry {
  final String html;
  final ChannelPage? channelPage;
  List<TabItem>? channelTabs;
  final Map<String, List<Drama>> _itemsByChannel = {};
  final Set<String> _emptyChannels = {};

  _ListCacheEntry({required this.html}) : channelPage = null;

  _ListCacheEntry.channel(this.channelPage, this.channelTabs) : html = '';

  List<Drama> itemsFor({
    required String tab,
    required String channelTab,
    required HtmlParser parser,
    required List<TabItem> channelTabs,
  }) {
    if (channelPage != null) return channelPage!.items;
    final key = '$tab|$channelTab';
    if (_emptyChannels.contains(key)) return const <Drama>[];
    return _itemsByChannel.putIfAbsent(key, () {
      if (tab.contains('rank')) return parser.parseRankList(html);
      final explicitPanel = parser.hasChannelPanel(html, channelTab);
      if (!explicitPanel && channelTabs.isNotEmpty && channelTabs.length > 1) {
        _emptyChannels.add(key);
        return const <Drama>[];
      }
      final activeChannel = channelTabs.any((item) => item.id == channelTab)
          ? channelTab
          : null;
      return parser.parseCardList(
        html,
        tab == 'home',
        channelTabId: activeChannel,
      );
    });
  }
}

class HomePage extends StatefulWidget {
  final Future<void>? networkReady;
  final HuangguoApi api;
  final SourceLoader sourceLoader;
  final DownloadService downloadService;
  final void Function(HtmlParser parser)? onParserReady;
  final void Function(Drama drama) onOpenDetail;
  final void Function(Drama drama, Uint8List? fallbackImage)?
  onOpenDetailWithImage;
  final void Function(
    Episode episode,
    List<Episode> allEpisodes,
    String dramaName,
  )
  onPlayEpisode;

  const HomePage({
    super.key,
    this.networkReady,
    required this.api,
    required this.sourceLoader,
    required this.downloadService,
    this.onParserReady,
    required this.onOpenDetail,
    this.onOpenDetailWithImage,
    required this.onPlayEpisode,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ImageDecryptor _imageDecryptor = ImageDecryptor();
  late HtmlParser _htmlParser;

  SourceConfig? _sourceConfig;
  List<Drama> _dramas = [];
  List<TabItem> _channelTabs = [];
  String _selectedTab = 'home';
  String _selectedChannelTab = 'latest';
  int _currentPage = 1;
  final Map<String, _ListCacheEntry> _listCache = {};
  int _loadToken = 0;
  bool _isLoadingSource = true;
  bool _isLoading = false;
  bool _hasNextPage = false;
  String? _errorMessage;
  String? _statusMessage;

  final Map<String, Uint8List?> _imageCache = {};
  final Map<String, Future<Uint8List?>> _imageRequests = {};

  @override
  void initState() {
    super.initState();
    _log.i('initState');
    _htmlParser = HtmlParser(widget.api.site);
    widget.sourceLoader.addListener(_onRulesUpdated);
    widget.api.addListener(_onSiteChanged);
    _loadSource();
  }

  Future<void> _loadSource() async {
    _log.i('_loadSource: start');
    setState(() {
      _isLoadingSource = true;
      _errorMessage = null;
      _statusMessage = '正在加载...';
    });

    try {
      await widget.networkReady;
      if (!mounted) return;
      final config = await widget.sourceLoader.loadSource();
      if (!mounted) return;
      _onSourceReady(config);
      await _loadList();
    } catch (e, stack) {
      _log.e('_loadSource: failed', e, stack);
      if (!mounted) return;
      setState(() {
        _isLoadingSource = false;
        _errorMessage = '加载失败：$e';
      });
    }
  }

  @override
  void dispose() {
    widget.sourceLoader.removeListener(_onRulesUpdated);
    widget.api.removeListener(_onSiteChanged);
    super.dispose();
  }

  void _onSiteChanged() {
    if (!mounted || _sourceConfig == null || _isLoadingSource) return;
    _htmlParser.updateSite(widget.api.site);
    _loadList();
  }

  void _onRulesUpdated() {
    final config = widget.sourceLoader.updatedConfig;
    if (!mounted || config == null) return;
    _onSourceReady(config);
    _loadList();
  }

  Future<void> _retry() async {
    if (_isLoading || _isLoadingSource) return;
    _imageCache.clear();
    _imageRequests.clear();
    if (_sourceConfig == null) {
      await _loadSource();
    } else {
      await _loadList(forceFetch: true);
    }
  }

  void _onSourceReady(SourceConfig config) {
    widget.api.updateConfig(config);
    _htmlParser = HtmlParser(config.site);
    widget.onParserReady?.call(_htmlParser);
    _currentPage = 1;
    _selectedTab = config.tabs.isNotEmpty ? config.tabs.first.id : 'home';

    setState(() {
      _sourceConfig = config;
      _isLoadingSource = false;
      _statusMessage = '配置已加载';
    });
    _log.i('_onSourceReady: site=${config.site}, tabs=${config.tabs.length}');
  }

  Future<void> _loadList({bool forceFetch = true}) async {
    final tab = _selectedTab;
    final channelTab = _selectedChannelTab;
    final page = _currentPage;
    final token = ++_loadToken;
    final cacheKey = _cacheKey(tab, channelTab, page);
    final cached = forceFetch ? null : _listCache[cacheKey];
    _log.i('_loadList: tab=$tab, channel=$channelTab, page=$page');
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      if (cached == null) {
        _dramas = [];
      }
    });

    try {
      final loadedEntry =
          cached ?? await _fetchListEntry(tab, channelTab, page);
      final channelTabs = loadedEntry.channelTabs ??= _htmlParser
          .parseChannelTabs(loadedEntry.html);
      final items = loadedEntry.itemsFor(
        tab: tab,
        channelTab: channelTab,
        parser: _htmlParser,
        channelTabs: channelTabs,
      );
      _listCache[cacheKey] = loadedEntry;
      if (!mounted ||
          token != _loadToken ||
          tab != _selectedTab ||
          page != _currentPage ||
          channelTab != _selectedChannelTab) {
        return;
      }
      _log.i('_loadList: parsed ${items.length} items');
      setState(() {
        _channelTabs = channelTabs;
        _dramas = items;
        _isLoading = false;
        _hasNextPage = loadedEntry.channelPage?.hasNextPage ?? items.isNotEmpty;
        _statusMessage = '解析到 ${items.length} 个条目';
      });
    } catch (e, stack) {
      _log.e('_loadList: failed', e, stack);
      if (!mounted || token != _loadToken) return;
      setState(() {
        _isLoading = false;
        _errorMessage = '列表加载失败：$e';
        _dramas = [];
      });
    }
  }

  Future<_ListCacheEntry> _fetchListEntry(
    String tab,
    String channelTab,
    int page,
  ) async {
    if (page > 1 &&
        _channelTabs.isNotEmpty &&
        (channelTab == 'hot' || channelTab == 'original')) {
      final tabs = List<TabItem>.of(_channelTabs);
      final response = await widget.api.fetchChannelPage(tab, channelTab, page);
      return _ListCacheEntry.channel(ChannelPage.fromResponse(response), tabs);
    }
    return _ListCacheEntry(html: await widget.api.fetchCategory(tab, page));
  }

  void _onTabChanged(String tabId) {
    _log.i('_onTabChanged: $tabId');
    setState(() {
      _selectedTab = tabId;
      _selectedChannelTab = 'latest';
      _channelTabs = [];
      _currentPage = 1;
    });
    _loadList(forceFetch: false);
  }

  void _onChannelTabChanged(String tabId) {
    _log.i('_onChannelTabChanged: $tabId');
    setState(() {
      _selectedChannelTab = tabId;
      _currentPage = 1;
    });
    _loadList(forceFetch: false);
  }

  void _onPageChanged(int delta) {
    final newPage = _currentPage + delta;
    if (newPage < 1) return;
    _log.i('_onPageChanged: $_currentPage -> $newPage');
    setState(() {
      _currentPage = newPage;
    });
    _loadList(forceFetch: false);
  }

  String _cacheKey(String tab, String channelTab, int page) =>
      page > 1 && (channelTab == 'hot' || channelTab == 'original')
      ? '$tab|$channelTab|$page'
      : '$tab|$page';

  void _onDramaTap(Drama drama) {
    _log.i('_onDramaTap: ${drama.name} (id=${drama.id})');
    widget.onOpenDetail(drama);
  }

  Future<Uint8List?> _loadDecryptedImage(String url) =>
      _imageRequests.putIfAbsent(url, () => _fetchDecryptedImage(url));

  Future<Uint8List?> _fetchDecryptedImage(String url) async {
    if (_imageCache.containsKey(url)) return _imageCache[url];
    if (url.isEmpty) return null;
    try {
      final bytes = await widget.api.fetchImageBytes(url);
      final decrypted = _imageDecryptor.decrypt(Uint8List.fromList(bytes));
      _imageCache[url] = decrypted;
      return decrypted;
    } catch (e, stack) {
      _log.e('_loadDecryptedImage: failed for $url', e, stack);
      _imageCache[url] = null;
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: true,
      bottom: false,
      child: Column(
        children: [
          _buildStatusBar(),
          if (_sourceConfig != null) _buildCategoryTabs(),
          if (_channelTabs.isNotEmpty) _buildChannelTabs(),
          Expanded(child: _buildContent()),
          if (_sourceConfig != null) _buildPagination(),
        ],
      ),
    );
  }

  Widget _buildStatusBar() {
    if (_statusMessage == null && _errorMessage == null) {
      return const SizedBox.shrink();
    }
    final isError = _errorMessage != null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: isError
          ? Colors.red[900]!.withOpacity(0.3)
          : Colors.green[900]!.withOpacity(0.2),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            size: 16,
            color: isError ? Colors.red[300] : Colors.green[300],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage ?? _statusMessage ?? '',
              style: TextStyle(
                fontSize: 12,
                color: isError ? Colors.red[300] : Colors.green[300],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTabs() {
    final tabs = _sourceConfig!.tabs;
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: tabs.length,
        itemBuilder: (_, index) {
          final tab = tabs[index];
          final isSelected = tab.id == _selectedTab;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(
                tab.name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.black : Colors.white70,
                ),
              ),
              selected: isSelected,
              onSelected: (_) => _onTabChanged(tab.id),
              selectedColor: Colors.orange,
              backgroundColor: Colors.grey[850],
              checkmarkColor: Colors.black,
              side: BorderSide.none,
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
          );
        },
      ),
    );
  }

  Widget _buildChannelTabs() {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        itemCount: _channelTabs.length,
        itemBuilder: (_, index) {
          final tab = _channelTabs[index];
          final isSelected = tab.id == _selectedChannelTab;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(
                tab.name,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.black : Colors.white70,
                ),
              ),
              selected: isSelected,
              onSelected: (_) => _onChannelTabChanged(tab.id),
              selectedColor: Colors.lightBlueAccent,
              backgroundColor: Colors.grey[850],
              checkmarkColor: Colors.black,
              side: BorderSide.none,
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoadingSource) {
      return const LoadingIndicator(message: '正在加载...');
    }
    if (_isLoading && _dramas.isEmpty) {
      return const LoadingIndicator(message: '正在加载列表...');
    }
    if (_errorMessage != null && _dramas.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off, size: 64, color: Colors.grey[600]),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: TextStyle(color: Colors.grey[400], fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _retry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }
    if (_dramas.isEmpty && !_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.movie_outlined, size: 64, color: Colors.grey[700]),
            const SizedBox(height: 16),
            Text(
              '没有解析到列表',
              style: TextStyle(color: Colors.grey[500], fontSize: 16),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _retry,
      child: GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 180,
          childAspectRatio: 0.58,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: _dramas.length,
        itemBuilder: (_, index) {
          final drama = _dramas[index];
          return FutureBuilder<Uint8List?>(
            future: _loadDecryptedImage(drama.pic),
            builder: (_, snapshot) {
              return DramaCard(
                drama: drama,
                onTap: () {
                  final openWithImage = widget.onOpenDetailWithImage;
                  if (openWithImage != null) {
                    openWithImage(drama, snapshot.data);
                  } else {
                    _onDramaTap(drama);
                  }
                },
                decryptedImage: snapshot.data,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildPagination() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black26,
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: !_isLoading && _currentPage > 1
                ? () => _onPageChanged(-1)
                : null,
            color: Colors.white70,
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '第 $_currentPage 页',
              style: const TextStyle(fontSize: 13, color: Colors.white70),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed:
                !_isLoading &&
                    _hasNextPage &&
                    (_channelTabs.isEmpty || _selectedChannelTab != 'random')
                ? () => _onPageChanged(1)
                : null,
            color: Colors.white70,
          ),
        ],
      ),
    );
  }
}
