import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../storage/storage_service.dart';

final storageServiceProvider = Provider<StorageService>((ref) => StorageService());

class ThemeNotifier extends StateNotifier<ThemeMode> {
  final StorageService _storageService;

  ThemeNotifier(this._storageService) : super(ThemeMode.light) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final isDark = await _storageService.isDarkMode();
    state = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> toggleTheme() async {
    final newIsDark = state == ThemeMode.light;
    state = newIsDark ? ThemeMode.dark : ThemeMode.light;
    await _storageService.setDarkMode(newIsDark);
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  final storageService = ref.watch(storageServiceProvider);
  return ThemeNotifier(storageService);
});

class ReduceTransparencyNotifier extends StateNotifier<bool> {
  final StorageService _storageService;

  ReduceTransparencyNotifier(this._storageService) : super(false) {
    _load();
  }

  Future<void> _load() async {
    state = await _storageService.isReduceTransparency();
  }

  Future<void> toggle() async {
    state = !state;
    await _storageService.setReduceTransparency(state);
  }
}

final reduceTransparencyProvider = StateNotifierProvider<ReduceTransparencyNotifier, bool>((ref) {
  return ReduceTransparencyNotifier(ref.watch(storageServiceProvider));
});
