import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // final locale = ref.watch(localeProvider); // Removed
    // final themeMode = ref.watch(themeProvider); // Removed

    // This widget is now largely redundant. The logic was moved to main.dart.
    // Returning a placeholder. Consider removing this widget entirely if not used elsewhere.
    return Container();
  }
}

// Removed _NoTransitionsBuilder class
// /// Custom PageTransitionsBuilder that has minimal transition animation
// class _NoTransitionsBuilder extends PageTransitionsBuilder {
//   @override
//   Widget buildTransitions<T>(
//     PageRoute<T> route,
//     BuildContext context,
//     Animation<double> animation,
//     Animation<double> secondaryAnimation,
//     Widget child,
//   ) {
//     // Return the child directly with no animations or transitions
//     return child;
//   }
// }
