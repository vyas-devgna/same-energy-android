import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/auth/auth_state.dart';
import 'core/design/app_theme.dart';
import 'core/settings/app_settings_provider.dart';
import 'core/storage/preferences_storage.dart';
import 'core/telemetry/clickstream_service.dart';
import 'router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PreferencesStorage.init();
  ClickstreamService().init();

  runApp(const ProviderScope(child: SameEnergyApp()));
}

/// Provider for the GoRouter instance so it's tied to the Riverpod lifecycle.
final appRouterProvider = Provider<GoRouter>((ref) {
  return buildAppRouter(ref);
});

class SameEnergyApp extends ConsumerStatefulWidget {
  const SameEnergyApp({super.key});

  @override
  ConsumerState<SameEnergyApp> createState() => _SameEnergyAppState();
}

class _SameEnergyAppState extends ConsumerState<SameEnergyApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authStateProvider);
      ClickstreamService().updateUser(user.userId, user.token);
      final media = MediaQuery.of(context);
      ClickstreamService().trackOpen(
        media.size.width,
        media.size.height,
        media.devicePixelRatio,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final router = ref.watch(appRouterProvider);
    ref.listen(authStateProvider, (prev, next) {
      ClickstreamService().updateUser(next.userId, next.token);
    });

    return MaterialApp.router(
      title: 'same.energy',
      debugShowCheckedModeBanner: false,
      themeMode: settings.themeMode,
      theme: SameEnergyTheme.light(accentColor: settings.accentColor),
      darkTheme: SameEnergyTheme.dark(accentColor: settings.accentColor),
      routerConfig: router,
    );
  }
}
