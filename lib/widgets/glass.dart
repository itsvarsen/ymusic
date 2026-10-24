import 'dart:math' as math;
import 'dart:ui' show ImageFilter, TileMode, FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

/// Frosted, translucent panel with a 1px light border and an inner highlight.
class Glass extends StatelessWidget {
  final Widget child;
  final double radius;
  final double blur;
  final EdgeInsetsGeometry? padding;
  final Color tint;
  final double opacity;
  final bool border;

  const Glass({
    super.key,
    required this.child,
    this.radius = 28,
    this.blur = 28,
    this.padding,
    this.tint = const Color(0xFF2A1F18),
    this.opacity = 0.55,
    this.border = true,
  });

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    return ClipRRect(
      borderRadius: r,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: r,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                tint.withValues(alpha: opacity),
                tint.withValues(alpha: opacity * 0.6),
              ],
            ),
            border: border ? Border.all(color: const Color(0x26FFF1E0), width: 1) : null,
          ),
          child: Stack(
            children: [
              // inner top highlight
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: 36,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(radius)),
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x1AFFF6EC), Color(0x00FFF6EC)],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(padding: padding ?? EdgeInsets.zero, child: child),
            ],
          ),
        ),
      ),
    );
  }
}

/// A lighter translucent surface without blur (cheap; good for list rows).
class SoftCard extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  const SoftCard({super.key, required this.child, this.radius = 24, this.padding, this.onTap, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0x0FFFF1E0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: const BorderSide(color: Color(0x14FFF1E0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
      ),
    );
  }
}

/// Round glass icon button with haptics.
class GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final Color? color;
  final bool filled;
  final String? tooltip;
  const GlassIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.size = 44,
    this.color,
    this.filled = false,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final btn = SizedBox(
      width: size,
      height: size,
      child: Material(
        color: filled ? YColors.amber : const Color(0x1AFFF1E0),
        shape: CircleBorder(
          side: BorderSide(color: filled ? Colors.transparent : const Color(0x24FFF1E0)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onTap!();
                },
          child: Icon(icon, size: size * 0.48, color: color ?? (filled ? const Color(0xFF1C120A) : YColors.cream)),
        ),
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}

/// Pill-shaped primary button.
class PillButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool primary;
  final bool large;
  const PillButton({super.key, required this.label, this.icon, this.onTap, this.primary = true, this.large = false});

  @override
  Widget build(BuildContext context) {
    final fg = primary ? const Color(0xFF1C120A) : YColors.cream;
    return Material(
      shape: StadiumBorder(side: BorderSide(color: primary ? Colors.transparent : const Color(0x26FFF1E0))),
      clipBehavior: Clip.antiAlias,
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          gradient: primary
              ? const LinearGradient(colors: [Color(0xFFF6B56E), YColors.copper])
              : null,
          color: primary ? null : const Color(0x14FFF1E0),
        ),
        child: InkWell(
          onTap: onTap == null
              ? null
              : () {
                  HapticFeedback.lightImpact();
                  onTap!();
                },
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: large ? 30 : 18, vertical: large ? 18 : 11),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: large ? 22 : 18, color: fg),
                  SizedBox(width: large ? 10 : 8),
                ],
                Text(
                  label,
                  style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: large ? 17 : 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Warm ambient background: near-black with soft amber/rose glows.
class AmbientBackground extends StatelessWidget {
  final Widget child;
  final Color? accent;
  const AmbientBackground({super.key, required this.child, this.accent});

  @override
  Widget build(BuildContext context) {
    final a = accent ?? YColors.amber;
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: YColors.bg),
        Positioned(
          top: -160,
          left: -120,
          child: _Glow(color: a.withValues(alpha: 0.20), size: 460),
        ),
        Positioned(
          top: 220,
          right: -180,
          child: _Glow(color: YColors.rose.withValues(alpha: 0.10), size: 420),
        ),
        Positioned(
          bottom: -200,
          left: -60,
          child: _Glow(color: YColors.ember.withValues(alpha: 0.12), size: 480),
        ),
        child,
      ],
    );
  }
}

class _Glow extends StatelessWidget {
  final Color color;
  final double size;
  const _Glow({required this.color, required this.size});
  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}

/// "⅄music" wordmark. The ⅄ is drawn as a rotated Y so it never depends on
/// font coverage of U+2144.
class BrandMark extends StatelessWidget {
  final double size;
  const BrandMark({super.key, this.size = 26});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Transform.rotate(
          angle: math.pi,
          child: ShaderMask(
            shaderCallback: (r) => const LinearGradient(
              colors: [Color(0xFFF8C27F), YColors.copper],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ).createShader(r),
            child: Text(
              'Y',
              style: TextStyle(fontSize: size * 1.05, fontWeight: FontWeight.w800, color: Colors.white, height: 1),
            ),
          ),
        ),
        const SizedBox(width: 2),
        Text(
          'music',
          style: TextStyle(
            fontSize: size,
            fontWeight: FontWeight.w300,
            letterSpacing: -0.5,
            color: YColors.cream,
            height: 1,
          ),
        ),
      ],
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const SectionHeader(this.title, {super.key, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 22, 14, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.3),
            ),
          ),
          if (action != null)
            TextButton(
              onPressed: onAction,
              child: Text(action!, style: const TextStyle(color: YColors.amber, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }
}

void showToast(BuildContext context, String message) {
  final m = ScaffoldMessenger.maybeOf(context);
  if (m == null) return;
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(
    content: Text(message),
    duration: const Duration(seconds: 2),
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 170),
  ));
}
