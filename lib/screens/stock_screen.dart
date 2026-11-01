import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../data/format.dart';
import '../data/models.dart';
import '../theme.dart';
import '../widgets/common.dart';

class StockScreen extends StatelessWidget {
  const StockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final items = [...state.stock]..sort((a, b) {
        if (a.isLow != b.isLow) return a.isLow ? -1 : 1;
        return a.name.compareTo(b.name);
      });
    final low = items.where((s) => s.isLow).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Stok bahan')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () => _addItem(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Bahan baru', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 96), children: [
        Row(children: [
          _Summary(label: 'Total bahan', value: '${items.length}', color: AppColors.primary, soft: AppColors.primarySoft),
          const SizedBox(width: 12),
          _Summary(label: 'Stok menipis', value: '$low', color: AppColors.red, soft: AppColors.redSoft),
        ]),
        const SizedBox(height: 16),
        for (final s in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: CardBox(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => StockDetailScreen(item: s))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
                  if (s.isLow) const Pill('Menipis', color: AppColors.red, background: AppColors.redSoft, icon: Icons.warning_amber_rounded),
                ]),
                const SizedBox(height: 8),
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(fmtQty(s.qty), style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: s.isLow ? AppColors.red : AppColors.ink)),
                  const SizedBox(width: 4),
                  Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(s.unit, style: const TextStyle(color: AppColors.muted))),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('min. ${fmtQty(s.min)} ${s.unit}', style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
                  ),
                ]),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (s.qty / (s.min * 3)).clamp(0.02, 1.0),
                    minHeight: 6,
                    backgroundColor: AppColors.bg,
                    color: s.isLow ? AppColors.red : AppColors.primary,
                  ),
                ),
              ]),
            ),
          ),
      ]),
    );
  }

  void _addItem(BuildContext context) {
    final name = TextEditingController();
    final unit = TextEditingController(text: 'kg');
    final qty = TextEditingController();
    final min = TextEditingController();
    showAppSheet(
      context,
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Bahan baru', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Nama bahan')),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(controller: qty, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Stok awal'))),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: unit, decoration: const InputDecoration(labelText: 'Satuan'))),
          ]),
          const SizedBox(height: 10),
          TextField(controller: min, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Batas minimum')),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () async {
              final q = double.tryParse(qty.text.replaceAll(',', '.'));
              final m = double.tryParse(min.text.replaceAll(',', '.'));
              if (name.text.trim().isEmpty || q == null || m == null) {
                showSnack(context, 'Lengkapi nama, stok, dan batas minimum.', error: true);
                return;
              }
              final nav = Navigator.of(context);
              final ok = await runAction(context, AppScope.read(context).addStockItem(name.text.trim(), unit.text.trim(), q, m),
                  success: '${name.text.trim()} ditambahkan.');
              if (ok) nav.pop();
            },
            child: const Text('Simpan'),
          ),
        ]),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.label, required this.value, required this.color, required this.soft});
  final String label;
  final String value;
  final Color color;
  final Color soft;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 26)),
        ]),
      ),
    );
  }
}

class StockDetailScreen extends StatefulWidget {
  const StockDetailScreen({super.key, required this.item});
  final StockItem item;

  @override
  State<StockDetailScreen> createState() => _StockDetailScreenState();
}

class _StockDetailScreenState extends State<StockDetailScreen> {
  final _amount = TextEditingController(text: '1');
  final _note = TextEditingController();

  bool _busy = false;

  // Ambil versi terbaru (di mode live data dimuat ulang jadi objek baru).
  StockItem _item(AppState state) =>
      state.stock.firstWhere((x) => x.id == widget.item.id, orElse: () => widget.item);

  Future<void> _apply(bool add) async {
    final v = double.tryParse(_amount.text.replaceAll(',', '.'));
    if (v == null || v <= 0) {
      showSnack(context, 'Isi jumlah yang valid.', error: true);
      return;
    }
    final state = AppScope.read(context);
    final s = _item(state);
    final note = _note.text.trim().isEmpty ? (add ? 'Bahan masuk' : 'Pemakaian') : _note.text.trim();
    setState(() => _busy = true);
    final ok = await runAction(context, state.adjustStock(s, add ? v : -v, note),
        success: '${s.name}: ${add ? '+' : '-'}${fmtQty(v)} ${s.unit}');
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) _note.clear();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final s = _item(state);
    final now = DateTime.now();
    return Scaffold(
      appBar: AppBar(title: Text(s.name)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: s.isLow ? AppColors.redSoft : AppColors.primarySoft, borderRadius: BorderRadius.circular(18)),
          child: Column(children: [
            Text('Stok sekarang', style: TextStyle(color: s.isLow ? AppColors.red : AppColors.primaryDark, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('${fmtQty(s.qty)} ${s.unit}', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: s.isLow ? AppColors.red : AppColors.primaryDark)),
            Text('Batas minimum ${fmtQty(s.min)} ${s.unit}', style: TextStyle(color: s.isLow ? AppColors.red : AppColors.primaryDark, fontSize: 13)),
          ]),
        ),
        const SizedBox(height: 18),
        const Text('Update stok', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'Jumlah', suffixText: s.unit),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(flex: 2, child: TextField(controller: _note, decoration: const InputDecoration(labelText: 'Catatan (opsional)'))),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.red, side: const BorderSide(color: AppColors.red, width: 1.5)),
              onPressed: _busy ? null : () => _apply(false),
              icon: const Icon(Icons.remove_rounded),
              label: const Text('Pakai'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(onPressed: _busy ? null : () => _apply(true), icon: const Icon(Icons.add_rounded), label: const Text('Masuk')),
          ),
        ]),
        const SectionTitle('Riwayat perubahan'),
        if (s.logs.isEmpty)
          const Text('Belum ada perubahan.', style: TextStyle(color: AppColors.muted))
        else
          for (final l in s.logs)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Avatar(state.byId(l.byId), size: 36),
              title: Text(l.note, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('${state.byId(l.byId).firstName} · ${fmtAgo(l.time, now)}'),
              trailing: Text('${l.delta > 0 ? '+' : ''}${fmtQty(l.delta)} ${s.unit}',
                  style: TextStyle(fontWeight: FontWeight.w800, color: l.delta > 0 ? AppColors.primary : AppColors.red)),
            ),
      ]),
    );
  }
}
