import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ava_web/core/app_theme.dart';
import 'package:ava_web/core/providers.dart';

@immutable
class ThemeSettings {
  const ThemeSettings({this.mode = ThemeMode.system, this.seed = kDefaultSeed});

  final ThemeMode mode;
  final Color seed;

  ThemeSettings copyWith({ThemeMode? mode, Color? seed}) =>
      ThemeSettings(mode: mode ?? this.mode, seed: seed ?? this.seed);

  @override
  bool operator ==(Object other) =>
      other is ThemeSettings &&
      other.mode == mode &&
      other.seed.toARGB32() == seed.toARGB32();

  @override
  int get hashCode => Object.hash(mode, seed.toARGB32());
}

final themeProvider = NotifierProvider<ThemeNotifier, ThemeSettings>(
  ThemeNotifier.new,
);

class ThemeNotifier extends Notifier<ThemeSettings> {
  static const modeKey = 'theme_mode';
  static const seedKey = 'theme_seed';

  @override
  ThemeSettings build() {
    final prefs = ref.watch(sharedPreferencesProvider);

    final savedMode = prefs.getString(modeKey);
    final mode = ThemeMode.values.firstWhere(
      (m) => m.name == savedMode,
      orElse: () => ThemeMode.system,
    );

    final savedSeed = prefs.getInt(seedKey);
    final seed =
        savedSeed != null &&
            kColorPresets.any((p) => p.seed.toARGB32() == savedSeed)
        ? Color(savedSeed)
        : kDefaultSeed;

    return ThemeSettings(mode: mode, seed: seed);
  }

  Future<void> cycleMode() => setMode(switch (state.mode) {
    ThemeMode.system => ThemeMode.light,
    ThemeMode.light => ThemeMode.dark,
    ThemeMode.dark => ThemeMode.system,
  });

  Future<void> setMode(ThemeMode mode) async {
    state = state.copyWith(mode: mode);
    await ref.read(sharedPreferencesProvider).setString(modeKey, mode.name);
  }

  Future<void> setSeed(Color seed) async {
    state = state.copyWith(seed: seed);
    await ref.read(sharedPreferencesProvider).setInt(seedKey, seed.toARGB32());
  }
}
