import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SameEnergyTopAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const SameEnergyTopAppBar({
    super.key,
    required this.title,
    this.leading,
    this.actions = const [],
    this.showLogo = false,
  });

  final String title;
  final Widget? leading;
  final List<Widget> actions;
  final bool showLogo;

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final resolvedLeading =
        leading ??
        (showLogo
            ? Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Center(
                  child: Image.asset(
                    'assets/blacklogo-bg.png',
                    width: 24,
                    height: 24,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
              )
            : canPop
            ? IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back),
              )
            : null);

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF090B0D).withValues(alpha: 0.65)
                : const Color(0xFFF8F7F3).withValues(alpha: 0.65),
            border: Border(
              bottom: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.06),
              ),
            ),
          ),
          child: AppBar(
            toolbarHeight: 56,
            leadingWidth: showLogo ? 44 : null,
            leading: resolvedLeading,
            titleSpacing: 8,
            title: Text(title),
            backgroundColor: Colors.transparent,
            actions: actions,
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(56);
}
