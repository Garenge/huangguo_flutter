import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/drama.dart';
import '../services/huangguo_api.dart';
import '../services/html_parser.dart';
import '../services/image_decryptor.dart';
import '../services/app_log.dart';
import '../widgets/drama_card.dart';
import '../widgets/loading_indicator.dart';

const _log = AppLog('SearchPage');

class SearchPage extends StatefulWidget {
  final HuangguoApi api;
  final HtmlParser htmlParser;
  final void Function(Drama drama) onOpenDetail;

  const SearchPage({
    super.key,
    required this.api,
    required this.htmlParser,
    required this.onOpenDetail,
  });

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final ImageDecryptor _imageDecryptor = ImageDecryptor();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  List<Drama> _results = [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _statusMessage;
  bool _hasSearched = false;

  final Map<String, Uint8List?> _imageCache = {};

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty) return;
    _searchFocus.unfocus();
    _log.i('_search: keyword="$keyword"');
    setState(() {
      _isLoading = true;
      _hasSearched = true;
      _errorMessage = null;
      _results = [];
      _statusMessage = '正在搜索 "$keyword"...';
    });
    try {
      final html = await widget.api.search(keyword);
      final items = widget.htmlParser.parseCardList(html, false);
      _log.i('_search: found ${items.length} results');
      setState(() {
        _results = items;
        _isLoading = false;
        _statusMessage = items.isEmpty ? '没有搜到结果' : '搜到 ${items.length} 个结果';
      });
    } catch (e, stack) {
      _log.e('_search: failed', e, stack);
      setState(() {
        _isLoading = false;
        _errorMessage = '搜索失败：$e';
      });
    }
  }

  Future<Uint8List?> _loadDecryptedImage(String url) async {
    if (_imageCache.containsKey(url)) return _imageCache[url];
    if (url.isEmpty) return null;
    try {
      final bytes = await widget.api.fetchImageBytes(url);
      final decrypted = _imageDecryptor.decrypt(Uint8List.fromList(bytes));
      _imageCache[url] = decrypted;
      return decrypted;
    } catch (e, stack) {
      _log.e('_loadDecryptedImage: failed', e, stack);
      _imageCache[url] = null;
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocus,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: '搜索短剧...',
              hintStyle: TextStyle(color: Colors.grey[500]),
              prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.clear_rounded, size: 20), onPressed: () { _searchController.clear(); setState(() {}); })
                  : null,
              filled: true,
              fillColor: Colors.white10,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onSubmitted: (_) => _search(),
            onChanged: (_) => setState(() {}),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _search,
              icon: const Icon(Icons.search_rounded, size: 20),
              label: const Text('搜索'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
          ),
        ),
        if (_statusMessage != null || _errorMessage != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(_errorMessage != null ? Icons.error_outline : Icons.info_outline, size: 16, color: _errorMessage != null ? Colors.red[300] : Colors.grey[400]),
                const SizedBox(width: 8),
                Text(_errorMessage ?? _statusMessage ?? '', style: TextStyle(fontSize: 13, color: _errorMessage != null ? Colors.red[300] : Colors.grey[400])),
              ],
            ),
          ),
        Expanded(child: _buildResults()),
      ],
    );
  }

  Widget _buildResults() {
    if (_isLoading) return const LoadingIndicator(message: '正在搜索...');
    if (!_hasSearched) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.search_rounded, size: 80, color: Colors.grey[800]), const SizedBox(height: 16), Text('输入关键词搜索短剧', style: TextStyle(color: Colors.grey[500], fontSize: 16))]));
    }
    if (_results.isEmpty && !_isLoading) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.movie_outlined, size: 64, color: Colors.grey[700]), const SizedBox(height: 16), Text('没有搜到结果', style: TextStyle(color: Colors.grey[500], fontSize: 16))]));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 0.58, crossAxisSpacing: 8, mainAxisSpacing: 8),
      itemCount: _results.length,
      itemBuilder: (_, index) {
        final drama = _results[index];
        return FutureBuilder<Uint8List?>(
          future: _loadDecryptedImage(drama.pic),
          builder: (_, snapshot) {
            return DramaCard(drama: drama, onTap: () => widget.onOpenDetail(drama), decryptedImage: snapshot.data);
          },
        );
      },
    );
  }
}
