import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/app_state.dart';
import '../data/backend.dart';
import '../data/format.dart';
import '../data/loyalty.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Database pelanggan loyalty card — khusus atasan.
/// Menu terlaris, berapa kali tiap pelanggan datang per bulan, dan menu favoritnya.
class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

enum _Sort { visits, recent, name }

class _CustomersScreenState extends State<CustomersScreen> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);
  Future<CustomerReport>? _future;
  String _query = '';
  _Sort _sort = _Sort.visits;

  LoyaltyRepo get _repo => LoyaltyRepo(AppScope.read(context).backend);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _repo.report(_month);
  }

  void _load() => setState(() => _future = _repo.report(_month));

  void _shift(int delta) {
    final next = DateTime(_month.year, _month.month + delta, 1);
    final now = DateTime.now();
    if (next.isAfter(DateTime(now.year, now.month, 1))) return;
    _month = next;
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isCurrent = _month.year == now.year && _month.month == now.month;
    return Scaffold(
      appBar: AppBar(title: const Text('Pelanggan')),
      body: Column(children: [
        // pemilih bulan
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
          child: Row(children: [
            IconButton(tooltip: 'Bulan sebelumnya', onPressed: () => _shift(-1), icon: const Icon(Icons.chevron_left_rounded)),
            Expanded(
              child: Text(fmtMonthYear(_month),
                  textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ),
            IconButton(
              tooltip: 'Bulan berikutnya',
              onPressed: isCurrent ? null : () => _shift(1),
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ]),
        ),
        Expanded(
          child: FutureBuilder<CustomerReport>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator(color: AppColors.primary));
              }
              if (snap.hasError) {
                return ListView(children: [
                  EmptyState(icon: Icons.cloud_off_rounded, title: 'Data pelanggan belum bisa dibuka', body: _errorText(snap.error!)),
                  Center(child: TextButton(onPressed: _load, child: const Text('Coba lagi'))),
                ]);
              }
              return RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () async {
                  _load();
                  await _future;
                },
                child: _body(snap.data!),
              );
            },
          ),
        ),
      ]),
    );
  }

  Widget _body(CustomerReport r) {
    final q = _query.toLowerCase();
    final list = r.customers
        .where((c) => q.isEmpty || '${c.name} ${c.phone} ${c.code}'.toLowerCase().contains(q))
        .toList();
    switch (_sort) {
      case _Sort.visits:
        break; // server sudah urut: paling sering datang bulan ini
      case _Sort.recent:
        list.sort((a, b) => (b.lastVisit ?? DateTime(2000)).compareTo(a.lastVisit ?? DateTime(2000)));
      case _Sort.name:
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }
    final maxQty = r.topMenu.isEmpty ? 1 : r.topMenu.first.qty;
    final now = DateTime.now();
    final inLabel = r.month.year == now.year && r.month.month == now.month
        ? 'bulan ini'
        : 'di ${fmtMonthYear(r.month).split(' ').first}';

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        Row(children: [
          _Stat(label: 'Pelanggan datang', value: '${r.activeCustomers}', note: 'dari ${r.membersTotal} member', color: AppColors.primary, soft: AppColors.primarySoft),
          const SizedBox(width: 10),
          _Stat(label: 'Total kunjungan', value: '${r.visits}', note: inLabel, color: AppColors.blue, soft: AppColors.blueSoft),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _Stat(
            label: 'Rata-rata datang',
            value: '${r.avgVisits.toStringAsFixed(r.avgVisits >= 10 || r.avgVisits == r.avgVisits.roundToDouble() ? 0 : 1)}×',
            note: 'per pelanggan',
            color: AppColors.teal,
            soft: AppColors.tealSoft,
          ),
          const SizedBox(width: 10),
          _Stat(label: 'Member baru', value: '${r.membersNew}', note: '${r.redeemed} hadiah ditukar', color: AppColors.orange, soft: AppColors.orangeSoft),
        ]),

        const _Heading('Menu paling sering dipesan'),
        if (r.topMenu.isEmpty)
          _Muted('Belum ada pesanan tercatat $inLabel. Menu dicatat kasir waktu ngasih stempel.')
        else
          CardBox(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Column(children: [
              for (final (i, m) in r.topMenu.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      SizedBox(
                        width: 22,
                        child: Text('${i + 1}', style: TextStyle(fontWeight: FontWeight.w800, color: i < 3 ? AppColors.primary : AppColors.muted)),
                      ),
                      Expanded(child: Text(m.name, style: const TextStyle(fontWeight: FontWeight.w700))),
                      Text('${m.qty} porsi', style: const TextStyle(fontWeight: FontWeight.w800)),
                    ]),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.only(left: 22),
                      child: Row(children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: m.qty / maxQty,
                              minHeight: 6,
                              color: i < 3 ? AppColors.primary : AppColors.goldLight,
                              backgroundColor: AppColors.bg,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text('${m.customers} orang', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                      ]),
                    ),
                  ]),
                ),
            ]),
          ),

        _Heading('Daftar pelanggan', subtitle: '${r.customers.length} member · urut ${_sortLabel(_sort)}'),
        TextField(
          onChanged: (v) => setState(() => _query = v.trim()),
          decoration: InputDecoration(
            hintText: 'Cari nama, nomor HP, atau ID',
            prefixIcon: const Icon(Icons.search_rounded),
            isDense: true,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.line)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.line)),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 8, children: [
          for (final s in _Sort.values)
            ChoiceChip(
              label: Text(_sortLabel(s)),
              selected: _sort == s,
              onSelected: (_) => setState(() => _sort = s),
              selectedColor: AppColors.primarySoft,
              labelStyle: TextStyle(fontWeight: FontWeight.w600, color: _sort == s ? AppColors.primary : AppColors.ink),
              side: const BorderSide(color: AppColors.line),
              showCheckmark: false,
            ),
        ]),
        const SizedBox(height: 10),
        if (list.isEmpty)
          _Muted(r.customers.isEmpty ? 'Belum ada member. Pelanggan daftar lewat halaman loyalty card.' : 'Nggak ada pelanggan yang cocok.')
        else
          for (final c in list)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: CardBox(
                padding: const EdgeInsets.all(12),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CustomerDetailScreen(id: c.id, name: c.name))),
                child: Row(children: [
                  _Initials(c.initials, seed: c.code),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(
                        c.lastVisit == null ? 'Belum pernah datang' : 'Terakhir ${fmtAgo(c.lastVisit!, DateTime.now())}',
                        style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
                      ),
                      if (c.favorite != null) ...[
                        const SizedBox(height: 6),
                        Pill('Suka ${c.favorite}', color: AppColors.primary, background: AppColors.primarySoft, icon: Icons.favorite_rounded),
                      ],
                    ]),
                  ),
                  const SizedBox(width: 8),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('${c.visitsMonth}×',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: c.visitsMonth > 0 ? AppColors.ink : AppColors.muted)),
                    Text(inLabel, style: const TextStyle(color: AppColors.muted, fontSize: 11.5)),
                  ]),
                ]),
              ),
            ),
      ],
    );
  }

  static String _sortLabel(_Sort s) => switch (s) {
        _Sort.visits => 'Paling sering',
        _Sort.recent => 'Terakhir datang',
        _Sort.name => 'Nama',
      };
}

/// Detail satu pelanggan: menu favorit, kunjungan 6 bulan, riwayat pesanan.
class CustomerDetailScreen extends StatefulWidget {
  const CustomerDetailScreen({super.key, required this.id, required this.name});
  final String id;
  final String name;

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  Future<CustomerDetail?>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= LoyaltyRepo(AppScope.read(context).backend).customer(widget.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.name)),
      body: FutureBuilder<CustomerDetail?>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }
          if (snap.hasError || snap.data == null) {
            return EmptyState(
              icon: Icons.person_off_rounded,
              title: 'Data pelanggan nggak ketemu',
              body: snap.hasError ? _errorText(snap.error!) : null,
            );
          }
          return _body(snap.data!);
        },
      ),
    );
  }

  Widget _body(CustomerDetail d) {
    final maxMonth = d.monthly.fold<int>(1, (m, e) => e.$2 > m ? e.$2 : m);
    final total = d.visits.length;
    return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
      CardBox(
        child: Row(children: [
          _Initials(d.name.trim().split(RegExp(r'\s+')).take(2).map((w) => w.isEmpty ? '' : w[0]).join().toUpperCase(), seed: d.code, size: 52),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(d.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
              const SizedBox(height: 2),
              Text('${d.phone} · ${d.code}', style: const TextStyle(color: AppColors.muted, fontSize: 13)),
              const SizedBox(height: 2),
              Text('Member sejak ${fmtDate(d.joinedAt)}', style: const TextStyle(color: AppColors.muted, fontSize: 13)),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        onPressed: () {
          Clipboard.setData(ClipboardData(text: '$loyaltyWebBase?card=${Uri.encodeComponent(d.id)}'));
          showSnack(context, 'Link kartu ${d.name} disalin. Kirim lewat WA kalau dia ganti HP.');
        },
        icon: const Icon(Icons.link_rounded),
        label: const Text('Salin link kartu'),
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
      ),
      const SizedBox(height: 10),
      Row(children: [
        _Stat(label: 'Stempel sekarang', value: '${d.stamps}', note: '${d.redeemed}× tukar hadiah', color: AppColors.primary, soft: AppColors.primarySoft),
        const SizedBox(width: 10),
        _Stat(
          label: 'Bulan ini',
          value: '${d.monthly.isEmpty ? 0 : d.monthly.last.$2}×',
          note: 'datang ke toko',
          color: AppColors.blue,
          soft: AppColors.blueSoft,
        ),
      ]),

      const _Heading('Kunjungan 6 bulan terakhir'),
      CardBox(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
        child: SizedBox(
          height: 140,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (final (m, n) in d.monthly)
              Expanded(
                child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Text('$n', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: n > 0 ? AppColors.ink : AppColors.muted)),
                  const SizedBox(height: 4),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: n / maxMonth),
                    duration: Motion.slow,
                    curve: Motion.curve,
                    builder: (_, v, _) => Container(
                      width: 22,
                      height: 4 + 80 * v,
                      decoration: BoxDecoration(
                        color: m == d.monthly.last.$1 ? AppColors.primary : AppColors.goldLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(fmtMonthYear(m).substring(0, 3), style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                ]),
              ),
          ]),
        ),
      ),

      const _Heading('Menu favorit'),
      if (d.favorites.isEmpty)
        const _Muted('Belum ada pesanan tercatat.')
      else
        CardBox(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Column(children: [
            for (final (i, f) in d.favorites.indexed) ...[
              if (i > 0) const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(children: [
                  Icon(i == 0 ? Icons.favorite_rounded : Icons.restaurant_rounded, size: 18, color: i == 0 ? AppColors.primary : AppColors.muted),
                  const SizedBox(width: 10),
                  Expanded(child: Text(f.name, style: const TextStyle(fontWeight: FontWeight.w700))),
                  Text('${f.qty} porsi', style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(width: 8),
                  Text('· ${f.customers}× pesan', style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
                ]),
              ),
            ],
          ]),
        ),

      _Heading('Riwayat kunjungan', subtitle: total >= 30 ? '30 kunjungan terakhir' : null),
      if (d.visits.isEmpty)
        const _Muted('Belum pernah datang sejak daftar.')
      else
        for (final v in d.visits)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: CardBox(
              padding: const EdgeInsets.all(12),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(
                  width: 74,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(fmtDayMonth(v.at), style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text(fmtTime(v.at), style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
                  ]),
                ),
                Expanded(
                  child: v.items.isEmpty
                      ? const Text('Menu nggak dicatat', style: TextStyle(color: AppColors.muted))
                      : Wrap(spacing: 6, runSpacing: 6, children: [
                          for (final it in v.items)
                            Pill('${it.name} ×${it.qty}', color: AppColors.ink, background: AppColors.bg),
                        ]),
                ),
              ]),
            ),
          ),
    ]);
  }
}

// ---------------------------------------------------------------------------

String _errorText(Object e) {
  if (e is PostgrestException) {
    if (e.message.contains('not_manager')) return 'Halaman ini khusus atasan.';
    if (e.code == 'PGRST202' || e.message.contains('Could not find the function')) {
      return 'Fitur pelanggan belum dipasang di server. Admin: jalankan supabase/loyalty.sql di Supabase.';
    }
  }
  return friendlyError(e);
}

class _Heading extends StatelessWidget {
  const _Heading(this.title, {this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 24, 4, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(subtitle!, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
            ),
        ]),
      );
}

class _Muted extends StatelessWidget {
  const _Muted(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Text(text, style: const TextStyle(color: AppColors.muted, height: 1.45)),
      );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.note, required this.color, required this.soft});
  final String label;
  final String value;
  final String note;
  final Color color;
  final Color soft;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(16)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 26)),
            Text(note, style: TextStyle(color: color.withValues(alpha: 0.75), fontSize: 12)),
          ]),
        ),
      );
}

class _Initials extends StatelessWidget {
  const _Initials(this.text, {required this.seed, this.size = 44});
  final String text;
  final String seed;
  final double size;

  static const _palette = [AppColors.primary, AppColors.blue, AppColors.orange, AppColors.purple, AppColors.teal, AppColors.pink];

  @override
  Widget build(BuildContext context) {
    final c = _palette[seed.codeUnits.fold(0, (a, b) => a + b) % _palette.length];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: c.withValues(alpha: 0.12), shape: BoxShape.circle),
      child: Text(text, style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: size * 0.36)),
    );
  }
}
