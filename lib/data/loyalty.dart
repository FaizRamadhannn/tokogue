import 'dart:math';

import 'backend.dart';

/// Data pelanggan dari program loyalty card (tabel loyalty_* di Supabase).
/// Cuma atasan yang boleh baca — dicek lagi di server (loyalty_report / loyalty_customer).

class MenuStat {
  const MenuStat({required this.name, required this.qty, required this.customers});
  final String name;
  final int qty;
  final int customers;

  factory MenuStat.fromJson(Map<String, dynamic> j) => MenuStat(
        name: j['name'] as String,
        qty: (j['qty'] as num?)?.toInt() ?? 0,
        customers: (j['customers'] as num?)?.toInt() ?? (j['visits'] as num?)?.toInt() ?? 0,
      );
}

class CustomerRow {
  const CustomerRow({
    required this.id,
    required this.code,
    required this.name,
    required this.phone,
    required this.stamps,
    required this.redeemed,
    required this.joinedAt,
    required this.visitsMonth,
    required this.visitsTotal,
    this.lastVisit,
    this.favorite,
  });
  final String id;
  final String code;
  final String name;
  final String phone;
  final int stamps;
  final int redeemed;
  final DateTime joinedAt;
  final int visitsMonth;
  final int visitsTotal;
  final DateTime? lastVisit;
  final String? favorite;

  String get initials =>
      name.trim().split(RegExp(r'\s+')).take(2).map((w) => w.isEmpty ? '' : w[0]).join().toUpperCase();

  factory CustomerRow.fromJson(Map<String, dynamic> j) => CustomerRow(
        id: j['id'] as String,
        code: j['code'] as String,
        name: j['name'] as String,
        phone: j['phone'] as String,
        stamps: (j['stamps'] as num).toInt(),
        redeemed: (j['redeemed'] as num).toInt(),
        joinedAt: DateTime.parse(j['created_at'] as String).toLocal(),
        visitsMonth: (j['visits_month'] as num?)?.toInt() ?? 0,
        visitsTotal: (j['visits_total'] as num?)?.toInt() ?? 0,
        lastVisit: j['last_visit'] == null ? null : DateTime.parse(j['last_visit'] as String).toLocal(),
        favorite: j['favorite'] as String?,
      );
}

class CustomerReport {
  const CustomerReport({
    required this.month,
    required this.membersTotal,
    required this.membersNew,
    required this.visits,
    required this.activeCustomers,
    required this.redeemed,
    required this.topMenu,
    required this.customers,
  });
  final DateTime month;
  final int membersTotal;
  final int membersNew;
  final int visits;
  final int activeCustomers;
  final int redeemed;
  final List<MenuStat> topMenu;
  final List<CustomerRow> customers;

  /// Rata-rata kunjungan per pelanggan yang datang bulan ini.
  double get avgVisits => activeCustomers == 0 ? 0 : visits / activeCustomers;

  factory CustomerReport.fromJson(Map<String, dynamic> j) => CustomerReport(
        month: DateTime.parse(j['month'] as String),
        membersTotal: (j['members_total'] as num).toInt(),
        membersNew: (j['members_new'] as num).toInt(),
        visits: (j['visits'] as num).toInt(),
        activeCustomers: (j['active_customers'] as num).toInt(),
        redeemed: (j['redeemed'] as num).toInt(),
        topMenu: [for (final m in (j['top_menu'] as List? ?? [])) MenuStat.fromJson(Map<String, dynamic>.from(m as Map))],
        customers: [for (final c in (j['customers'] as List? ?? [])) CustomerRow.fromJson(Map<String, dynamic>.from(c as Map))],
      );
}

class VisitItem {
  const VisitItem(this.name, this.qty);
  final String name;
  final int qty;
}

class Visit {
  const Visit(this.at, this.items);
  final DateTime at;
  final List<VisitItem> items;
}

class CustomerDetail {
  const CustomerDetail({
    required this.id,
    required this.code,
    required this.name,
    required this.phone,
    required this.stamps,
    required this.redeemed,
    required this.joinedAt,
    required this.favorites,
    required this.monthly,
    required this.visits,
  });
  final String id;
  final String code;
  final String name;
  final String phone;
  final int stamps;
  final int redeemed;
  final DateTime joinedAt;
  final List<MenuStat> favorites; // customers = jumlah kunjungan yang pesan menu ini
  final List<(DateTime, int)> monthly; // 6 bulan terakhir
  final List<Visit> visits; // 30 kunjungan terakhir

  factory CustomerDetail.fromJson(Map<String, dynamic> j) => CustomerDetail(
        id: j['id'] as String,
        code: j['code'] as String,
        name: j['name'] as String,
        phone: j['phone'] as String,
        stamps: (j['stamps'] as num).toInt(),
        redeemed: (j['redeemed'] as num).toInt(),
        joinedAt: DateTime.parse(j['created_at'] as String).toLocal(),
        favorites: [for (final m in (j['favorites'] as List? ?? [])) MenuStat.fromJson(Map<String, dynamic>.from(m as Map))],
        monthly: [
          for (final m in (j['monthly'] as List? ?? []))
            (DateTime.parse((m as Map)['month'] as String), (m['visits'] as num).toInt()),
        ],
        visits: [
          for (final v in (j['visits'] as List? ?? []))
            Visit(
              DateTime.parse((v as Map)['created_at'] as String).toLocal(),
              [for (final i in (v['items'] as List? ?? [])) VisitItem((i as Map)['name'] as String, (i['qty'] as num).toInt())],
            ),
        ],
      );
}

/// Ambil data dari server, atau data contoh kalau app jalan di mode demo.
class LoyaltyRepo {
  LoyaltyRepo(this.backend);
  final Backend? backend;

  Future<CustomerReport> report(DateTime month) async {
    final b = backend;
    if (b == null) return _Demo.report(month);
    final m = DateTime(month.year, month.month, 1);
    final res = await b.rpc('loyalty_report', {'p_month': '${m.year}-${_two(m.month)}-01'});
    return CustomerReport.fromJson(Map<String, dynamic>.from(res as Map));
  }

  Future<CustomerDetail?> customer(String id) async {
    final b = backend;
    if (b == null) return _Demo.detail(id);
    final res = await b.rpc('loyalty_customer', {'p_member': id});
    if (res == null) return null;
    return CustomerDetail.fromJson(Map<String, dynamic>.from(res as Map));
  }
}

String _two(int n) => n.toString().padLeft(2, '0');

// ---------------------------------------------------------------------------
// Data contoh (mode demo)
// ---------------------------------------------------------------------------
class _Demo {
  static const _menu = ['Ayam Geprek', 'Ayam Goreng Original', 'Ayam Crispy', 'Nasi Putih', 'Es Teh', 'Es Jeruk', 'Ayam Bakar'];
  static const _people = [
    ('Rina Putri', '081234567788'),
    ('Bima Santoso', '085711223344'),
    ('Sari Wulandari', '081399881100'),
    ('Dimas Pratama', '082144556677'),
    ('Ayu Lestari', '087820203030'),
    ('Fajar Nugroho', '081355667788'),
    ('Lina Marlina', '085233445566'),
    ('Yoga Saputra', '089611223344'),
  ];

  static List<Visit> _visitsOf(int person) {
    final r = Random(person * 97 + 13);
    final now = DateTime.now();
    final freq = [9, 6, 3, 1, 12, 4, 2, 0][person]; // kira-kira kunjungan per bulan
    final fav = [0, 2, 6, 1, 0, 2, 4, 3][person];
    final out = <Visit>[];
    for (var d = 0; d < 180; d++) {
      if (r.nextDouble() > freq / 30) continue;
      final at = DateTime(now.year, now.month, now.day, 11 + r.nextInt(9), r.nextInt(60)).subtract(Duration(days: d));
      final items = <String, int>{_menu[fav]: 1 + (r.nextDouble() < 0.3 ? 1 : 0)};
      if (r.nextDouble() < 0.7) items[_menu[4 + r.nextInt(2)]] = 1;
      if (r.nextDouble() < 0.35) {
        final extra = _menu[r.nextInt(_menu.length)];
        items[extra] = (items[extra] ?? 0) + 1;
      }
      out.add(Visit(at, [for (final e in items.entries) VisitItem(e.key, e.value)]));
    }
    return out;
  }

  static bool _inMonth(DateTime t, DateTime m) => t.year == m.year && t.month == m.month;

  static CustomerReport report(DateTime month) {
    final now = DateTime.now();
    final rows = <CustomerRow>[];
    final menuQty = <String, int>{};
    final menuPeople = <String, Set<int>>{};
    var visits = 0;
    for (var i = 0; i < _people.length; i++) {
      final all = _visitsOf(i);
      final inMonth = all.where((v) => _inMonth(v.at, month)).toList();
      visits += inMonth.length;
      for (final v in inMonth) {
        for (final it in v.items) {
          menuQty[it.name] = (menuQty[it.name] ?? 0) + it.qty;
          (menuPeople[it.name] ??= {}).add(i);
        }
      }
      final favCount = <String, int>{};
      for (final v in all) {
        for (final it in v.items) {
          favCount[it.name] = (favCount[it.name] ?? 0) + it.qty;
        }
      }
      final fav = favCount.entries.isEmpty ? null : (favCount.entries.toList()..sort((a, b) => b.value - a.value)).first.key;
      rows.add(CustomerRow(
        id: 'demo-$i',
        code: 'LC-DEM${i}X',
        name: _people[i].$1,
        phone: _people[i].$2,
        stamps: all.length % 10,
        redeemed: all.length ~/ 10,
        joinedAt: now.subtract(Duration(days: 30 + i * 21)),
        visitsMonth: inMonth.length,
        visitsTotal: all.length,
        lastVisit: all.isEmpty ? null : all.first.at,
        favorite: fav,
      ));
    }
    rows.sort((a, b) => b.visitsMonth != a.visitsMonth
        ? b.visitsMonth - a.visitsMonth
        : (b.lastVisit ?? DateTime(2000)).compareTo(a.lastVisit ?? DateTime(2000)));
    final top = menuQty.entries.map((e) => MenuStat(name: e.key, qty: e.value, customers: menuPeople[e.key]!.length)).toList()
      ..sort((a, b) => b.qty - a.qty);
    return CustomerReport(
      month: DateTime(month.year, month.month, 1),
      membersTotal: rows.length,
      membersNew: _inMonth(now, month) ? 2 : 0,
      visits: visits,
      activeCustomers: rows.where((r) => r.visitsMonth > 0).length,
      redeemed: _inMonth(now, month) ? 3 : 1,
      topMenu: top.take(10).toList(),
      customers: rows,
    );
  }

  static CustomerDetail? detail(String id) {
    final i = int.tryParse(id.replaceFirst('demo-', ''));
    if (i == null || i < 0 || i >= _people.length) return null;
    final all = _visitsOf(i);
    final now = DateTime.now();
    final fav = <String, (int, int)>{};
    for (final v in all) {
      for (final it in v.items) {
        final cur = fav[it.name] ?? (0, 0);
        fav[it.name] = (cur.$1 + it.qty, cur.$2 + 1);
      }
    }
    final favs = fav.entries.map((e) => MenuStat(name: e.key, qty: e.value.$1, customers: e.value.$2)).toList()
      ..sort((a, b) => b.qty - a.qty);
    return CustomerDetail(
      id: id,
      code: 'LC-DEM${i}X',
      name: _people[i].$1,
      phone: _people[i].$2,
      stamps: all.length % 10,
      redeemed: all.length ~/ 10,
      joinedAt: now.subtract(Duration(days: 30 + i * 21)),
      favorites: favs.take(5).toList(),
      monthly: [
        for (var k = 5; k >= 0; k--)
          () {
            final m = DateTime(now.year, now.month - k, 1);
            return (m, all.where((v) => _inMonth(v.at, m)).length);
          }(),
      ],
      visits: all.take(30).toList(),
    );
  }
}
