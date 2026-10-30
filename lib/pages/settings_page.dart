import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/proxy_settings.dart';
import '../services/proxy_settings_service.dart';
import '../services/app_log.dart';
import '../services/source_loader.dart';
import '../widgets/source_update_tile.dart';
import '../widgets/network_diagnostics_tile.dart';
import '../services/huangguo_api.dart';
import '../services/site_endpoint_service.dart';
import '../widgets/site_endpoint_tile.dart';
import '../services/playback_settings_service.dart';
import '../widgets/playback_settings_tile.dart';

const _log = AppLog('SettingsPage');

class SettingsPage extends StatefulWidget {
  final ProxySettingsService proxyService;
  final PlaybackSettingsService? playbackSettings;
  final SourceLoader? sourceLoader;
  final HuangguoApi? api;
  final SiteEndpointService? siteService;

  const SettingsPage({
    super.key,
    required this.proxyService,
    this.playbackSettings,
    this.sourceLoader,
    this.api,
    this.siteService,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late bool _proxyEnabled;
  late TextEditingController _hostController;
  late TextEditingController _portController;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _hostController = TextEditingController();
    _portController = TextEditingController();
    _syncFromService();
    widget.proxyService.addListener(_onServiceChanged);
  }

  @override
  void dispose() {
    widget.proxyService.removeListener(_onServiceChanged);
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  void _onServiceChanged() {
    if (!mounted) return;
    _syncFromService();
  }

  void _syncFromService() {
    final s = widget.proxyService.settings;
    setState(() {
      _proxyEnabled = s.enabled;
      _hostController.text = s.host;
      _portController.text = s.port.toString();
      _dirty = false;
    });
  }

  Future<void> _save() async {
    final host = _hostController.text.trim();
    final portText = _portController.text.trim();

    if (host.isEmpty) {
      _showSnack('代理地址不能为空');
      return;
    }
    final port = int.tryParse(portText);
    if (port == null || port <= 0 || port > 65535) {
      _showSnack('端口号无效 (1-65535)');
      return;
    }

    _log.i('_save: enabled=$_proxyEnabled, host=$host, port=$port');
    await widget.proxyService.save(
      ProxySettings(enabled: _proxyEnabled, host: host, port: port),
    );
    _showSnack('代理设置已保存（即时生效，无需重启）');
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        title: const Text('设置'),
        backgroundColor: const Color(0xFF0D0D0D),
        actions: [
          if (_dirty)
            TextButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_rounded, size: 18),
              label: const Text('保存'),
              style: TextButton.styleFrom(foregroundColor: Colors.orange),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.playbackSettings != null)
            PlaybackSettingsTile(settings: widget.playbackSettings!),
          if (widget.sourceLoader != null)
            SourceUpdateTile(sourceLoader: widget.sourceLoader!),
          if (widget.siteService != null)
            SiteEndpointTile(service: widget.siteService!),
          if (widget.api != null) NetworkDiagnosticsTile(api: widget.api!),
          // --- Proxy toggle ---
          Card(
            color: Colors.grey[900],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: SwitchListTile(
              title: const Text(
                '启用代理',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                _proxyEnabled ? '所有网络请求走代理' : '直接连接（不经过代理）',
                style: TextStyle(color: Colors.grey[400], fontSize: 13),
              ),
              value: _proxyEnabled,
              activeColor: Colors.orange,
              onChanged: (v) {
                setState(() => _proxyEnabled = v);
                _markDirty();
              },
            ),
          ),
          const SizedBox(height: 16),

          // --- Host ---
          _buildLabel('代理地址'),
          const SizedBox(height: 6),
          TextField(
            controller: _hostController,
            onChanged: (_) => _markDirty(),
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration('127.0.0.1'),
          ),
          const SizedBox(height: 16),

          // --- Port ---
          _buildLabel('代理端口'),
          const SizedBox(height: 6),
          TextField(
            controller: _portController,
            onChanged: (_) => _markDirty(),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration('7897'),
          ),
          const SizedBox(height: 24),

          // --- Info ---
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: Colors.orange[300], size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '保存后即时生效，无需重启 App。'
                    '手机端如使用小火箭等外部代理，通常无需开启此设置。'
                    '如果通过 Mac 共享代理给 iPhone，请填写 Mac 的局域网 IP，不能填写 127.0.0.1，'
                    '并确认代理软件已开启“允许局域网连接”。',
                    style: TextStyle(color: Colors.orange[200], fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.grey[400],
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey[700]),
      filled: true,
      fillColor: Colors.grey[850],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }
}
