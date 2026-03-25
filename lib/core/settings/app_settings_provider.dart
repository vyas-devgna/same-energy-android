import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/preferences_storage.dart';

class AppSettingsState {
  final int gridColumns;
  final int imagePadding;
  final bool safeSearchEnabled;
  final ThemeMode themeMode;
  final Color? accentColor;

  const AppSettingsState({
    required this.gridColumns,
    required this.imagePadding,
    required this.safeSearchEnabled,
    required this.themeMode,
    this.accentColor,
  });

  AppSettingsState copyWith({
    int? gridColumns,
    int? imagePadding,
    bool? safeSearchEnabled,
    ThemeMode? themeMode,
    Color? accentColor,
    bool clearAccent = false,
  }) {
    return AppSettingsState(
      gridColumns: gridColumns ?? this.gridColumns,
      imagePadding: imagePadding ?? this.imagePadding,
      safeSearchEnabled: safeSearchEnabled ?? this.safeSearchEnabled,
      themeMode: themeMode ?? this.themeMode,
      accentColor: clearAccent ? null : (accentColor ?? this.accentColor),
    );
  }
}

final appSettingsProvider =
    StateNotifierProvider<AppSettingsNotifier, AppSettingsState>(
      (ref) => AppSettingsNotifier(),
    );

class AppSettingsNotifier extends StateNotifier<AppSettingsState> {
  AppSettingsNotifier()
    : super(
        AppSettingsState(
          gridColumns: PreferencesStorage.getColumnCount(),
          imagePadding: PreferencesStorage.getImagePadding(),
          // The stored value `nsfw_filter` == true means "NSFW is allowed"
          // (i.e., safe search is OFF). We invert for the new semantics:
          // safeSearchEnabled == true → NSFW blocked.
          safeSearchEnabled: !PreferencesStorage.getNsfwFilter(),
          themeMode: _themeModeFromString(PreferencesStorage.getThemeMode()),
          accentColor: _colorFromInt(PreferencesStorage.getAccentColor()),
        ),
      );

  Future<void> setGridColumns(int columns) async {
    final normalized = columns.clamp(2, 3);
    await PreferencesStorage.setColumnCount(normalized);
    await PreferencesStorage.setColumnOffset(normalized - 2);
    state = state.copyWith(gridColumns: normalized);
  }

  Future<void> setImagePadding(int padding) async {
    final normalized = padding.clamp(1, 8);
    await PreferencesStorage.setImagePadding(normalized);
    state = state.copyWith(imagePadding: normalized);
  }

  Future<void> setSafeSearchEnabled(bool enabled) async {
    // Store the inverted value: nsfw_filter == true means NSFW allowed,
    // so safeSearchEnabled == true → store false.
    await PreferencesStorage.setNsfwFilter(!enabled);
    state = state.copyWith(safeSearchEnabled: enabled);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await PreferencesStorage.setThemeMode(_themeModeToString(mode));
    state = state.copyWith(themeMode: mode);
  }

  Future<void> setAccentColor(Color? color) async {
    if (color == null) {
      await PreferencesStorage.setAccentColor(0);
      state = state.copyWith(clearAccent: true);
    } else {
      await PreferencesStorage.setAccentColor(color.toARGB32());
      state = state.copyWith(accentColor: color);
    }
  }

  static ThemeMode _themeModeFromString(String mode) {
    switch (mode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static String _themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  static Color? _colorFromInt(int value) {
    if (value == 0) return null;
    return Color(value);
  }
}
