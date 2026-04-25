import 'package:flutter/material.dart';

class SessionResultScreen extends StatelessWidget {
  final List<String> questions;
  final List<String> userAnswers;
  final Map<String, dynamic> evaluation;

  const SessionResultScreen({
    super.key,
    required this.questions,
    required this.userAnswers,
    required this.evaluation,
  });

  @override
  Widget build(BuildContext context) {
    final overallFeedback = evaluation['overallFeedback'] ?? 'No overall feedback provided.';
    final List evals = evaluation['evaluations'] ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('Session Results')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Overall Feedback', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(overallFeedback),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('Detailed Review', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          ...List.generate(questions.length, (index) {
            final eval = evals.firstWhere((e) => e['questionIndex'] == index, orElse: () => {});
            final isCorrect = eval['isCorrect'] == true;
            final feedback = eval['feedback'] ?? 'No specific feedback.';
            final grammarFeedback = eval['grammarFeedback'];

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          isCorrect ? Icons.check_circle : Icons.cancel,
                          color: isCorrect ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Q${index + 1}: ${questions[index]}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Text('Your Answer:', style: Theme.of(context).textTheme.bodySmall),
                    Text(userAnswers[index]),
                    const SizedBox(height: 12),
                    Text('Feedback:', style: Theme.of(context).textTheme.bodySmall),
                    Text(feedback),
                    if (grammarFeedback != null && grammarFeedback.toString().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text('Grammar Note:', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.orange)),
                      Text(grammarFeedback),
                    ]
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: () {
              Navigator.pop(context); // Go back to material options
            },
            child: const Text('Finish Review'),
          )
        ],
      ),
    );
  }
}
