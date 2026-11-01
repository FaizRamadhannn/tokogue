import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'data/app_state.dart';
import 'data/backend.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Backend? backend;
  if (liveMode) {
    await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseKey);
    backend = Backend(Supabase.instance.client);
  }
  final state = AppState(backend: backend);
  runApp(TokogueApp(state: state));
  state.restoreSession();
}

class TokogueApp extends StatelessWidget {
  const TokogueApp({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: MaterialApp(
        title: 'tokogue',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        // Di browser desktop, tampilkan app selebar HP supaya mirip di ponsel.
        builder: (context, child) => ColoredBox(
          color: AppColors.bg,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: child,
            ),
          ),
        ),
        home: const _Gate(),
      ),
    );
  }
}

class _Gate extends StatelessWidget {
  const _Gate();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final Widget page = state.loading
        ? const Scaffold(key: ValueKey('loading'), body: Center(child: CircularProgressIndicator(color: AppColors.primary)))
        : state.me == null
            ? const LoginScreen(key: ValueKey('login'))
            : MainShell(key: ValueKey('shell-${state.me!.id}'));
    return AnimatedSwitcher(
      duration: Motion.slow,
      // Fade-through: layar lama hilang dulu, baru layar baru muncul.
      switchInCurve: const Interval(0.35, 1, curve: Motion.curve),
      switchOutCurve: const Interval(0.65, 1, curve: Curves.easeIn),
      transitionBuilder: (child, a) => FadeTransition(
        opacity: a,
        child: ScaleTransition(scale: Tween(begin: 0.97, end: 1.0).animate(a), child: child),
      ),
      child: page,
    );
  }
}
