import 'dart:math';

import 'backend.dart';
import 'models.dart';

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

/// Jumlah stempel & tukar hadiah yang dikasih 1 staf dalam sebulan.
class StaffStat {
  const StaffStat({required this.name, required this.stamps, required this.redeems});
  final String name;
  final int stamps;
  final int redeems;

  factory StaffStat.fromJson(Map<String, dynamic> j) => StaffStat(
    name: j['name'] as String? ?? '-',
    stamps: (j['stamps'] as num?)?.toInt() ?? 0,
    redeems: (j['redeems'] as num?)?.toInt() ?? 0,
  );
}

/// Karyawan (bukan atasan) + apakah atasan mengizinkan dia kasih stempel.
class StaffMember {
  const StaffMember({required this.id, required this.name, required this.position, required this.allowed});
  final String id;
  final String name;
  final String position;
  final bool allowed;

  factory StaffMember.fromJson(Map<String, dynamic> j) => StaffMember(
    id: j['id'] as String,
    name: j['name'] as String,
    position: j['position'] as String? ?? '-',
    allowed: j['allowed'] as bool? ?? false,
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

  String get initials => name.trim().split(RegExp(r'\s+')).take(2).map((w) => w.isEmpty ? '' : w[0]).join().toUpperCase();

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
    this.staff = const [],
  });
  final DateTime month;
  final int membersTotal;
  final int membersNew;
  final int visits;
  final int activeCustomers;
  final int redeemed;
  final List<MenuStat> topMenu;
  final List<CustomerRow> customers;
  final List<StaffStat> staff;

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
    staff: [for (final x in (j['staff'] as List? ?? [])) StaffStat.fromJson(Map<String, dynamic>.from(x as Map))],
  );
}

class VisitItem {
  const VisitItem(this.name, this.qty);
  final String name;
  final int qty;
}

class Visit {
  const Visit(this.at, this.items, {this.staff});
  final DateTime at;
  final List<VisitItem> items;
  final String? staff; // siapa yang ngasih stempel
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
        Visit(DateTime.parse((v as Map)['created_at'] as String).toLocal(), [
          for (final i in (v['items'] as List? ?? [])) VisitItem((i as Map)['name'] as String, (i['qty'] as num).toInt()),
        ], staff: v['staff'] as String?),
    ],
  );
}

/// Kartu member hasil scan (tanpa nomor HP).
class MemberCard {
  const MemberCard({
    required this.id,
    required this.code,
    required this.name,
    required this.stamps,
    required this.target,
    required this.redeemed,
    required this.reward,
  });
  final String id;
  final String code;
  final String name;
  final int stamps;
  final int target;
  final int redeemed;
  final String reward;

  bool get full => stamps >= target;

  factory MemberCard.fromJson(Map<String, dynamic> j) => MemberCard(
    id: j['token'] as String,
    code: j['code'] as String,
    name: j['name'] as String,
    stamps: (j['stamps'] as num).toInt(),
    target: (j['target'] as num).toInt(),
    redeemed: (j['redeemed'] as num?)?.toInt() ?? 0,
    reward: j['reward'] as String? ?? '',
  );
}

class MenuItem {
  const MenuItem({required this.id, required this.name, required this.active});
  final int id;
  final String name;
  final bool active;

  factory MenuItem.fromJson(Map<String, dynamic> j) =>
      MenuItem(id: (j['id'] as num).toInt(), name: j['name'] as String, active: j['active'] as bool? ?? true);
}

class LoyaltySettings {
  const LoyaltySettings({required this.store, required this.target, required this.reward, required this.cooldownMin});
  final String store;
  final int target;
  final String reward;
  final int cooldownMin;

  factory LoyaltySettings.fromJson(Map<String, dynamic> j) => LoyaltySettings(
    store: j['store'] as String,
    target: (j['target'] as num).toInt(),
    reward: j['reward'] as String,
    cooldownMin: (j['stamp_cooldown_min'] as num?)?.toInt() ?? 0,
  );
}

/// Ambil kode member (LC-XXXXX) dari isi QR: kode polos, `LOYALTY:LC-...`,
/// atau link lama `.../kartu/?scan=LC-...`.
String? extractMemberCode(String raw) {
  final t = raw.trim();
  final fromLink = RegExp(r'[?&]scan=([^&#\s]+)').firstMatch(t);
  final text = fromLink != null ? Uri.decodeComponent(fromLink.group(1)!) : t;
  final m = RegExp(r'LC-[A-Z0-9]{3,10}', caseSensitive: false).firstMatch(text);
  return m?.group(0)?.toUpperCase();
}

/// Link halaman kartu pelanggan (dipakai untuk poster QR).
const loyaltyWebBase = 'https://tokogue-sigma.vercel.app/kartu/';

/// Ambil data dari server, atau data contoh kalau app jalan di mode demo.
class LoyaltyRepo {
  LoyaltyRepo(this.backend);
  final Backend? backend;

  Future<MemberCard?> lookup(String code) async {
    final b = backend;
    if (b == null) return _Demo.lookup(code);
    final res = await b.rpc('loyalty_lookup', {'p_code': code});
    if (res == null) return null;
    return MemberCard.fromJson(Map<String, dynamic>.from(res as Map));
  }

  /// items: menu_id → qty
  Future<MemberCard> addStamp(String memberId, Map<int, int> items) async {
    final b = backend;
    if (b == null) return _Demo.addStamp(memberId, items);
    final res = await b.rpc('loyalty_add_stamp', {
      'p_member': memberId,
      'p_items': [
        for (final e in items.entries)
          if (e.value > 0) {'menu_id': e.key, 'qty': e.value},
      ],
    });
    return MemberCard.fromJson(Map<String, dynamic>.from(res as Map));
  }

  Future<MemberCard> redeem(String memberId) async {
    final b = backend;
    if (b == null) return _Demo.redeem(memberId);
    final res = await b.rpc('loyalty_redeem', {'p_member': memberId});
    return MemberCard.fromJson(Map<String, dynamic>.from(res as Map));
  }

  Future<List<MenuItem>> menu({bool includeInactive = false}) async {
    final b = backend;
    if (b == null) {
      return [
        for (final m in _Demo.menuItems)
          if (includeInactive || m.active) m,
      ];
    }
    var q = b.db.from('loyalty_menu').select('id, name, active');
    if (!includeInactive) q = q.eq('active', true);
    final rows = await q.order('name');
    return [for (final r in rows) MenuItem.fromJson(r)];
  }

  Future<void> addMenu(String name) async {
    final b = backend;
    if (b == null) return _Demo.addMenu(name);
    await b.db.from('loyalty_menu').insert({'name': name.trim()});
  }

  Future<void> setMenuActive(int id, bool active) async {
    final b = backend;
    if (b == null) return _Demo.setMenuActive(id, active);
    await b.db.from('loyalty_menu').update({'active': active}).eq('id', id);
  }

  /// Apakah akun yang login boleh scan & kasih stempel.
  Future<bool> canStamp() async {
    final b = backend;
    if (b == null) return false;
    return (await b.rpc('loyalty_is_staff')) == true;
  }

  /// Karyawan non-atasan + izin kasih stempelnya (khusus atasan).
  Future<List<StaffMember>> staffList({List<Employee> demoEmployees = const []}) async {
    final b = backend;
    if (b == null) {
      return [
        for (final e in demoEmployees)
          if (e.role != Role.atasan)
            StaffMember(id: e.id, name: e.name, position: e.position, allowed: demoStampStaff.contains(e.id)),
      ];
    }
    final res = await b.rpc('loyalty_staff_list');
    return [for (final r in (res as List? ?? [])) StaffMember.fromJson(Map<String, dynamic>.from(r as Map))];
  }

  Future<void> setStaff(String profileId, bool allowed) async {
    final b = backend;
    if (b == null) {
      allowed ? demoStampStaff.add(profileId) : demoStampStaff.remove(profileId);
      return;
    }
    await b.rpc('loyalty_set_staff', {'p_profile': profileId, 'p_allowed': allowed});
  }

  Future<LoyaltySettings> settings() async {
    final b = backend;
    if (b == null) return _Demo.settings;
    final r = await b.db.from('loyalty_settings').select('store, target, reward, stamp_cooldown_min').eq('id', 1).single();
    return LoyaltySettings.fromJson(r);
  }

  Future<void> saveSettings(LoyaltySettings s) async {
    final b = backend;
    if (b == null) {
      _Demo.settings = s;
      return;
    }
    await b.db
        .from('loyalty_settings')
        .update({'store': s.store.trim(), 'target': s.target, 'reward': s.reward.trim(), 'stamp_cooldown_min': s.cooldownMin})
        .eq('id', 1);
  }

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

/// Mode demo: karyawan yang diizinkan kasih stempel (awalnya Sari si kasir).
final demoStampStaff = <String>{'e2'};

String _two(int n) => n.toString().padLeft(2, '0');

// ---------------------------------------------------------------------------
// Data contoh (mode demo)
// ---------------------------------------------------------------------------
class _Demo {
  static LoyaltySettings settings = const LoyaltySettings(
    store: 'Ayam Garing Juara',
    target: 10,
    reward: '1 Paket Ayam Geprek + Es Teh',
    cooldownMin: 0,
  );
  static final menuItems = <MenuItem>[for (final (i, n) in _menu.indexed) MenuItem(id: i + 1, name: n, active: true)];
  static final _stamps = <int, int>{};
  static final _redeemed = <int, int>{};

  static int? _index(String idOrCode) {
    final c = idOrCode.toUpperCase();
    final m = RegExp(r'^(?:DEMO-|LC-DEM)(\d+)X?$').firstMatch(c);
    final i = m == null ? null : int.tryParse(m.group(1)!);
    return i != null && i >= 0 && i < _people.length ? i : null;
  }

  static MemberCard _card(int i) {
    final all = _visitsOf(i).length;
    return MemberCard(
      id: 'demo-$i',
      code: 'LC-DEM${i}X',
      name: _people[i].$1,
      stamps: _stamps[i] ?? all % settings.target,
      target: settings.target,
      redeemed: _redeemed[i] ?? all ~/ settings.target,
      reward: settings.reward,
    );
  }

  static MemberCard? lookup(String code) {
    final i = _index(code);
    return i == null ? null : _card(i);
  }

  static MemberCard addStamp(String id, Map<int, int> items) {
    if (items.values.every((q) => q <= 0) && menuItems.any((m) => m.active)) throw Exception('items_required');
    final i = _index(id)!;
    final c = _card(i);
    if (c.full) throw Exception('card_full_or_missing');
    _stamps[i] = c.stamps + 1;
    return _card(i);
  }

  static MemberCard redeem(String id) {
    final i = _index(id)!;
    final c = _card(i);
    if (!c.full) throw Exception('not_ready');
    _stamps[i] = 0;
    _redeemed[i] = c.redeemed + 1;
    return _card(i);
  }

  static void addMenu(String name) => menuItems.add(MenuItem(id: menuItems.length + 1, name: name.trim(), active: true));

  static void setMenuActive(int id, bool active) {
    final k = menuItems.indexWhere((m) => m.id == id);
    if (k >= 0) menuItems[k] = MenuItem(id: id, name: menuItems[k].name, active: active);
  }

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
      out.add(
        Visit(at, [
          for (final e in items.entries) VisitItem(e.key, e.value),
        ], staff: r.nextDouble() < 0.6 ? 'Sari Wulandari' : 'Dimas Aditya'),
      );
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
      rows.add(
        CustomerRow(
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
        ),
      );
    }
    rows.sort(
      (a, b) => b.visitsMonth != a.visitsMonth
          ? b.visitsMonth - a.visitsMonth
          : (b.lastVisit ?? DateTime(2000)).compareTo(a.lastVisit ?? DateTime(2000)),
    );
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
      staff: [
        StaffStat(name: 'Sari Wulandari', stamps: (visits * 0.6).round(), redeems: _inMonth(now, month) ? 2 : 1),
        StaffStat(name: 'Dimas Aditya', stamps: visits - (visits * 0.6).round(), redeems: _inMonth(now, month) ? 1 : 0),
      ],
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
