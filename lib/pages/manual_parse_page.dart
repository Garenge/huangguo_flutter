import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/huangguo_api.dart';
import '../services/html_parser.dart';
import '../services/stream_resolver.dart';
import '../services/app_log.dart';
import '../widgets/loading_indicator.dart';

const _log = AppLog('ManualParse');

class ManualParsePage extends StatefulWidget {
  final HuangguoApi api;
  final HtmlParser htmlParser;

  const ManualParsePage({
    super.key,
    required this.api,
    required this.htmlParser,
  });

  @override
  State<ManualParsePage> createState() => _ManualParsePageState();
}

class _ManualParsePageState extends State<ManualParsePage> {
  late StreamResolver _resolver;

  final _playUrlController = TextEditingController();
  final _htmlController = TextEditingController();
  final _episodeController = TextEditingController(text: '1');

  String? _resultUrl;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _resolver = StreamResolver(widget.api);
  }

  @override
  void dispose() {
    _playUrlController.dispose();
    _htmlController.dispose();
    _episodeController.dispose();
    super.dispose();
  }

  Future<void> _parseFromUrl() async {
    final url = _playUrlController.text.trim();
    if (url.isEmpty) return;
    _log.i('_parseFromUrl: $url');

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _resultUrl = null;
    });

    try {
      final ep = _episodeController.text.trim();
      final result = await _resolver.resolveStreamFromUrl(
        url,
        ep: ep.isNotEmpty ? ep : '1',
      );
      _log.i('_parseFromUrl: result=$result');
      setState(() {
        _resultUrl = result;
        _isLoading = false;
      });
    } catch (e, stack) {
      _log.e('_parseFromUrl: failed', e, stack);
      setState(() {
        _isLoading = false;
        _errorMessage = '解析失败：$e';
      });
    }
  }

  void _parseFromHtml() {
    final html = _htmlController.text.trim();
    if (html.isEmpty) return;
    _log.i('_parseFromHtml: htmlLen=${html.length}');

    setState(() {
      _errorMessage = null;
      _resultUrl = null;
    });

    try {
      final ep = _episodeController.text.trim();
      final result = _resolver.resolveStreamFromHtml(
        html,
        ep: ep.isNotEmpty ? ep : '1',
      );
      _log.i('_parseFromHtml: result=$result');
      setState(() {
        _resultUrl = result;
      });
    } catch (e, stack) {
      _log.e('_parseFromHtml: failed', e, stack);
      setState(() {
        _errorMessage = '解析失败：$e';
      });
    }
  }

  void _copyResult() {
    if (_resultUrl != null) {
      Clipboard.setData(ClipboardData(text: _resultUrl!));
      _log.d('_copyResult: copied');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('已复制流地址到剪贴板'),
          backgroundColor: Colors.grey[800],
        ),
      );
    }
  }

  InputDecoration _inputDeco(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey[600]),
      filled: true,
      fillColor: Colors.white10,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionTitle('播放页 URL'),
          const SizedBox(height: 8),
          TextField(
            controller: _playUrlController,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDeco('粘贴播放页完整 URL'),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 44,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _parseFromUrl,
              icon: const Icon(Icons.download_rounded, size: 20),
              label: const Text('抓取并解析'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          const Divider(color: Colors.white10),
          const SizedBox(height: 28),
          _sectionTitle('或粘贴 HTML 源码'),
          const SizedBox(height: 8),
          TextField(
            controller: _htmlController,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            maxLines: 6,
            decoration: _inputDeco('粘贴播放页 HTML 源码'),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text('集数: ',
                  style: TextStyle(color: Colors.grey[400], fontSize: 14)),
              SizedBox(
                width: 60,
                child: TextField(
                  controller: _episodeController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white10,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 10),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: ElevatedButton(
                    onPressed: _parseFromHtml,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white10,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('解析粘贴内容'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: LoadingIndicator(message: '正在解析...'),
            ),
          if (_errorMessage != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red[300], fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          if (_resultUrl != null) ...[
            _sectionTitle('解析结果'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    _resultUrl!,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _copyResult,
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('复制'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green,
                      side: BorderSide(color: Colors.green.withOpacity(0.5)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: Colors.orange,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
