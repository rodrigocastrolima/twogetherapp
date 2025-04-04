import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router/app_router.dart';
import 'core/theme/theme.dart';
import 'core/providers/locale_provider.dart';
import 'core/providers/theme_provider.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeProvider);

    return ScrollConfiguration(
      behavior: const _NoScrollbarBehavior(),
      child: MaterialApp.router(
        title: 'Twogether',
        theme: AppTheme.light().copyWith(
          pageTransitionsTheme: PageTransitionsTheme(
            builders: {
              // Use a custom transition that's very quick with minimal animation
              TargetPlatform.android: _NoTransitionsBuilder(),
              TargetPlatform.iOS: _NoTransitionsBuilder(),
              TargetPlatform.windows: _NoTransitionsBuilder(),
              TargetPlatform.macOS: _NoTransitionsBuilder(),
              TargetPlatform.linux: _NoTransitionsBuilder(),
            },
          ),
        ),
        darkTheme: AppTheme.dark().copyWith(
          pageTransitionsTheme: PageTransitionsTheme(
            builders: {
              // Use the same transition for dark theme
              TargetPlatform.android: _NoTransitionsBuilder(),
              TargetPlatform.iOS: _NoTransitionsBuilder(),
              TargetPlatform.windows: _NoTransitionsBuilder(),
              TargetPlatform.macOS: _NoTransitionsBuilder(),
              TargetPlatform.linux: _NoTransitionsBuilder(),
            },
          ),
        ),
        themeMode: themeMode,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: AppRouter.router,
      ),
    );
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

/// Custom ScrollBehavior that removes the scrollbar
class _NoScrollbarBehavior extends ScrollBehavior {
  const _NoScrollbarBehavior();

  @override
  Widget buildViewportChrome(
    BuildContext context,
    Widget child,
    AxisDirection axisDirection,
  ) {
    return child;
  }
}
