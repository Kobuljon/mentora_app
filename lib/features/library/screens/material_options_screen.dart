import 'package:flutter/material.dart';
import 'training_data_screen.dart';

class MaterialOptionsScreen extends StatelessWidget {
  final Map<String, dynamic> material;

  const MaterialOptionsScreen({super.key, required this.material});

  @override
  Widget build(BuildContext context) {
    final filename = material['filename'] ?? 'Unknown Material';

    return Scaffold(
      appBar: AppBar(
        title: Text(filename),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Generate Questions feature coming soon!')),
                );
              },
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Generate Questions'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TrainingDataScreen(material: material),
                  ),
                );
              },
              icon: const Icon(Icons.analytics_outlined),
              label: const Text('Training Data'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
