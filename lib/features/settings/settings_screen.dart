import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/security/collection_lock_service.dart';
import '../../features/collections/collections_provider.dart';
import '../../core/settings/app_settings_provider.dart';
import '../../core/storage/preferences_storage.dart';
import '../../core/telemetry/clickstream_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final notifier = ref.read(appSettingsProvider.notifier);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Advanced Settings',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 16),

            TextButton.icon(
              onPressed: () async {
                final lockService = ref.read(collectionLockServiceProvider);
                final hasPin = await lockService.hasPin();
                if (!hasPin) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Collection lock PIN is not set.'),
                    ),
                  );
                  return;
                }
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Reset collection lock PIN'),
                    content: const Text(
                      'This will clear your lock PIN. '
                      'Private collections will be locked again.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Reset'),
                      ),
                    ],
                  ),
                );
                if (confirm != true || !context.mounted) return;
                await lockService.resetPin();
                ref
                    .read(savedItemsProvider.notifier)
                    .lockAllCollectionSessions();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Collection lock PIN reset successfully.'),
                  ),
                );
              },
              icon: const Icon(Icons.lock_reset, size: 18),
              label: const Text('Reset Collection Lock PIN'),
              style: TextButton.styleFrom(
                foregroundColor: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 8),

            // Reset recommendations
            TextButton.icon(
              onPressed: () async {
                await notifier.setGridColumns(2);
                await notifier.setImagePadding(2);
                await notifier.setSafeSearchEnabled(false);
                await notifier.setThemeMode(ThemeMode.system);
                await notifier.setAccentColor(null);

                // Clear cached data
                final keys = PreferencesStorage.prefs
                    .getKeys()
                    .where((key) => key.startsWith('json_cache_v1::'))
                    .toList();
                for (final key in keys) {
                  await PreferencesStorage.prefs.remove(key);
                }
                ClickstreamService().trackResetFyp();
                if (!context.mounted) return;
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(context);
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('All settings reset to default'),
                  ),
                );
              },
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Reset All Settings'),
              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () async {
                await PreferencesStorage.setSearchHistory([]);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Search history cleared')),
                );
              },
              icon: const Icon(Icons.history, size: 18),
              label: const Text('Clear Search History'),
              style: TextButton.styleFrom(
                foregroundColor: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
