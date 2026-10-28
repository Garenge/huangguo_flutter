import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/drama.dart';

class DramaCard extends StatelessWidget {
  final Drama drama;
  final VoidCallback onTap;
  final Uint8List? decryptedImage;

  const DramaCard({
    super.key,
    required this.drama,
    required this.onTap,
    this.decryptedImage,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Poster image with overlay
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _buildImage(),
                ),

                // Score badge (top-right)
                if (_hasScore)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _scoreText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                // Episode count badge (bottom-left)
                if (_episodeText.isNotEmpty)
                  Positioned(
                    bottom: 4,
                    left: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _episodeText,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 2, right: 2),
            child: Text(
              drama.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool get _hasScore {
    // Check if remark contains a score like "8.8分"
    return drama.remark.contains(RegExp(r'\d+\.\d+'));
  }

  String get _scoreText {
    final match = RegExp(r'(\d+\.\d+)').firstMatch(drama.remark);
    return match?.group(1) ?? '';
  }

  String get _episodeText {
    // Extract episode info like "更新至18集" or "全1集"
    final match = RegExp(r'(\S+?集)').firstMatch(drama.remark);
    if (match != null) return match.group(1)!;
    // Also match "全N集" pattern
    final fullMatch = RegExp(r'(\S+?\u96c6)').firstMatch(drama.remark);
    if (fullMatch != null) return fullMatch.group(1)!;
    return '';
  }

  Widget _buildImage() {
    if (decryptedImage != null) {
      return Image.memory(
        decryptedImage!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }

    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      color: Colors.grey[900],
      child: const Center(
        child: Icon(Icons.movie_outlined, size: 32, color: Colors.grey),
      ),
    );
  }
}
