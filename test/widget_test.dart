import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tokogue_app/data/app_state.dart';
import 'package:tokogue_app/data/models.dart';
import 'package:tokogue_app/main.dart';

void main() {
  testWidgets('login demo lalu beranda tampil', (tester) async {
    // Ukuran layar HP (390 x 1400 titik) supaya akun demo kelihatan.
    tester.view.physicalSize = const Size(1170, 4200);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final state = AppState();
    await tester.pumpWidget(TokogueApp(state: state));
    expect(find.text('Masuk ke akun kamu'), findsOneWidget);

    await tester.tap(find.text('Budi Santoso'));
    await tester.pumpAndSettle();
    expect(find.text('Absen'), findsWidgets);
    expect(find.text('Tugas kamu'), findsOneWidget);
  });

  test('absen di luar radius ditolak', () {
    final state = AppState();
    state.loginAs(state.employees.firstWhere((e) => e.id == 'e1'));
    final n = DateTime.now();
    final inShift = DateTime(n.year, n.month, n.day, 8, 3); // Budi shift pagi
    expect(state.clockIn(distance: 240, selfie: true, at: inShift), isNotNull);
    expect(state.clockIn(distance: 38, selfie: false, at: inShift), isNotNull);
    expect(state.clockIn(distance: 38, selfie: true, at: inShift), isNull);
    expect(state.todayRecord('e1')?.checkIn, isNotNull);
  });

  test('absen masuk di luar jam shift ditolak', () {
    final state = AppState();
    state.loginAs(state.employees.firstWhere((e) => e.id == 'e1'));
    final n = DateTime.now();
    expect(state.clockIn(distance: 38, selfie: true, at: DateTime(n.year, n.month, n.day, 6, 30)), isNotNull);
    expect(state.clockIn(distance: 38, selfie: true, at: DateTime(n.year, n.month, n.day, 21)), isNotNull);
  });

  test('potongan telat Rp5.000 per 5 menit', () {
    final d = DateTime(2026, 10, 29);
    final r = AttendanceRecord(employeeId: 'x', date: d, shift: Shift.pagi, checkIn: DateTime(2026, 10, 29, 8, 12));
    expect(r.lateMinutes, 12);
    expect(r.penalty, 10000);
  });

  test('tugas tidak bisa dikirim tanpa bukti', () async {
    final state = AppState();
    state.loginAs(state.employees.firstWhere((e) => e.id == 'e1'));
    final t = state.tasks.firstWhere((t) => t.id == 't1');
    await state.startTask(t);
    expect(await state.submitTask(t, ''), isNotNull);
    await state.addProof(t, photo: true);
    await state.addProof(t, photo: false);
    expect(await state.submitTask(t, 'beres'), isNull);
    expect(t.status, TaskStatus.review);
  });

  test('cuti: atasan lalu HR', () async {
    final state = AppState();
    final r = state.requests.firstWhere((r) => r.id == 'r1');
    state.loginAs(state.employees.firstWhere((e) => e.id == 'm1'));
    await state.decide(r, true);
    expect(r.status, RequestStatus.menungguHr);
    state.loginAs(state.employees.firstWhere((e) => e.id == 'h1'));
    await state.decide(r, true);
    expect(r.status, RequestStatus.disetujui);
  });

  test('login demo: password salah ditolak, benar diterima', () async {
    final state = AppState();
    expect(await state.login('081200000004', 'salah'), isNotNull);
    expect(await state.login('0812-0000-0004', AppState.demoPassword), isNull);
    expect(state.me?.name, 'Budi Santoso');
  });
}
