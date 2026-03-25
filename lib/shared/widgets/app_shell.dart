import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/collections/collections_provider.dart';

class AppShell extends ConsumerStatefulWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  bool _exitDialogOpen = false;
  final List<int> _tabHistory = <int>[0];

  void _goToTab(int index) {
    switch (index) {
      case 0:
        context.go('/');
        break;
      case 1:
        context.go('/search');
        break;
      case 2:
        context.go('/saved');
        break;
      case 3:
        context.go('/profile');
        break;
    }
  }

  Future<void> _handleBackPressed(int selectedIndex) async {
    if (!mounted) return;
    if (selectedIndex != 0) {
      if (_tabHistory.length > 1) {
        _tabHistory.removeLast();
        _goToTab(_tabHistory.last);
      } else {
        _goToTab(0);
      }
      return;
    }
    if (_exitDialogOpen) return;
    _exitDialogOpen = true;
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Exit app?'),
        content: const Text('Press Exit to close same.energy.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Exit'),
          ),
        ],
      ),
    );
    _exitDialogOpen = false;
    if (shouldExit == true) {
      SystemNavigator.pop();
    }
  }

  Widget _homeLogo(bool selected) {
    return Opacity(
      opacity: selected ? 1 : 0.72,
      child: AnimatedScale(
        scale: selected ? 1.0 : 0.94,
        duration: const Duration(milliseconds: 140),
        child: Image.asset(
          'assets/blacklogo-bg.png',
          width: selected ? 24 : 22,
          height: selected ? 24 : 22,
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final selectedIndex = _indexForLocation(location);
    if (_tabHistory.isEmpty) {
      _tabHistory.add(selectedIndex);
    } else if (_tabHistory.last != selectedIndex) {
      _tabHistory.remove(selectedIndex);
      _tabHistory.add(selectedIndex);
    }
    final hasSavedItems = ref.watch(savedItemsProvider).images.isNotEmpty;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBackPressed(selectedIndex);
      },
      child: Scaffold(
        body: Stack(
          children: [
            // Wrap the background in RepaintBoundary to isolate repaints
            const RepaintBoundary(
              child: _LiquidGlassBackground(),
            ),
            Positioned.fill(
              child: KeyedSubtree(
                key: ValueKey(selectedIndex),
                child: widget.child,
              ),
            ),
          ],
        ),
        extendBody: true,
        bottomNavigationBar: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF121519).withValues(alpha: 0.72)
                    : const Color(0xFFFFFFFF).withValues(alpha: 0.72),
                border: Border(
                  top: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06),
                  ),
                ),
              ),
              child: NavigationBar(
                selectedIndex: selectedIndex,
                onDestinationSelected: (index) {
                  if (index == selectedIndex) return;
                  _goToTab(index);
                },
                animationDuration: const Duration(milliseconds: 350),
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                height: 70,
                backgroundColor: Colors.transparent,
                destinations: [
                  NavigationDestination(
                    icon: _homeLogo(false),
                    selectedIcon: _homeLogo(true),
                    label: 'Home',
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.search_outlined),
                    selectedIcon: Icon(Icons.search),
                    label: 'Search',
                  ),
                  NavigationDestination(
                    icon: Icon(
                      hasSavedItems ? Icons.bookmark : Icons.bookmark_border,
                    ),
                    selectedIcon: Icon(Icons.bookmark, color: accent),
                    label: 'Saved',
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.person_outline),
                    selectedIcon: Icon(Icons.person),
                    label: 'Profile',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  int _indexForLocation(String location) {
    if (location.startsWith('/search')) return 1;
    if (location.startsWith('/saved')) return 2;
    if (location.startsWith('/profile')) return 3;
    return 0;
  }
}

class _LiquidGlassBackground extends StatelessWidget {
  const _LiquidGlassBackground();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topColor = isDark ? const Color(0xFF0F141B) : const Color(0xFFF5F3EE);
    final bottomColor = isDark
        ? const Color(0xFF080A0C)
        : const Color(0xFFEFE9DD);
    final orbA = Theme.of(
      context,
    ).colorScheme.primary.withValues(alpha: isDark ? 0.16 : 0.14);
    final orbB = isDark
        ? const Color(0xFF4A90D9).withValues(alpha: 0.10)
        : const Color(0xFFE6B56A).withValues(alpha: 0.12);

    return IgnorePointer(
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [topColor, bottomColor],
              ),
            ),
          ),
          Positioned(
            left: -60,
            top: -40,
            child: RepaintBoundary(child: _BlurOrb(color: orbA, size: 220)),
          ),
          Positioned(
            right: -80,
            top: 180,
            child: RepaintBoundary(child: _BlurOrb(color: orbB, size: 260)),
          ),
          Positioned(
            left: 80,
            bottom: -120,
            child: RepaintBoundary(
              child: _BlurOrb(color: orbA.withValues(alpha: 0.08), size: 280),
            ),
          ),
        ],
      ),
    );
  }
}

class _BlurOrb extends StatelessWidget {
  const _BlurOrb({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: size * 0.22,
            spreadRadius: size * 0.03,
          ),
        ],
      ),
    );
  }
}
