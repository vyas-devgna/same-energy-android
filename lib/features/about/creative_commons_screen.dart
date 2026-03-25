import 'package:flutter/material.dart';

import '../../shared/widgets/glass_background.dart';
import '../../shared/widgets/top_app_bar.dart';

class CreativeCommonsScreen extends StatelessWidget {
  const CreativeCommonsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: const SameEnergyTopAppBar(title: 'Creative Commons'),
      body: Stack(
        children: [
          const Positioned.fill(child: SameEnergyGlassBackground()),
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Creative Commons',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Some images on same.energy are licensed under Creative Commons. '
                  'These images can be reused under specific conditions depending on '
                  'the exact license attached to the original source.\n\n'
                  'When available, you can inspect source and licensing context from '
                  'the image detail view.\n\n'
                  'If you are the copyright holder of an image appearing on '
                  'same.energy and need it removed, contact the original platform or '
                  'the service directly.\n\n'
                  'same.energy aggregates publicly accessible images and does not '
                  'claim ownership over third-party images shown in search results.',
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.6,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
