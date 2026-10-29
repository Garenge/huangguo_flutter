import 'dart:convert';

import 'drama.dart';
import '../services/site_address.dart';

/// 频道异步接口的列表及分页信息，与首屏 HTML 模板分开缓存。
class ChannelPage {
  final List<Drama> items;
  final int page;
  final int pages;

  const ChannelPage({
    required this.items,
    required this.page,
    required this.pages,
  });

  bool get hasNextPage => page < pages;

  factory ChannelPage.fromResponse(String response) {
    final envelope = jsonDecode(response) as Map<String, dynamic>;
    final data = envelope['data'] as Map<String, dynamic>;
    final pagination = data['pagination'] as Map<String, dynamic>;
    final seen = <String>{};
    final items = (data['items'] as List)
        .cast<Map<String, dynamic>>()
        .where((item) => item['id'] != null && '${item['id']}'.isNotEmpty)
        .map(_parseItem)
        .where((item) => seen.add(item.id))
        .toList();
    return ChannelPage(
      items: items,
      page: _integer(pagination['page']),
      pages: _integer(pagination['pages']),
    );
  }

  static Drama _parseItem(Map<String, dynamic> item) => Drama(
    id: item['id'].toString(),
    name: item['title']?.toString() ?? '',
    pic: SiteAddress.relative(item['cover']?.toString() ?? ''),
    remark: _remark(item),
  );

  static String _remark(Map<String, dynamic> item) {
    final count = _integer(item['episode_count']);
    final finished = item['is_finished'] == true || item['is_finished'] == 1;
    final episode = finished
        ? '全${_integer(item['total_episodes'])}集'
        : (count > 0 ? '更新至$count集' : '');
    final score = num.tryParse('${item['score']}') ?? 0;
    return [
      episode,
      if (score > 0) '${score.toStringAsFixed(1)}分',
    ].where((value) => value.isNotEmpty).join(' · ');
  }

  static int _integer(dynamic value) => int.tryParse('$value') ?? 0;
}
