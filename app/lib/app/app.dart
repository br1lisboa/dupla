import 'package:flutter/material.dart';

import 'package:dupla/features/home/index.dart';

/// Root widget of the application.
///
/// Owns what is global — title, theme, localization, navigation — and nothing
/// else. Screens belong to their feature slice.
///
/// The theme is deliberately the Material default: design tokens and typography
/// are owned by SPEC 04.
class DuplaApp extends StatelessWidget {
  const DuplaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'dupla',
      home: HomeScreen(),
    );
  }
}
