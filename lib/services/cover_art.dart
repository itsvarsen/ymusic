import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Warm gradient palettes used when a file has no embedded cover.
const List<List<Color>> _warmPalettes = [
  [Color(0xFFF2A65A), Color(0xFF8A3B2E)],
  [Color(0xFFE4949B), Color(0xFF5B2A3A)],
  [Color(0xFFD9825B), Color(0xFF3A1F1A)],
  [Color(0xFFF6C177), Color(0xFFB8573A)],
  [Color(0xFFC9735E), Color(0xFF2B1A22)],
  [Color(0xFFEDB48A), Color(0xFF7A4B3A)],
  [Color(0xFFB5838D), Color(0xFF3B2530)],
  [Color(0xFFE6A15C), Color(0xFF4A2A18)],
];

int _seedHash(String s) {
  var h = 0x811c9dc5;
  for (final c in s.codeUnits) {
    h ^= c;
    h = (h * 0x01000193) & 0xFFFFFFFF;
  }
  return h;
}

List<Color> warmGradientFor(String seed) => _warmPalettes[_seedHash(seed) % _warmPalettes.length];

Color accentFor(String seed) => warmGradientFor(seed).first;

/// Renders a 512x512 PNG of the warm gradient (used for notification/lock-screen art).
Future<Uint8List> renderFallbackCoverPng(String seed, String label) async {
  const size = 512.0;
  final colors = warmGradientFor(seed);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, size, size));
  final paint = Paint()
    ..shader = ui.Gradient.linear(
      const Offset(0, 0),
      const Offset(size, size),
      [colors[0], colors[1]],
    );
  canvas.drawRect(const Rect.fromLTWH(0, 0, size, size), paint);
  // soft glow
  final glow = Paint()
    ..shader = ui.Gradient.radial(
      const Offset(size * 0.25, size * 0.2),
      size * 0.7,
      [const Color(0x55FFF1E0), const Color(0x00FFF1E0)],
    );
  canvas.drawRect(const Rect.fromLTWH(0, 0, size, size), glow);
  final initial = label.trim().isEmpty ? '♪' : label.trim().characters.first.toUpperCase();
  final pb = ui.ParagraphBuilder(ui.ParagraphStyle(textAlign: TextAlign.center))
    ..pushStyle(ui.TextStyle(
      color: const Color(0xCCFFF6EC),
      fontSize: 220,
      fontWeight: FontWeight.w300,
    ))
    ..addText(initial);
  final para = pb.build()..layout(const ui.ParagraphConstraints(width: size));
  canvas.drawParagraph(para, Offset(0, (size - para.height) / 2));
  final picture = recorder.endRecording();
  final img = await picture.toImage(size.toInt(), size.toInt());
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  img.dispose();
  return data!.buffer.asUint8List();
}

final Map<String, Color?> _dominantCache = {};

/// Picks a warm-leaning, saturated dominant colour from an image file.
/// (Own lightweight replacement for the discontinued palette_generator.)
Future<Color?> dominantColorOf(String? path) async {
  if (path == null) return null;
  if (_dominantCache.containsKey(path)) return _dominantCache[path];
  Color? result;
  try {
    final bytes = await File(path).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: 40, targetHeight: 40);
    final frame = await codec.getNextFrame();
    final data = await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
    frame.image.dispose();
    if (data != null) {
      // Hue buckets weighted by saturation & mid-lightness.
      final buckets = List<double>.filled(36, 0);
      final sums = List.generate(36, (_) => [0.0, 0.0, 0.0]);
      double avgR = 0, avgG = 0, avgB = 0;
      var n = 0;
      for (var i = 0; i + 3 < data.lengthInBytes; i += 4) {
        final r = data.getUint8(i) / 255.0;
        final g = data.getUint8(i + 1) / 255.0;
        final b = data.getUint8(i + 2) / 255.0;
        avgR += r;
        avgG += g;
        avgB += b;
        n++;
        final hsl = HSLColor.fromColor(Color.fromARGB(255, (r * 255).round(), (g * 255).round(), (b * 255).round()));
        final l = hsl.lightness;
        if (l < 0.12 || l > 0.92) continue;
        final w = hsl.saturation * (1 - (l - 0.5).abs() * 1.6).clamp(0.05, 1.0);
        final idx = math.min(35, math.max(0, (hsl.hue / 10).floor()));
        buckets[idx] += w;
        sums[idx][0] += r * w;
        sums[idx][1] += g * w;
        sums[idx][2] += b * w;
      }
      var best = -1;
      var bestW = 0.0;
      for (var i = 0; i < 36; i++) {
        if (buckets[i] > bestW) {
          bestW = buckets[i];
          best = i;
        }
      }
      Color c;
      if (best >= 0 && bestW > n * 0.02) {
        c = Color.fromARGB(
          255,
          math.min(255, math.max(0, (sums[best][0] / bestW * 255).round())),
          math.min(255, math.max(0, (sums[best][1] / bestW * 255).round())),
          math.min(255, math.max(0, (sums[best][2] / bestW * 255).round())),
        );
      } else if (n > 0) {
        c = Color.fromARGB(255, (avgR / n * 255).round(), (avgG / n * 255).round(), (avgB / n * 255).round());
      } else {
        c = const Color(0xFFF2A65A);
      }
      // Keep it usable as an accent on a dark UI.
      final hsl = HSLColor.fromColor(c);
      result = hsl
          .withSaturation(math.max(0.35, math.min(0.85, hsl.saturation)))
          .withLightness(math.max(0.5, math.min(0.72, hsl.lightness)))
          .toColor();
    }
  } catch (_) {
    result = null;
  }
  _dominantCache[path] = result;
  return result;
}

void forgetDominant(String? path) {
  if (path != null) _dominantCache.remove(path);
}
