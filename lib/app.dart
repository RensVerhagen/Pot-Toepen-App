import 'package:flutter/material.dart';

import 'application/app_controller.dart';
import 'ui/app_theme.dart';
import 'ui/screens/home_screen.dart';

class PotToepenApp extends StatelessWidget {
  const PotToepenApp({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Pot Toepen',
    debugShowCheckedModeBanner: false,
    theme: buildTheme(),
    themeMode: ThemeMode.dark,
    home: HomeScreen(controller: controller),
  );
}

Route<T> potRoute<T>(Widget page) => PageRouteBuilder<T>(
  pageBuilder: (context, animation, secondaryAnimation) => page,
  transitionDuration: const Duration(milliseconds: 380),
  reverseTransitionDuration: const Duration(milliseconds: 280),
  transitionsBuilder: (context, animation, secondaryAnimation, child) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(.04, .02),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  },
);
