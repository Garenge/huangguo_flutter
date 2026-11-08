abstract final class CompressionFailureDetails {
  static String describe(String? logs) {
    final lines = (logs ?? '')
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final relevant = lines
        .where(
          (line) => RegExp(
            r'error|failed|invalid|not found|denied|not permitted|unable|unsupported|'
            r'not on whitelist|could not|cannot|no such|incompatible',
            caseSensitive: false,
          ).hasMatch(line),
        )
        .toList();
    final selected = relevant.isEmpty ? lines : relevant;
    if (selected.isEmpty) return '编码组件未提供详细错误';
    final message = selected
        .skip(selected.length > 3 ? selected.length - 3 : 0)
        .join('\n');
    return message.length <= 600
        ? message
        : message.substring(message.length - 600);
  }
}
