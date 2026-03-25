import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_state.dart';
import '../../core/design/app_theme.dart';
import '../../core/settings/app_settings_provider.dart';
import '../settings/settings_screen.dart';
import '../auth/login_bottom_sheet.dart';
import '../collections/collections_provider.dart';
import '../../shared/widgets/top_app_bar.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _authActionInProgress = false;

  Future<void> _openSignInSheet() async {
    if (_authActionInProgress) return;
    setState(() => _authActionInProgress = true);
    showLoginBottomSheet(context, ref, intent: 'profile');
    // The sheet owns the actual login submission. This only guards rapid taps.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      setState(() => _authActionInProgress = false);
    }
  }

  Future<void> _confirmSignOut() async {
    if (_authActionInProgress) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          "You'll need to sign in again to access your saved items.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _authActionInProgress = true);
    try {
      await ref.read(authStateProvider.notifier).logout();
      ref.read(savedItemsProvider.notifier).lockAllCollectionSessions();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Signed out')),
      );
      // Router redirect will auto-navigate to /login
    } finally {
      if (mounted) {
        setState(() => _authActionInProgress = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;
    final auth = ref.watch(authStateProvider);
    final settings = ref.watch(appSettingsProvider);
    final settingsNotifier = ref.read(appSettingsProvider.notifier);

    return Scaffold(
      appBar: SameEnergyTopAppBar(
        title: 'Profile',
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: () => _openSettings(context),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 90),
        children: [
          // User section
          _GlassSection(
            isDark: isDark,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: accent.withValues(alpha: 0.15),
                child: Icon(Icons.person, color: accent),
              ),
              title: Text(
                auth.isLoggedIn ? auth.userId : 'Anonymous User',
                style: const TextStyle(fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                auth.isLoggedIn ? 'Signed in' : 'Not signed in',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
              trailing: auth.isLoggedIn
                  ? OutlinedButton(
                      onPressed: _authActionInProgress
                          ? null
                          : _confirmSignOut,
                      child: const Text('Sign out'),
                    )
                  : FilledButton(
                      onPressed: _authActionInProgress
                          ? null
                          : _openSignInSheet,
                      child: const Text('Sign in / Sign up'),
                    ),
            ),
          ),
          const SizedBox(height: 16),

          // Display settings
          _SectionLabel(text: 'Display', isDark: isDark),
          _GlassSection(
            isDark: isDark,
            child: Column(
              children: [
                // Theme
                ListTile(
                  leading: Icon(
                    settings.themeMode == ThemeMode.dark
                        ? Icons.dark_mode
                        : settings.themeMode == ThemeMode.light
                        ? Icons.light_mode
                        : Icons.brightness_auto,
                  ),
                  title: const Text('Theme'),
                  trailing: SegmentedButton<ThemeMode>(
                    showSelectedIcon: false,
                    selected: {settings.themeMode},
                    onSelectionChanged: (modes) {
                      settingsNotifier.setThemeMode(modes.first);
                    },
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.system,
                        label: Text('Auto', style: TextStyle(fontSize: 12)),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        label: Text('Light', style: TextStyle(fontSize: 12)),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        label: Text('Dark', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                // Grid columns
                ListTile(
                  leading: const Icon(Icons.grid_view),
                  title: const Text('Grid columns'),
                  trailing: SegmentedButton<int>(
                    showSelectedIcon: false,
                    selected: {settings.gridColumns},
                    onSelectionChanged: (vals) {
                      settingsNotifier.setGridColumns(vals.first);
                    },
                    segments: const [
                      ButtonSegment(value: 2, label: Text('2')),
                      ButtonSegment(value: 3, label: Text('3')),
                    ],
                  ),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                // Image padding
                ListTile(
                  leading: const Icon(Icons.format_line_spacing),
                  title: const Text('Image padding'),
                  trailing: SizedBox(
                    width: 160,
                    child: Slider(
                      value: settings.imagePadding.toDouble(),
                      min: 1,
                      max: 8,
                      divisions: 7,
                      label: '${settings.imagePadding}px',
                      onChanged: (val) =>
                          settingsNotifier.setImagePadding(val.round()),
                    ),
                  ),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                // NSFW filter
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: SwitchListTile(
                    key: ValueKey(settings.safeSearchEnabled),
                    secondary: const Icon(Icons.shield_outlined),
                    title: const Text('Safe search'),
                    subtitle: Text(
                      settings.safeSearchEnabled
                          ? 'NSFW content is hidden'
                          : 'All content is shown',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                    value: settings.safeSearchEnabled,
                    onChanged: (val) =>
                        settingsNotifier.setSafeSearchEnabled(val),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Accent color picker
          _SectionLabel(text: 'Accent Color', isDark: isDark),
          _GlassSection(
            isDark: isDark,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  // Default (reset)
                  _AccentColorCircle(
                    color: SameEnergyPalette.defaultAccent,
                    isSelected: settings.accentColor == null,
                    label: 'Default',
                    onTap: () => settingsNotifier.setAccentColor(null),
                  ),
                  ...SameEnergyPalette.accentPresets
                      .skip(1)
                      .map(
                        (color) => _AccentColorCircle(
                          color: color,
                          isSelected:
                              settings.accentColor?.toARGB32() ==
                              color.toARGB32(),
                          onTap: () => settingsNotifier.setAccentColor(color),
                        ),
                      ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // About
          _SectionLabel(text: 'About', isDark: isDark),
          _GlassSection(
            isDark: isDark,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('About same.energy'),
                  onTap: () => context.push('/about'),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.article_outlined),
                  title: const Text('Creative Commons'),
                  onTap: () => context.push('/creativecommons'),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.groups_outlined),
                  title: const Text('Developer Credits'),
                  onTap: () => context.push('/credits'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const SettingsScreen(),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text, required this.isDark});
  final String text;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: isDark ? Colors.white38 : Colors.black38,
        ),
      ),
    );
  }
}

class _GlassSection extends StatelessWidget {
  const _GlassSection({required this.isDark, required this.child});
  final bool isDark;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.07)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _AccentColorCircle extends StatelessWidget {
  const _AccentColorCircle({
    required this.color,
    required this.isSelected,
    required this.onTap,
    this.label,
  });

  final Color color;
  final bool isSelected;
  final VoidCallback onTap;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Colors.white : Colors.transparent,
                width: 2.5,
              ),
              boxShadow: [
                if (isSelected)
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
              ],
            ),
            child: isSelected
                ? const Icon(Icons.check, color: Colors.white, size: 18)
                : null,
          ),
          if (label != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(label!, style: const TextStyle(fontSize: 10)),
            ),
        ],
      ),
    );
  }
}
