import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/models.dart';
import '../theme.dart';

bool _reduceMotion(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// Memberi jeda bertingkat ke widget yang muncul bersamaan (efek "stagger"),
/// tanpa perlu tahu urutannya di daftar.
class _Stagger {
  static DateTime _last = DateTime(0);
  static int _count = 0;

  static Duration next() {
    final now = DateTime.now();
    if (now.difference(_last).inMilliseconds > 120) _count = 0;
    _last = now;
    final d = Duration(milliseconds: math.min(_count * 45, 420));
    _count++;
    return d;
  }
}

/// Muncul dengan fade + geser naik sedikit, sekali saat pertama tampil.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({super.key, required this.child, this.delay, this.offset = 14});
  final Widget child;
  final Duration? delay;
  final double offset;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _a;

  @override
  void initState() {
    super.initState();
    final delay = widget.delay ?? _Stagger.next();
    final total = delay + Motion.slow;
    _c = AnimationController(vsync: this, duration: total);
    final start = delay.inMilliseconds / total.inMilliseconds;
    _a = CurvedAnimation(parent: _c, curve: Interval(start, 1, curve: Motion.curve));
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_reduceMotion(context)) return widget.child;
    return AnimatedBuilder(
      animation: _a,
      child: widget.child,
      builder: (_, child) => Opacity(
        opacity: _a.value,
        child: Transform.translate(offset: Offset(0, widget.offset * (1 - _a.value)), child: child),
      ),
    );
  }
}

/// Mengecil sedikit saat ditekan, memberi rasa "membal".
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.enabled = true, this.scale = 0.97});
  final Widget child;
  final bool enabled;
  final double scale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (widget.enabled && _down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: _down ? const Duration(milliseconds: 90) : Motion.medium,
        curve: _down ? Curves.easeOut : Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}

/// Angka badge merah yang "pop" setiap kali nilainya berubah.
class CountBadge extends StatelessWidget {
  const CountBadge(this.count, {super.key, this.border = true});
  final int count;
  final bool border;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: Motion.medium,
      transitionBuilder: (child, a) => ScaleTransition(
        scale: CurvedAnimation(parent: a, curve: Curves.easeOutBack),
        child: child,
      ),
      child: count <= 0
          ? const SizedBox.shrink(key: ValueKey(0))
          : Container(
              key: ValueKey(count),
              constraints: const BoxConstraints(minWidth: 18),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: AppColors.red,
                borderRadius: BorderRadius.circular(10),
                border: border ? Border.all(color: Colors.white, width: 2) : null,
              ),
              child: Text('$count',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
            ),
    );
  }
}

class Avatar extends StatelessWidget {
  const Avatar(this.employee, {super.key, this.size = 40});
  final Employee employee;
  final double size;

  static const _palette = [
    AppColors.primary,
    AppColors.blue,
    AppColors.orange,
    AppColors.purple,
    AppColors.teal,
    AppColors.pink,
  ];

  @override
  Widget build(BuildContext context) {
    final c = _palette[employee.id.codeUnits.fold(0, (a, b) => a + b) % _palette.length];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: c.withValues(alpha: 0.12), shape: BoxShape.circle),
      child: Text(
        employee.initials,
        style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: size * 0.36),
      ),
    );
  }
}

class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, required this.color, required this.background, this.icon});
  final String text;
  final Color color;
  final Color background;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: Motion.medium,
      curve: Motion.curve,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 13, color: color), const SizedBox(width: 4)],
        Text(text, style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.action, this.onAction, this.subtitle});
  final String title;
  final String? subtitle;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return FadeSlideIn(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 28, 8, 12),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.ink, letterSpacing: -0.3)),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(subtitle!, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                ),
            ]),
          ),
          if (action != null) TextButton(onPressed: onAction, child: Text(action!)),
        ]),
      ),
    );
  }
}

/// Menu layanan: ikon dalam kotak lembut + label.
class ServiceTile extends StatelessWidget {
  const ServiceTile({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.soft,
    required this.onTap,
    this.badge = 0,
  });
  final IconData icon;
  final String label;
  final Color color;
  final Color soft;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return FadeSlideIn(
      child: Pressable(
        scale: 0.92,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Stack(clipBehavior: Clip.none, children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Center(
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(11)),
                      child: Icon(icon, color: color, size: 21),
                    ),
                  ),
                ),
                Positioned(right: -5, top: -5, child: CountBadge(badge)),
              ]),
              const SizedBox(height: 8),
              Text(label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: const TextStyle(fontSize: 12, color: AppColors.ink, fontWeight: FontWeight.w500, height: 1.2)),
            ]),
          ),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.body});
  final IconData icon;
  final String title;
  final String? body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 56),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.6, end: 1),
          duration: const Duration(milliseconds: 600),
          curve: Curves.elasticOut,
          builder: (_, v, child) => Transform.scale(scale: v, child: child),
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.line),
            ),
            child: Icon(icon, color: AppColors.primary, size: 34),
          ),
        ),
        const SizedBox(height: 18),
        FadeSlideIn(
          child: Column(children: [
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.2)),
            if (body != null) ...[
              const SizedBox(height: 6),
              Text(body!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted, height: 1.45)),
            ],
          ]),
        ),
      ]),
    );
  }
}

/// Kartu putih bergaris tipis. Muncul dengan animasi dan membal saat ditekan.
class CardBox extends StatelessWidget {
  const CardBox({super.key, required this.child, this.onTap, this.padding = const EdgeInsets.all(16), this.margin});
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final EdgeInsets? margin;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(18);
    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: FadeSlideIn(
        child: Pressable(
          enabled: onTap != null,
          scale: 0.98,
          child: Material(
            color: Colors.white,
            borderRadius: radius,
            child: InkWell(
              onTap: onTap,
              borderRadius: radius,
              child: Container(
                padding: padding,
                decoration: BoxDecoration(borderRadius: radius, border: Border.all(color: AppColors.line)),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

SnackBar _snack(String msg, Color color) => SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w500)),
      behavior: SnackBarBehavior.floating,
      backgroundColor: color,
      elevation: 0,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );

void showSnack(BuildContext context, String msg, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(_snack(msg, error ? AppColors.red : AppColors.ink));
}

/// Jalankan aksi yang mengembalikan pesan error (atau null), lalu tampilkan hasilnya.
/// Mengembalikan true kalau berhasil.
Future<bool> runAction(BuildContext context, Future<String?> action, {String? success}) async {
  final messenger = ScaffoldMessenger.of(context);
  final err = await action;
  if (err != null) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(_snack(err, AppColors.red));
    return false;
  }
  if (success != null) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(_snack(success, AppColors.ink));
  }
  return true;
}

/// Bottom sheet putih dengan pegangan di atas.
Future<T?> showAppSheet<T>(BuildContext context, Widget child) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    sheetAnimationStyle: const AnimationStyle(duration: Duration(milliseconds: 380), reverseDuration: Duration(milliseconds: 240)),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 10),
          Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(2))),
          Flexible(child: child),
        ]),
      ),
    ),
  );
}
