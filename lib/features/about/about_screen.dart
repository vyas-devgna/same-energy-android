import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../shared/widgets/glass_background.dart';
import '../../shared/widgets/top_app_bar.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: const SameEnergyTopAppBar(title: 'About'),
      body: Stack(
        children: [
          const Positioned.fill(child: SameEnergyGlassBackground()),
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'same.energy',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 2.0,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'same.energy is a visual search engine. You can use it to find '
                  'beautiful images of all kinds - art, photography, decor, fashion, and more.\n\n'
                  'Our search works visually: instead of typing keywords, you find one '
                  'image close to what you want and then use it to discover more like it. '
                  'That makes browsing visual ideas feel faster and more natural.\n\n'
                  'Under the hood, same.energy uses deep learning to read the mood and '
                  'aesthetic of an image, then finds other images with a similar feel.',
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.6,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
                const SizedBox(height: 24),
                _buildInfoRow(context, 'Created by', 'Jacob (original developer)', isDark),
                const SizedBox(height: 8),
                _buildLinkButton(
                  context,
                  'Twitter',
                  'https://twitter.com/jacobjackson',
                  isDark,
                ),
                const SizedBox(height: 24),
                _buildInfoRow(context, 'Developer Credits', '', isDark),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildLinkButton(
                      context,
                      'Maitri & Devgna',
                      null,
                      isDark,
                      onTap: () => context.push('/credits'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    String label,
    String value,
    bool isDark,
  ) {
    return Row(
      children: [
        Text(
          value.isEmpty ? label : '$label: ',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white54 : Colors.black54,
          ),
        ),
        if (value.isNotEmpty)
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
      ],
    );
  }

  Widget _buildLinkButton(
    BuildContext context,
    String text,
    String? url,
    bool isDark, {
    VoidCallback? onTap,
  }) {
    return OutlinedButton(
      onPressed:
          onTap ??
          () async {
            if (url == null) return;
            final uri = Uri.parse(url);
            await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
          },
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: isDark ? Colors.white24 : Colors.black12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(text),
    );
  }
}
