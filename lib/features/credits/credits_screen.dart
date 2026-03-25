import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../shared/widgets/glass_background.dart';
import '../../shared/widgets/top_app_bar.dart';

class CreditsScreen extends StatelessWidget {
  const CreditsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: const SameEnergyTopAppBar(title: 'Developer Credits'),
      body: Stack(
        children: [
          const Positioned.fill(child: SameEnergyGlassBackground()),
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _CreditCard(
                isDark: isDark,
                name: 'Maitri Kansagra',
                role: 'UI/UX Design & Visual Polish',
                contributions: const [
                  'Screen Layouts & Component Design',
                  'Theme System & Glassmorphism Styling',
                  'Dark/Light Mode Implementation',
                  'Animation & Interaction Design',
                ],
                linkLabel: 'LinkedIn',
                link:
                    'https://www.linkedin.com/in/maitri-kansagra-b16a3b281/',
              ),
              const SizedBox(height: 12),
              _CreditCard(
                isDark: isDark,
                name: 'Devgna Vyas',
                role: 'Architecture & Backend Integration',
                contributions: const [
                  'App Architecture & Project Structure',
                  'API Integration & Data Layer',
                  'State Management (Riverpod)',
                  'Backend Communication & Caching',
                  'Authentication & Security',
                ],
                linkLabel: 'LinkedIn',
                link: 'https://www.linkedin.com/in/devgna-vyas/',
              ),
              const SizedBox(height: 20),
              _PlatformCredit(isDark: isDark),
            ],
          ),
        ],
      ),
    );
  }
}

class _CreditCard extends StatelessWidget {
  const _CreditCard({
    required this.isDark,
    required this.name,
    required this.role,
    required this.contributions,
    required this.linkLabel,
    required this.link,
  });

  final bool isDark;
  final String name;
  final String role;
  final List<String> contributions;
  final String linkLabel;
  final String link;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.white.withValues(alpha: 0.65),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.08),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              role,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: accent,
              ),
            ),
            const SizedBox(height: 8),
            ...contributions.map(
              (c) => Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 5, right: 8),
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        c,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () async {
                final uri = Uri.parse(link);
                await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
              },
              icon: const Icon(Icons.open_in_new, size: 16),
              label: Text(linkLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlatformCredit extends StatelessWidget {
  const _PlatformCredit({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: isDark
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.white.withValues(alpha: 0.5),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Original Platform',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'The same.energy visual search engine and API are created and maintained by the original same.energy team. This mobile app is built on top of their public platform.',
            style: TextStyle(
              fontSize: 12.5,
              color: isDark ? Colors.white54 : Colors.black45,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
