import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../data/app_state.dart';
import '../data/format.dart';
import '../data/models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'leave_screen.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Absensi'),
          bottom: const TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.muted,
            indicatorColor: AppColors.primary,
            labelStyle: TextStyle(fontWeight: FontWeight.w700),
            tabs: [Tab(text: 'Absen hari ini'), Tab(text: 'Riwayat')],
          ),
        ),
        body: const TabBarView(children: [_ClockTab(), _HistoryTab()]),
      ),
    );
  }
}

class _ClockTab extends StatefulWidget {
  const _ClockTab();

  @override
  State<_ClockTab> createState() => _ClockTabState();
}

class _ClockTabState extends State<_ClockTab> {
  // Mode demo: lokasi & selfie disimulasikan.
  bool _inside = true;
  bool _demoSelfie = false;

  // Mode live: GPS & kamera asli.
  int? _gpsDistance;
  double? _lat;
  double? _lng;
  String? _gpsError;
  bool _locating = false;
  XFile? _selfieFile;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && AppScope.read(context).isLive) _locate();
    });
  }

  bool get _live => AppScope.read(context).isLive;
  int get _distance => _live ? (_gpsDistance ?? 99999) : (_inside ? 38 : 240);
  bool get _hasSelfie => _live ? _selfieFile != null : _demoSelfie;

  Future<void> _locate() async {
    setState(() {
      _locating = true;
      _gpsError = null;
    });
    final state = AppScope.read(context);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw 'GPS di HP kamu mati. Nyalakan dulu.';
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        throw 'Izinkan akses lokasi supaya bisa absen.';
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 20)),
      );
      if (pos.isMocked) throw 'Terdeteksi fake GPS. Matikan aplikasi pengubah lokasi.';
      _lat = pos.latitude;
      _lng = pos.longitude;
      _gpsDistance = Geolocator.distanceBetween(pos.latitude, pos.longitude, state.officeLat, state.officeLng).round();
    } catch (e) {
      _gpsDistance = null;
      _gpsError = e is String ? e : 'Lokasi tidak terbaca. Coba lagi di tempat terbuka.';
    }
    if (mounted) setState(() => _locating = false);
  }

  Future<void> _takeSelfie() async {
    if (!_live) {
      setState(() => _demoSelfie = !_demoSelfie);
      return;
    }
    final file = await ImagePicker().pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      maxWidth: 900,
      imageQuality: 70,
    );
    if (file != null && mounted) setState(() => _selfieFile = file);
  }

  Future<void> _submit(bool isIn) async {
    final state = AppScope.read(context);
    String? err;
    if (_live) {
      if (_lat == null || _lng == null) {
        showSnack(context, _gpsError ?? 'Lokasi belum terbaca. Ketuk "Perbarui lokasi".', error: true);
        return;
      }
      if (_selfieFile == null) {
        showSnack(context, 'Ambil selfie dulu sebelum absen.', error: true);
        return;
      }
      setState(() => _busy = true);
      err = await state.clockLive(isIn: isIn, lat: _lat!, lng: _lng!, selfie: _selfieFile!);
      if (mounted) setState(() => _busy = false);
    } else {
      err = isIn
          ? state.clockIn(distance: _distance, selfie: _demoSelfie)
          : state.clockOut(distance: _distance, selfie: _demoSelfie);
    }
    if (!mounted) return;
    if (err != null) {
      showSnack(context, err, error: true);
      return;
    }
    setState(() {
      _demoSelfie = false;
      _selfieFile = null;
    });
    final rec = state.todayRecord(state.me!.id);
    if (rec == null) return;
    final time = isIn ? rec.checkIn : rec.checkOut;
    showAppSheet(
      context,
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 84,
            height: 84,
            decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
            child: const Icon(Icons.check_rounded, color: AppColors.primary, size: 48),
          ),
          const SizedBox(height: 16),
          Text(isIn ? 'Absen masuk berhasil' : 'Absen pulang berhasil',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          if (time != null)
            Text(fmtTime(time),
                style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: AppColors.primary)),
          const SizedBox(height: 8),
          if (isIn && rec.lateMinutes > 0)
            Text('Telat ${rec.lateMinutes} menit · potongan ${fmtRupiah(rec.penalty)}',
                style: const TextStyle(color: AppColors.red, fontWeight: FontWeight.w600))
          else
            Text(isIn ? 'Tepat waktu, semangat kerjanya!' : 'Terima kasih, hati-hati di jalan.',
                style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 24),
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Oke')),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final me = state.me!;
    final rec = state.todayRecord(me.id);
    final isIn = rec?.checkIn == null;
    final done = rec?.checkOut != null;
    final now = DateTime.now();
    final live = state.isLive;
    final inside = _distance <= state.radius;
    final known = !live || _gpsDistance != null;

    final String badge;
    if (live && _locating) {
      badge = 'Mencari lokasi…';
    } else if (!known) {
      badge = 'Lokasi belum terbaca';
    } else {
      badge = inside ? 'Dalam radius toko' : 'Di luar radius toko';
    }
    final badgeColor = !known ? AppColors.orange : (inside ? AppColors.primary : AppColors.red);

    return ListView(padding: const EdgeInsets.all(16), children: [
      // Peta radius
      ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          height: 210,
          child: Stack(children: [
            Positioned.fill(
              child: CustomPaint(painter: _MapPainter(distance: known ? _distance : -1, radius: state.radius)),
            ),
            Positioned(
              left: 12,
              top: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(inside && known ? Icons.check_circle_rounded : Icons.error_rounded, size: 16, color: badgeColor),
                  const SizedBox(width: 6),
                  Text(badge, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: badgeColor)),
                ]),
              ),
            ),
          ]),
        ),
      ),
      const SizedBox(height: 12),
      Row(children: [
        const Icon(Icons.storefront_rounded, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(state.storeName, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(
              known
                  ? 'Kamu $_distance m dari toko · batas ${state.radius} m'
                  : (_gpsError ?? 'Sedang membaca GPS…'),
              style: TextStyle(color: _gpsError != null ? AppColors.red : AppColors.muted, fontSize: 13),
            ),
          ]),
        ),
      ]),
      const SizedBox(height: 10),
      if (live)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _locating ? null : _locate,
            icon: const Icon(Icons.my_location_rounded, size: 18, color: AppColors.primary),
            label: const Text('Perbarui lokasi', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
          ),
        )
      else
        Row(children: [
          const Text('Lokasi (demo):', style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
          const SizedBox(width: 8),
          ChoiceChip(label: const Text('Di toko'), selected: _inside, onSelected: (_) => setState(() => _inside = true)),
          const SizedBox(width: 6),
          ChoiceChip(label: const Text('Di luar'), selected: !_inside, onSelected: (_) => setState(() => _inside = false)),
        ]),
      const SizedBox(height: 16),
      // Selfie
      CardBox(
        onTap: done ? null : _takeSelfie,
        child: Row(children: [
          Container(
            width: 64,
            height: 64,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: _hasSelfie ? AppColors.primarySoft : AppColors.bg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: _hasSelfie
                ? (_selfieFile != null
                    ? FutureBuilder(
                        future: _selfieFile!.readAsBytes(),
                        builder: (_, snap) => snap.hasData
                            ? Image.memory(snap.data!, fit: BoxFit.cover)
                            : Center(child: Avatar(me, size: 48)),
                      )
                    : Center(child: Avatar(me, size: 48)))
                : const Icon(Icons.photo_camera_front_rounded, color: AppColors.muted, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_hasSelfie ? 'Selfie siap' : 'Ambil selfie', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 2),
              Text(_hasSelfie ? 'Ketuk untuk ulangi' : 'Wajib untuk absen masuk dan pulang',
                  style: const TextStyle(color: AppColors.muted, fontSize: 13)),
            ]),
          ),
          Icon(_hasSelfie ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
              color: _hasSelfie ? AppColors.primary : AppColors.muted),
        ]),
      ),
      const SizedBox(height: 16),
      CardBox(
        child: Column(children: [
          Row(children: [
            Text(me.shift.label, style: const TextStyle(fontWeight: FontWeight.w800)),
            const Spacer(),
            Text(me.shift.hours, style: const TextStyle(color: AppColors.muted)),
          ]),
          const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider()),
          Row(children: [
            Expanded(child: _Stat(label: 'Masuk', value: rec?.checkIn == null ? '--.--' : fmtTime(rec!.checkIn!))),
            Expanded(child: _Stat(label: 'Pulang', value: rec?.checkOut == null ? '--.--' : fmtTime(rec!.checkOut!))),
            Expanded(
              child: _Stat(
                label: 'Telat',
                value: rec == null || rec.lateMinutes == 0 ? '-' : '${rec.lateMinutes} mnt',
                color: (rec?.lateMinutes ?? 0) > 0 ? AppColors.red : null,
              ),
            ),
          ]),
        ]),
      ),
      const SizedBox(height: 20),
      FilledButton.icon(
        onPressed: done || _busy ? null : () => _submit(isIn),
        icon: _busy
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
            : Icon(isIn ? Icons.login_rounded : Icons.logout_rounded),
        label: Text(done ? 'Absen hari ini selesai' : (isIn ? 'Absen Masuk Sekarang' : 'Absen Pulang Sekarang')),
      ),
      const SizedBox(height: 12),
      Text(
        'Telat dihitung dari jam mulai shift. Setiap 5 menit telat dipotong Rp5.000. '
        'Absen tidak bisa offline — kalau gagal karena sinyal atau GPS, ajukan koreksi absen.',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.muted.withValues(alpha: 0.9), fontSize: 12.5, height: 1.4),
      ),
      TextButton(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const LeaveFormScreen(initialType: RequestType.koreksiAbsen))),
        child: const Text('Ajukan koreksi absen', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
      ),
      Text(fmtLongDate(now), textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
    ]);
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.color});
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: color ?? AppColors.ink)),
    ]);
  }
}

class _MapPainter extends CustomPainter {
  _MapPainter({required this.distance, required this.radius});
  final int distance;
  final int radius;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFEFF3EE));
    // jalan
    final road = Paint()
      ..color = Colors.white
      ..strokeWidth = 14;
    canvas.drawLine(Offset(0, size.height * 0.62), Offset(size.width, size.height * 0.52), road);
    canvas.drawLine(Offset(size.width * 0.3, 0), Offset(size.width * 0.38, size.height), road..strokeWidth = 10);
    canvas.drawLine(Offset(size.width * 0.78, 0), Offset(size.width * 0.7, size.height), road..strokeWidth = 8);
    // blok bangunan
    final block = Paint()..color = const Color(0xFFE2E8E0);
    for (final r in [
      Rect.fromLTWH(size.width * 0.05, size.height * 0.1, 60, 40),
      Rect.fromLTWH(size.width * 0.45, size.height * 0.08, 70, 46),
      Rect.fromLTWH(size.width * 0.82, size.height * 0.7, 54, 40),
      Rect.fromLTWH(size.width * 0.06, size.height * 0.72, 70, 36),
    ]) {
      canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(6)), block);
    }

    final center = Offset(size.width * 0.55, size.height * 0.55);
    final pxPerM = (size.height * 0.36) / radius;
    canvas.drawCircle(center, radius * pxPerM, Paint()..color = AppColors.primary.withValues(alpha: 0.14));
    canvas.drawCircle(
        center,
        radius * pxPerM,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = AppColors.primary.withValues(alpha: 0.6));
    // toko
    canvas.drawCircle(center, 14, Paint()..color = AppColors.primary);
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(Icons.storefront_rounded.codePoint),
        style: TextStyle(fontSize: 16, fontFamily: Icons.storefront_rounded.fontFamily, package: Icons.storefront_rounded.fontPackage, color: Colors.white),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
    // posisi kamu
    if (distance < 0) return;
    final angle = -math.pi / 5;
    final d = math.min(distance * pxPerM, size.width * 0.5);
    final me = center + Offset(math.cos(angle) * d, math.sin(angle) * d) * (distance > radius ? 1 : 1);
    final clamped = Offset(me.dx.clamp(12, size.width - 12), me.dy.clamp(12, size.height - 12));
    canvas.drawCircle(clamped, 16, Paint()..color = AppColors.blue.withValues(alpha: 0.2));
    canvas.drawCircle(clamped, 8, Paint()..color = Colors.white);
    canvas.drawCircle(clamped, 6, Paint()..color = AppColors.blue);
  }

  @override
  bool shouldRepaint(covariant _MapPainter old) => old.distance != distance;
}

class _HistoryTab extends StatelessWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final me = state.me!;
    final now = DateTime.now();
    final list = state.historyOf(me.id);
    final month = list.where((r) => r.date.month == now.month && r.date.year == now.year).toList();
    final lateDays = month.where((r) => r.lateMinutes > 0).length;
    final penalty = month.fold<int>(0, (s, r) => s + r.penalty);

    return ListView(padding: const EdgeInsets.all(16), children: [
      FadeSlideIn(child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.hero,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Ringkasan ${fmtMonthYear(now)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          Row(children: [
            _WhiteStat(label: 'Hadir', value: '${month.length} hari'),
            _WhiteStat(label: 'Telat', value: '$lateDays kali'),
            _WhiteStat(label: 'Potongan', value: fmtRupiah(penalty)),
          ]),
        ]),
      )),
      const SizedBox(height: 16),
      for (final r in list)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: CardBox(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              Container(
                width: 46,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(10)),
                child: Column(children: [
                  Text('${r.date.day}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                  Text(fmtDayMonth(r.date).split(' ').last, style: const TextStyle(color: AppColors.muted, fontSize: 11)),
                ]),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${r.checkIn == null ? '--.--' : fmtTime(r.checkIn!)}  →  ${r.checkOut == null ? '--.--' : fmtTime(r.checkOut!)}',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(r.isCorrection ? '${r.shift.label} · koreksi disetujui' : r.shift.label,
                      style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
                ]),
              ),
              if (r.lateMinutes > 0)
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Pill('Telat ${r.lateMinutes} mnt', color: AppColors.red, background: AppColors.redSoft),
                  const SizedBox(height: 4),
                  Text('-${fmtRupiah(r.penalty)}', style: const TextStyle(color: AppColors.red, fontSize: 12)),
                ])
              else
                const Pill('Tepat waktu', color: AppColors.green, background: AppColors.greenSoft),
            ]),
          ),
        ),
    ]);
  }
}

class _WhiteStat extends StatelessWidget {
  const _WhiteStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
      ]),
    );
  }
}
