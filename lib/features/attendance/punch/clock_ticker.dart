import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final clockTickerProvider = StreamProvider<DateTime>((ref) async* {
  yield DateTime.now();
  
  bool isPaused = WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed;
  
  final binding = WidgetsBinding.instance;
  final listener = AppLifecycleListener(
    onResume: () => isPaused = false,
    onPause: () => isPaused = true,
    onInactive: () => isPaused = true,
  );
  
  ref.onDispose(() {
    listener.dispose();
  });

  while (true) {
    await Future.delayed(const Duration(seconds: 1));
    if (!isPaused) {
      yield DateTime.now();
    }
  }
});
