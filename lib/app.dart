import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router/app_router.dart';
import 'core/theme/theme.dart';
import 'core/providers/locale_provider.dart';
import 'core/providers/theme_provider.dart';
import 'features/notifications/presentation/widgets/notification_overlay_manager.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeProvider);

    // Remove MaterialApp.router, ScrollConfiguration, and NotificationOverlayManager wrappers
    // The root MaterialApp in main.dart will handle these.
    // We just need to return the router's target widget.
    // Since MaterialApp.router itself renders based on the router config,
    // we can't directly return a single child here. The configuration needs
    // to happen in the main MaterialApp.
    // For now, let's return a simple placeholder Container.
    // The real fix is in main.dart
    return Container(); // Placeholder - This widget essentially becomes redundant now.
    // We'll integrate its logic into main.dart's MaterialApp.
  }
}

/// Custom PageTransitionsBuilder that has minimal transition animation
class _NoTransitionsBuilder extends PageTransitionsBuilder {
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Return the child directly with no animations or transitions
    return child;
  }
}
