const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
];
const _monthsLong = [
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
];
const _days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];

String two(int n) => n.toString().padLeft(2, '0');

/// 29 Okt 2026
String fmtDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

/// 29 Okt
String fmtDayMonth(DateTime d) => '${d.day} ${_months[d.month - 1]}';

/// Kamis, 29 Oktober 2026
String fmtLongDate(DateTime d) =>
    '${_days[d.weekday - 1]}, ${d.day} ${_monthsLong[d.month - 1]} ${d.year}';

String fmtMonthYear(DateTime d) => '${_monthsLong[d.month - 1]} ${d.year}';

/// 08.05
String fmtTime(DateTime d) => '${two(d.hour)}.${two(d.minute)}';

String fmtRupiah(int v) {
  final s = v.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return 'Rp$buf';
}

String fmtQty(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

/// "2 jam lalu", "kemarin", atau tanggal.
String fmtAgo(DateTime t, DateTime now) {
  final diff = now.difference(t);
  if (diff.inMinutes < 1) return 'baru saja';
  if (diff.inMinutes < 60) return '${diff.inMinutes} mnt lalu';
  if (diff.inHours < 24) return '${diff.inHours} jam lalu';
  if (diff.inDays == 1) return 'kemarin';
  if (diff.inDays < 7) return '${diff.inDays} hari lalu';
  return fmtDate(t);
}

/// "Hari ini 17.00", "Besok 10.00", "Lewat 2 hari", atau tanggal.
String fmtDeadline(DateTime d, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final delta = day.difference(today).inDays;
  if (d.isBefore(now)) {
    final late = now.difference(d);
    if (late.inHours < 24) return 'Lewat ${late.inHours} jam';
    return 'Lewat ${late.inDays} hari';
  }
  if (delta == 0) return 'Hari ini ${fmtTime(d)}';
  if (delta == 1) return 'Besok ${fmtTime(d)}';
  return '${fmtDayMonth(d)} ${fmtTime(d)}';
}

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
