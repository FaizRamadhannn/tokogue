import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../data/app_state.dart';
import '../data/backend.dart';
import '../data/loyalty.dart';
import '../data/models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'loyalty_settings_screen.dart';

/// Layani member loyalty card — khusus atasan.
/// Scan QR di HP pelanggan → pilih menu yang dibeli → kasih stempel / tukar hadiah.
class MemberScanScreen extends StatefulWidget {
  const MemberScanScreen({super.key});

  @override
  State<MemberScanScreen> createState() => _MemberScanScreenState();
}

class _MemberScanScreenState extends State<MemberScanScreen> {
  final _codeCtrl = TextEditingController();
  MemberCard? _member;
  List<MenuItem> _menu = const [];
  final _qty = <int, int>{};
  bool _busy = false;
  String? _lastScanned;

  LoyaltyRepo get _repo => LoyaltyRepo(AppScope.read(context).backend);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_menu.isEmpty) _loadMenu();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMenu() async {
    try {
      final m = await _repo.menu();
      if (mounted) setState(() => _menu = m);
    } catch (_) {
      /* menu opsional; stempel tetap bisa tanpa menu */
    }
  }

  Future<void> _find(String raw) async {
    final code = extractMemberCode(raw);
    if (code == null) {
      showSnack(context, 'QR ini bukan kartu member.', error: true);
      return;
    }
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final m = await _repo.lookup(code);
      if (!mounted) return;
      if (m == null) {
        showSnack(context, 'Member $code tidak ditemukan.', error: true);
        _lastScanned = null;
      } else {
        HapticFeedback.mediumImpact();
        _qty.clear();
        _member = m;
        _codeCtrl.clear();
      }
    } catch (e) {
      if (mounted) showSnack(context, loyaltyErrorText(e), error: true);
      _lastScanned = null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _onDetect(BarcodeCapture cap) {
    final raw = cap.barcodes.map((b) => b.rawValue).whereType<String>().firstOrNull;
    if (raw == null || raw == _lastScanned || _busy || _member != null) return;
    _lastScanned = raw;
    _find(raw);
  }

  Future<void> _stamp() async {
    final m = _member!;
    setState(() => _busy = true);
    try {
      final next = await _repo.addStamp(m.id, Map.of(_qty));
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      setState(() {
        _member = next;
        _qty.clear();
      });
      showSnack(
        context,
        next.full
            ? '${next.name} dapat stempel ke-${next.stamps}. Kartu penuh, siap tukar hadiah!'
            : '${next.name} dapat stempel ke-${next.stamps}.',
      );
    } catch (e) {
      if (mounted) showSnack(context, loyaltyErrorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _redeem() async {
    final m = _member!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tukar hadiah?'),
        content: Text('${m.name} dapat ${m.reward}. Stempel kembali ke 0.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
            child: const Text('Tukar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final next = await _repo.redeem(m.id);
      if (!mounted) return;
      setState(() => _member = next);
      showSnack(context, 'Hadiah ditukar. Kasih ${m.reward} ke ${m.name}.');
    } catch (e) {
      if (mounted) showSnack(context, loyaltyErrorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _reset() => setState(() {
    _member = null;
    _lastScanned = null;
    _qty.clear();
  });

  @override
  Widget build(BuildContext context) {
    final m = _member;
    final isManager = AppScope.of(context).me?.role == Role.atasan;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kartu Member'),
        actions: [
          // Pengaturan program cuma untuk atasan; kasir cuma scan & kasih stempel.
          if (isManager)
            IconButton(
              tooltip: 'Atur program & menu',
              icon: const Icon(Icons.tune_rounded),
              onPressed: () async {
                await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoyaltySettingsScreen()));
                _loadMenu();
              },
            ),
        ],
      ),
      body: AnimatedSwitcher(duration: Motion.medium, child: m == null ? _scanView() : _memberView(m)),
    );
  }

  Widget _scanView() {
    return ListView(
      key: const ValueKey('scan'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        const Text('Scan QR di HP pelanggan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
        const SizedBox(height: 4),
        const Text(
          'Minta pelanggan buka kartunya lalu tap "Tampilkan QR ke kasir".',
          style: TextStyle(color: AppColors.muted, height: 1.4),
        ),
        const SizedBox(height: 14),
        AspectRatio(
          aspectRatio: 1,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(
                  color: Colors.black,
                  // Tanpa controller: widget nyalain kamera sendiri & matiin lagi waktu kartu member tampil.
                  child: MobileScanner(
                    onDetect: _onDetect,
                    errorBuilder: (context, error) => _CameraError(error),
                    // Bingkai bidik cuma tampil kalau kamera nyala.
                    overlayBuilder: (context, constraints) => const _Viewfinder(),
                  ),
                ),
                if (_busy)
                  const ColoredBox(
                    color: Color(0x88000000),
                    child: Center(child: CircularProgressIndicator(color: Colors.white)),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Text('Kamera bermasalah? Ketik kode di kartu', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _codeCtrl,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.search,
                onSubmitted: _find,
                decoration: const InputDecoration(hintText: 'LC-XXXXX', prefixIcon: Icon(Icons.badge_outlined)),
              ),
            ),
            const SizedBox(width: 10),
            FilledButton(
              onPressed: _busy ? null : () => _find(_codeCtrl.text),
              style: FilledButton.styleFrom(minimumSize: const Size(88, 52)),
              child: const Text('Cari'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _memberView(MemberCard m) {
    final picked = _qty.values.fold(0, (a, b) => a + b);
    return ListView(
      key: ValueKey('member-${m.code}'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        _MemberCardView(m),
        const SizedBox(height: 16),
        if (m.full) ...[
          CardBox(
            child: Row(
              children: [
                const Icon(Icons.card_giftcard_rounded, color: AppColors.gold, size: 30),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Kartu penuh!', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      const SizedBox(height: 2),
                      Text('Hadiah: ${m.reward}', style: const TextStyle(color: AppColors.muted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _busy ? null : _redeem,
            icon: const Icon(Icons.redeem_rounded),
            label: const Text('Tukar hadiah'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          ),
        ] else ...[
          Row(
            children: [
              const Expanded(
                child: Text('Menu yang dibeli', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ),
              Text(
                picked == 0 ? (_menu.isEmpty ? 'opsional' : 'pilih minimal 1') : '$picked item',
                style: TextStyle(
                  color: picked == 0 && _menu.isNotEmpty ? AppColors.primary : AppColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_menu.isEmpty)
            const Text(
              'Belum ada menu. Atasan bisa menambahkannya lewat tombol atur di kanan atas.',
              style: TextStyle(color: AppColors.muted),
            )
          else
            for (final item in _menu)
              _MenuRow(item: item, qty: _qty[item.id] ?? 0, onChanged: (q) => setState(() => _qty[item.id] = q)),
          const SizedBox(height: 16),
          FilledButton.icon(
            // Menu wajib dipilih kalau toko punya menu, biar laporan menu terlaris akurat.
            onPressed: _busy || (_menu.isNotEmpty && picked == 0) ? null : _stamp,
            icon: _busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.verified_rounded),
            label: const Text('Kasih stempel'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          ),
        ],
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _busy ? null : _reset,
          icon: const Icon(Icons.qr_code_scanner_rounded),
          label: const Text('Scan pelanggan lain'),
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        ),
      ],
    );
  }
}

class _Viewfinder extends StatelessWidget {
  const _Viewfinder();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: FractionallySizedBox(
          widthFactor: 0.7,
          heightFactor: 0.7,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white, width: 3),
            ),
          ),
        ),
      ),
    );
  }
}

class _MemberCardView extends StatelessWidget {
  const _MemberCardView(this.m);
  final MemberCard m;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.hero],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  m.name,
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(99)),
                child: Text(
                  m.code,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${m.stamps} dari ${m.target} stempel · sudah tukar ${m.redeemed}x',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < m.target; i++)
                AnimatedContainer(
                  duration: Motion.medium,
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < m.stamps ? AppColors.goldLight : Colors.white.withValues(alpha: 0.12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                  ),
                  child: i < m.stamps ? const Icon(Icons.check_rounded, size: 20, color: AppColors.hero) : null,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.item, required this.qty, required this.onChanged});
  final MenuItem item;
  final int qty;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
      decoration: BoxDecoration(
        color: qty > 0 ? AppColors.primarySoft : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: qty > 0 ? AppColors.primary.withValues(alpha: 0.3) : AppColors.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          IconButton(
            tooltip: 'Kurangi',
            onPressed: qty > 0 ? () => onChanged(qty - 1) : null,
            icon: const Icon(Icons.remove_circle_outline_rounded),
          ),
          SizedBox(
            width: 22,
            child: Text(
              '$qty',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          IconButton(
            tooltip: 'Tambah',
            onPressed: qty < 50 ? () => onChanged(qty + 1) : null,
            icon: const Icon(Icons.add_circle_rounded, color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

class _CameraError extends StatelessWidget {
  const _CameraError(this.error);
  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    return ColoredBox(
      color: AppColors.hero,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.no_photography_rounded, color: Colors.white, size: 40),
            const SizedBox(height: 12),
            Text(
              denied
                  ? 'Izin kamera ditolak. Buka pengaturan browser/HP, izinkan kamera untuk tokogue, lalu buka layar ini lagi.'
                  : 'Kamera tidak bisa dibuka. Pakai kolom kode di bawah.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pesan error loyalty yang ramah.
String loyaltyErrorText(Object e) {
  final msg = e is PostgrestException ? e.message : e.toString();
  final soon = RegExp(r'too_soon:(\d+)').firstMatch(msg);
  if (soon != null) return 'Member ini baru dapat stempel. Tunggu ${soon.group(1)} menit lagi.';
  if (msg.contains('not_staff') || msg.contains('not_manager')) return 'Fitur ini khusus atasan.';
  if (msg.contains('card_full_or_missing')) return 'Kartu sudah penuh. Tukar hadiah dulu.';
  if (msg.contains('not_ready')) return 'Stempel belum cukup untuk tukar hadiah.';
  if (msg.contains('items_required')) return 'Pilih minimal 1 menu yang dibeli.';
  if (msg.contains('invalid_items')) return 'Ada menu yang tidak valid. Muat ulang layar ini.';
  if (msg.contains('PGRST202') || msg.contains('Could not find the function')) {
    return 'Fitur kartu member belum dipasang di server. Admin: jalankan supabase/loyalty.sql di Supabase.';
  }
  return friendlyError(e);
}
