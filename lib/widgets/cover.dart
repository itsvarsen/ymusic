import 'dart:math' as math;
import 'dart:io';

import 'package:flutter/material.dart';

import '../models/song.dart';
import '../services/cover_art.dart';

/// Song / album artwork with a warm gradient fallback.
class CoverArt extends StatelessWidget {
  final Song? song;
  final double size;
  final double radius;
  final bool circle;
  final String? seed;

  const CoverArt({super.key, required this.song, this.size = 56, this.radius = 16, this.circle = false, this.seed});

  @override
  Widget build(BuildContext context) {
    final s = song;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    Widget child;
    if (s != null && s.hasArt && s.artPath != null) {
      child = Image.file(
        File(s.artPath!),
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: math.min(1400, math.max(64, (size * dpr).round())),
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, _, _) => _GradientCover(seed: _seedOf(s), label: s.title, size: size),
      );
    } else {
      child = _GradientCover(seed: seed ?? (s == null ? 'ymusic' : _seedOf(s)), label: s?.title ?? '', size: size);
    }
    final shape = circle ? BorderRadius.circular(size / 2) : BorderRadius.circular(radius);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: shape,
        boxShadow: size >= 120
            ? const [BoxShadow(color: Color(0x66000000), blurRadius: 30, offset: Offset(0, 14))]
            : null,
      ),
      child: ClipRRect(borderRadius: shape, child: child),
    );
  }

  static String _seedOf(Song s) => '${s.album.isEmpty ? s.title : s.album}|${s.artist}';
}

class _GradientCover extends StatelessWidget {
  final String seed;
  final String label;
  final double size;
  const _GradientCover({required this.seed, required this.label, required this.size});

  @override
  Widget build(BuildContext context) {
    final c = warmGradientFor(seed);
    final initial = label.trim().isEmpty ? '♪' : label.trim().characters.first.toUpperCase();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: c),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-0.5, -0.6),
                radius: 1.0,
                colors: [Color(0x40FFF1E0), Color(0x00FFF1E0)],
              ),
            ),
          ),
          Center(
            child: Text(
              initial,
              style: TextStyle(
                fontSize: size * 0.42,
                fontWeight: FontWeight.w300,
                color: const Color(0xD9FFF6EC),
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
