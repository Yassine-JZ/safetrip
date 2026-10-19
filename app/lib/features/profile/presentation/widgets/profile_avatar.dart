import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.initials,
    this.photoUrl,
    this.radius = 28,
    this.ring = false,
  });

  final String initials;
  final String? photoUrl;
  final double radius;

  /// White ring, for avatars on the blue header.
  final bool ring;

  // Decoding a base64 photo on every rebuild would be wasteful.
  static final _cache = <String, Uint8List>{};

  static Uint8List? _bytes(String? url) {
    if (url == null || !url.startsWith('data:image/')) return null;
    final cached = _cache[url];
    if (cached != null) return cached;
    final comma = url.indexOf(',');
    if (comma < 0) return null;
    try {
      final bytes = base64Decode(url.substring(comma + 1));
      if (_cache.length > 8) _cache.clear();
      return _cache[url] = bytes;
    } on FormatException {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes(photoUrl);
    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primary.withValues(alpha: 0.12),
      foregroundImage: bytes == null ? null : MemoryImage(bytes),
      child: Text(
        initials.isEmpty ? '?' : initials,
        style: TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
          fontSize: radius * 0.7,
        ),
      ),
    );
    if (!ring) return avatar;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: avatar,
    );
  }
}
