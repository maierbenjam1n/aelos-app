import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  runApp(const ProviderScope(child: AelosApp()));
}

class AelosApp extends StatelessWidget {
  const AelosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Aelos',
      debugShowCheckedModeBanner: false,
      // Replaced by the design system and onboarding in build step 2.
      home: Scaffold(
        backgroundColor: Color(0xFF2B1F17),
        body: Center(
          child: Text(
            'Aelos',
            style: TextStyle(
              color: Color(0xFFF6F0E6),
              fontSize: 48,
              fontFamily: 'serif',
              letterSpacing: 4,
            ),
          ),
        ),
      ),
    );
  }
}
