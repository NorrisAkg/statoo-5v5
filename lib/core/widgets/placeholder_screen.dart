import 'package:flutter/material.dart';

class PlaceholderScreen extends StatelessWidget {
  final String title;

  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: Color(0xFF1F2733),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.build_circle_outlined, size: 40, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 24),
            const Text(
              'Bientôt disponible',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Cet écran arrive dans une prochaine étape du\nprototype.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
