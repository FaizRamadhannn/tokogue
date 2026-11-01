import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../data/models.dart';
import '../theme.dart';
import '../widgets/common.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _hide = true;
  bool _busy = false;

  Future<void> _submit() async {
    if (_phone.text.trim().isEmpty || _password.text.isEmpty) {
      showSnack(context, 'Isi nomor HP dan password.', error: true);
      return;
    }
    setState(() => _busy = true);
    final state = AppScope.read(context);
    await runAction(context, state.login(_phone.text.trim(), _password.text));
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final demo = state.employees.where((e) => ['e1', 'm1', 'h1'].contains(e.id)).toList();
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          children: <Widget>[
            const _BrandBanner(),
            const SizedBox(height: 24),
            Row(children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 900),
                curve: Curves.elasticOut,
                builder: (_, v, child) => Transform.rotate(angle: (1 - v) * -0.5, child: Transform.scale(scale: v, child: child)),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.storefront_rounded, color: AppColors.goldLight),
                ),
              ),
              const SizedBox(width: 10),
              const Text('tokogue', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.ink, letterSpacing: -0.8)),
            ]),
            const SizedBox(height: 24),
            const Text('Masuk ke akun kamu', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.9, height: 1.15)),
            const SizedBox(height: 6),
            const Text('Absen, tugas, dan pengajuan cuti sekarang di satu aplikasi.',
                style: TextStyle(color: AppColors.muted, fontSize: 15, height: 1.4)),
            const SizedBox(height: 28),
            const Text('Nomor HP', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                hintText: '0812xxxxxxxx',
                prefixIcon: Icon(Icons.phone_iphone_rounded),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Password', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _password,
              obscureText: _hide,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: 'Masukkan password',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  icon: Icon(_hide ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                  onPressed: () => setState(() => _hide = !_hide),
                ),
              ),
            ),
            const SizedBox(height: 28),
            Pressable(
              child: FilledButton(
                onPressed: _busy ? null : _submit,
                child: AnimatedSwitcher(
                  duration: Motion.medium,
                  transitionBuilder: (child, a) => ScaleTransition(scale: a, child: FadeTransition(opacity: a, child: child)),
                  child: _busy
                      ? const SizedBox(key: ValueKey('busy'), width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary))
                      : const Text('Masuk', key: ValueKey('idle')),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Pressable(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegisterScreen())),
                child: const Text('Daftar akun baru'),
              ),
            ),
            const SizedBox(height: 32),
            if (!state.isLive) Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(16)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Mode demo', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.primaryDark)),
                const SizedBox(height: 4),
                const Text('Belum ada server. Pilih akun contoh untuk mencoba tiap role:',
                    style: TextStyle(color: AppColors.primaryDark, fontSize: 13)),
                const SizedBox(height: 12),
                for (final e in demo)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      child: ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        leading: Avatar(e, size: 36),
                        title: Text(e.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        subtitle: Text('${e.role.label} · ${e.position}', style: const TextStyle(fontSize: 12)),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => state.loginAs(e),
                      ),
                    ),
                  ),
                const Text('Atau login manual: nomor HP akun + password demo123',
                    style: TextStyle(color: AppColors.primaryDark, fontSize: 12)),
              ]),
            ),
          ].map((w) => w is SizedBox ? w : FadeSlideIn(child: w)).toList(),
        ),
      ),
    );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _position = TextEditingController();
  final _password = TextEditingController();
  bool _sent = false;
  bool _busy = false;

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty || _phone.text.trim().isEmpty || _position.text.trim().isEmpty) {
      showSnack(context, 'Lengkapi semua data dulu.', error: true);
      return;
    }
    if (_password.text.length < 6) {
      showSnack(context, 'Password minimal 6 karakter.', error: true);
      return;
    }
    setState(() => _busy = true);
    final ok = await runAction(
      context,
      AppScope.read(context).register(
        name: _name.text.trim(),
        phone: _phone.text.trim(),
        position: _position.text.trim(),
        password: _password.text,
      ),
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _sent = ok;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Daftar akun')),
      body: AnimatedSwitcher(
        duration: Motion.slow,
        child: _sent
          ? Column(key: const ValueKey('sent'), mainAxisAlignment: MainAxisAlignment.center, children: [
              const EmptyState(
                icon: Icons.hourglass_top_rounded,
                title: 'Pendaftaran terkirim',
                body: 'Akun kamu aktif setelah di-approve HR. Kamu akan bisa login dengan nomor HP yang didaftarkan.',
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Kembali ke login')),
              ),
            ])
          : ListView(padding: const EdgeInsets.all(24), children: <Widget>[
              const Text('Isi data diri. HR akan mengecek dan mengaktifkan akun kamu.',
                  style: TextStyle(color: AppColors.muted, height: 1.4)),
              const SizedBox(height: 20),
              TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nama lengkap')),
              const SizedBox(height: 12),
              TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Nomor HP')),
              const SizedBox(height: 12),
              TextField(controller: _position, decoration: const InputDecoration(labelText: 'Jabatan (contoh: Barista)')),
              const SizedBox(height: 12),
              TextField(controller: _password, obscureText: true, decoration: const InputDecoration(labelText: 'Password (minimal 6 karakter)')),
              const SizedBox(height: 24),
              Pressable(child: FilledButton(onPressed: _busy ? null : _submit, child: const Text('Kirim pendaftaran'))),
            ].map((w) => w is SizedBox ? w : FadeSlideIn(child: w)).toList()),
      ),
    );
  }
}

/// Foto brand di atas form login, dengan zoom pelan sekali saat muncul.
class _BrandBanner extends StatelessWidget {
  const _BrandBanner();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        height: 190,
        child: Stack(fit: StackFit.expand, children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 1.15, end: 1.0),
            duration: const Duration(milliseconds: 2400),
            curve: Curves.easeOutCubic,
            builder: (_, v, child) => Transform.scale(scale: v, child: child),
            child: Image.asset(
              'assets/images/brand_box.webp',
              fit: BoxFit.cover,
              alignment: const Alignment(0, -0.1),
              errorBuilder: (_, _, _) => const ColoredBox(color: AppColors.hero),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0x995A1212)],
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
