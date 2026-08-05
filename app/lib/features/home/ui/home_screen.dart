import 'package:flutter/material.dart';

/// Placeholder home screen.
///
/// SPEC 02 needs it only to prove the app boots through the layer wiring. Its
/// text moves to the ARB file in the next step, and the environment banner
/// lands here after that.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('dupla')),
    );
  }
}
