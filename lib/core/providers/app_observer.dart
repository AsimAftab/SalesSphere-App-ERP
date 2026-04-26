import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

base class AppProviderObserver extends ProviderObserver {
  @override
  void didAddProvider(
    ProviderObserverContext context,
    Object? value,
  ) {
    if (kDebugMode) {
      debugPrint('[Provider+] ${context.provider.name ?? context.provider.runtimeType}');
    }
  }

  @override
  void didUpdateProvider(
    ProviderObserverContext context,
    Object? previousValue,
    Object? newValue,
  ) {
    if (kDebugMode) {
      debugPrint(
        '[Provider~] ${context.provider.name ?? context.provider.runtimeType}',
      );
    }
  }

  @override
  void providerDidFail(
    ProviderObserverContext context,
    Object error,
    StackTrace stackTrace,
  ) {
    if (kDebugMode) {
      debugPrint(
        '[Provider!] ${context.provider.name ?? context.provider.runtimeType} → $error',
      );
    }
  }
}
