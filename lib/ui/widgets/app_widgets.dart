import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../app_theme.dart';

class FeltScaffold extends StatelessWidget {
  const FeltScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.bottomNavigationBar,
    this.floatingActionButton,
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: appBar,
    extendBodyBehindAppBar: appBar != null,
    body: Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(-.75, -.8),
              radius: 1.55,
              colors: [Color(0xFF194A39), AppColors.ink],
              stops: [0, .78],
            ),
          ),
        ),
        IgnorePointer(child: CustomPaint(painter: _FeltPatternPainter())),
        body,
      ],
    ),
    bottomNavigationBar: bottomNavigationBar,
    floatingActionButton: floatingActionButton,
  );
}

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 48});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: AppColors.gold,
      borderRadius: BorderRadius.circular(size * .32),
      boxShadow: [
        BoxShadow(
          color: AppColors.gold.withValues(alpha: .24),
          blurRadius: 24,
          spreadRadius: 2,
        ),
      ],
    ),
    child: Stack(
      alignment: Alignment.center,
      children: [
        Icon(Icons.style_rounded, color: AppColors.black, size: size * .56),
        Positioned(
          right: size * .14,
          top: size * .11,
          child: Container(
            width: size * .16,
            height: size * .16,
            decoration: const BoxDecoration(
              color: AppColors.coral,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    ),
  );
}

class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.color,
    this.borderColor,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.deepGreen.withValues(alpha: .9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor ?? const Color(0xFF315548)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x30000000),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
    if (onTap == null) return content;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: content,
      ),
    );
  }
}

class PotDisplay extends StatelessWidget {
  const PotDisplay({
    super.key,
    required this.value,
    required this.unit,
    this.compact = false,
    this.caption = 'IN DE POT',
  });

  final int value;
  final ScoreUnit unit;
  final bool compact;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final style = compact
        ? Theme.of(context).textTheme.displaySmall
        : Theme.of(context).textTheme.displayLarge;
    return Semantics(
      label: '${unit.format(value)} $caption',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(end: value.toDouble()),
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 520),
            curve: Curves.easeOutCubic,
            builder: (context, animatedValue, child) => Text(
              unit.format(animatedValue.round()),
              style: style?.copyWith(color: AppColors.gold),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            caption,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.goldSoft.withValues(alpha: .74),
              letterSpacing: 2.2,
              fontSize: compact ? 10 : 11,
            ),
          ),
        ],
      ),
    );
  }
}

class SectionHeading extends StatelessWidget {
  const SectionHeading({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
      ),
      if (trailing case final Widget trailingWidget) trailingWidget,
    ],
  );
}

class ScoreText extends StatelessWidget {
  const ScoreText({
    super.key,
    required this.score,
    required this.unit,
    this.large = false,
  });

  final int score;
  final ScoreUnit unit;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final color = score > 0
        ? AppColors.mint
        : score < 0
        ? AppColors.coral
        : AppColors.cream;
    return AnimatedSwitcher(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, .35),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: child,
        ),
      ),
      child: Text(
        unit.format(score, showPlus: true),
        key: ValueKey(score),
        style: TextStyle(
          color: color,
          fontSize: large ? 28 : 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -.5,
        ),
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.icon,
    this.color = AppColors.mint,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: color.withValues(alpha: .38)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: .5,
          ),
        ),
      ],
    ),
  );
}

class StaggeredEntrance extends StatelessWidget {
  const StaggeredEntrance({
    super.key,
    required this.index,
    required this.child,
  });

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : Duration(milliseconds: 360 + math.min(index, 6) * 70),
    curve: Curves.easeOutCubic,
    builder: (context, value, child) => Opacity(
      opacity: value,
      child: Transform.translate(
        offset: Offset(0, (1 - value) * 22),
        child: child,
      ),
    ),
    child: child,
  );
}

class _FeltPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: .018);
    const spacing = 42.0;
    for (double y = 18; y < size.height; y += spacing) {
      for (double x = 18; x < size.width; x += spacing) {
        final stagger = ((y / spacing).round().isOdd) ? spacing / 2 : 0.0;
        canvas.save();
        canvas.translate(x + stagger, y);
        canvas.rotate(math.pi / 4);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(-2.5, -2.5, 5, 5),
            const Radius.circular(1),
          ),
          paint,
        );
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
