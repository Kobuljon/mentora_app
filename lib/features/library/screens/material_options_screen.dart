import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'training_data_screen.dart';
import '../../study/providers/study_provider.dart';
import '../../study/screens/study_session_screen.dart';
import '../../study/screens/session_result_screen.dart';
import '../../study/screens/generate_questions_screen.dart';

class MaterialOptionsScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> material;

  const MaterialOptionsScreen({super.key, required this.material});

  @override
  ConsumerState<MaterialOptionsScreen> createState() => _MaterialOptionsScreenState();
}

class _MaterialOptionsScreenState extends ConsumerState<MaterialOptionsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(studyProvider.notifier).loadBundles(widget.material['id']);
    });
  }

  @override
  Widget build(BuildContext context) {
    final filename = widget.material['filename'] ?? 'Unknown Material';
    final studyState = ref.watch(studyProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(filename),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              onPressed: studyState.isGenerating ? null : () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => GenerateQuestionsScreen(material: widget.material),
                  ),
                );
              },
              icon: studyState.isGenerating 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.auto_awesome),
              label: Text(studyState.isGenerating 
                ? (studyState.generatingProgress ?? 'Generating...') 
                : 'Generate Questions'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: studyState.isGenerating ? null : () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TrainingDataScreen(material: widget.material),
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
            
            if (studyState.error != null) ...[
              const SizedBox(height: 16),
              Text(studyState.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],

            const SizedBox(height: 32),
            Text('Question Bundles', style: Theme.of(context).textTheme.titleMedium),
            const Divider(),
            Expanded(
              child: studyState.bundles.isEmpty
                  ? const Center(child: Text('No question bundles generated yet.'))
                  : ListView.builder(
                      itemCount: studyState.bundles.length,
                      itemBuilder: (context, index) {
                        final bundle = studyState.bundles[index];
                        final params = jsonDecode(bundle['params']);
                        final questions = jsonDecode(bundle['questions']) as List;
                        final date = DateTime.fromMillisecondsSinceEpoch(bundle['created_at']);
                        
                        final bundleId = bundle['id'];
                        final sessions = studyState.sessionsByBundle[bundleId] ?? [];

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ExpansionTile(
                            leading: const CircleAvatar(child: Icon(Icons.quiz)),
                            title: Text('${questions.length} Questions (Pages ${params['pageFrom']}-${params['pageTo']})'),
                            subtitle: Text('Generated: ${DateFormat.yMMMd().add_Hm().format(date)}'),
                            children: [
                              ...sessions.map((session) {
                                final sessionDate = DateTime.fromMillisecondsSinceEpoch(session['created_at']);
                                return ListTile(
                                  leading: const Icon(Icons.history),
                                  title: Text('Session ${DateFormat.yMMMd().add_Hm().format(sessionDate)}'),
                                  trailing: const Icon(Icons.chevron_right, size: 16),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => SessionResultScreen(
                                          questions: questions.map((e) => e.toString()).toList(),
                                          userAnswers: (jsonDecode(session['answers']) as List).map((e) => e.toString()).toList(),
                                          evaluation: jsonDecode(session['evaluation']),
                                        )
                                      )
                                    );
                                  },
                                );
                              }),
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    TextButton.icon(
                                      onPressed: () {
                                        ref.read(studyProvider.notifier).deleteBundle(widget.material['id'].toString(), bundleId);
                                      },
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      label: const Text('Delete', style: TextStyle(color: Colors.red)),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => StudySessionScreen(bundle: bundle),
                                          )
                                        ).then((_) {
                                          ref.read(studyProvider.notifier).loadBundles(widget.material['id'].toString());
                                        });
                                      },
                                      icon: const Icon(Icons.play_arrow),
                                      label: const Text('Start New Session'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
