import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/app_state.dart';
import '../data/loyalty.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'member_scan_screen.dart' show loyaltyErrorText;

/// Atur program kartu member: nama toko, target stempel, hadiah, jeda anti-curang, menu, poster QR.
class LoyaltySettingsScreen extends StatefulWidget {
  const LoyaltySettingsScreen({super.key});

  @override
  State<LoyaltySettingsScreen> createState() => _LoyaltySettingsScreenState();
}

class _LoyaltySettingsScreenState extends State<LoyaltySettingsScreen> {
  final _store = TextEditingController();
  final _reward = TextEditingController();
  final _newMenu = TextEditingController();
  int _target = 10;
  int _cooldown = 30;
  List<MenuItem> _menu = const [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  static const _cooldownOptions = [0, 5, 15, 30, 60, 120, 240];

  LoyaltyRepo get _repo => LoyaltyRepo(AppScope.read(context).backend);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loading && _error == null && _store.text.isEmpty) _load();
  }

  @override
  void dispose() {
    _store.dispose();
    _reward.dispose();
    _newMenu.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final s = await _repo.settings();
      final m = await _repo.menu(includeInactive: true);
      if (!mounted) return;
      setState(() {
        _store.text = s.store;
        _reward.text = s.reward;
        _target = s.target;
        _cooldown = _cooldownOptions.contains(s.cooldownMin) ? s.cooldownMin : 30;
        _menu = m;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = loyaltyErrorText(e);
        });
      }
    }
  }

  Future<void> _save() async {
    final store = _store.text.trim();
    final reward = _reward.text.trim();
    if (store.isEmpty || reward.isEmpty) {
      showSnack(context, 'Nama toko dan hadiah wajib diisi.', error: true);
      return;
    }
    setState(() => _saving = true);
    await runAction(context, () async {
      try {
        await _repo.saveSettings(LoyaltySettings(store: store, target: _target, reward: reward, cooldownMin: _cooldown));
        return null;
      } catch (e) {
        return loyaltyErrorText(e);
      }
    }(), success: 'Pengaturan disimpan.');
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _addMenu() async {
    final name = _newMenu.text.trim();
    if (name.isEmpty) return;
    if (_menu.any((m) => m.name.toLowerCase() == name.toLowerCase())) {
      showSnack(context, 'Menu "$name" sudah ada.', error: true);
      return;
    }
    try {
      await _repo.addMenu(name);
      _newMenu.clear();
      final m = await _repo.menu(includeInactive: true);
      if (mounted) setState(() => _menu = m);
    } catch (e) {
      if (mounted) showSnack(context, loyaltyErrorText(e), error: true);
    }
  }

  Future<void> _toggle(MenuItem item, bool active) async {
    try {
      await _repo.setMenuActive(item.id, active);
      final m = await _repo.menu(includeInactive: true);
      if (mounted) setState(() => _menu = m);
    } catch (e) {
      if (mounted) showSnack(context, loyaltyErrorText(e), error: true);
    }
  }

  void _showPoster() {
    const link = '${loyaltyWebBase}poster.html';
    showAppSheet(
      context,
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Poster QR untuk meja kasir', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text(
              'Buka link ini di laptop/HP, lalu tekan "Cetak poster (A5)". Pelanggan scan poster → daftar → dapat kartu. '
              'Pelanggan lama yang scan langsung masuk ke kartunya.',
              style: TextStyle(color: AppColors.muted, height: 1.45),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.line),
              ),
              child: const SelectableText(link, style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () {
                Clipboard.setData(const ClipboardData(text: link));
                Navigator.pop(context);
                showSnack(context, 'Link poster disalin.');
              },
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Salin link poster'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Atur Kartu Member')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
          ? ListView(
              children: [
                EmptyState(icon: Icons.cloud_off_rounded, title: 'Pengaturan belum bisa dibuka', body: _error),
                Center(
                  child: TextButton(
                    onPressed: () {
                      setState(() {
                        _loading = true;
                        _error = null;
                      });
                      _load();
                    },
                    child: const Text('Coba lagi'),
                  ),
                ),
              ],
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              children: [
                CardBox(
                  onTap: _showPoster,
                  child: const Row(
                    children: [
                      Icon(Icons.qr_code_2_rounded, color: AppColors.primary, size: 32),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Poster QR pendaftaran', style: TextStyle(fontWeight: FontWeight.w800)),
                            SizedBox(height: 2),
                            Text('Cetak & taruh di meja kasir', style: TextStyle(color: AppColors.muted)),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: AppColors.muted),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                const Text('Program', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                TextField(
                  controller: _store,
                  maxLength: 60,
                  decoration: const InputDecoration(labelText: 'Nama toko di kartu', counterText: ''),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _reward,
                  maxLength: 120,
                  decoration: const InputDecoration(labelText: 'Hadiah kalau kartu penuh', counterText: ''),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: _target,
                  decoration: const InputDecoration(labelText: 'Jumlah stempel sampai dapat hadiah'),
                  items: [for (var i = 3; i <= 15; i++) DropdownMenuItem(value: i, child: Text('$i stempel'))],
                  onChanged: (v) => setState(() => _target = v ?? _target),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: _cooldown,
                  decoration: const InputDecoration(
                    labelText: 'Jeda minimal antar stempel (anti-curang)',
                    helperText: 'Member yang sama tidak bisa dapat stempel lagi sebelum jeda ini lewat.',
                    helperMaxLines: 3,
                  ),
                  items: [
                    for (final m in _cooldownOptions)
                      DropdownMenuItem(
                        value: m,
                        child: Text(
                          m == 0
                              ? 'Tanpa jeda'
                              : m < 60
                              ? '$m menit'
                              : '${m ~/ 60} jam',
                        ),
                      ),
                  ],
                  onChanged: (v) => setState(() => _cooldown = v ?? _cooldown),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                  child: Text(_saving ? 'Menyimpan…' : 'Simpan pengaturan'),
                ),
                const SizedBox(height: 28),
                const Text('Menu', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                const Text(
                  'Menu yang dimatikan tidak muncul waktu kasih stempel, tapi riwayatnya tetap tersimpan.',
                  style: TextStyle(color: AppColors.muted, height: 1.4),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _newMenu,
                        maxLength: 60,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _addMenu(),
                        decoration: const InputDecoration(hintText: 'Nama menu baru', counterText: ''),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      onPressed: _addMenu,
                      style: FilledButton.styleFrom(minimumSize: const Size(96, 52)),
                      child: const Text('Tambah'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                for (final item in _menu)
                  SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    title: Text(
                      item.name,
                      style: TextStyle(fontWeight: FontWeight.w600, color: item.active ? AppColors.ink : AppColors.muted),
                    ),
                    value: item.active,
                    activeThumbColor: Colors.white,
                    activeTrackColor: AppColors.primary,
                    onChanged: (v) => _toggle(item, v),
                  ),
              ],
            ),
    );
  }
}
