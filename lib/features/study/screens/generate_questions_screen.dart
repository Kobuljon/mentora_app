import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/study_provider.dart';

class GenerateQuestionsScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> material;

  const GenerateQuestionsScreen({super.key, required this.material});

  @override
  ConsumerState<GenerateQuestionsScreen> createState() => _GenerateQuestionsScreenState();
}

class _GenerateQuestionsScreenState extends ConsumerState<GenerateQuestionsScreen> {
  final _pageFromCtrl = TextEditingController(text: '1');
  final _pageToCtrl = TextEditingController(text: '10');
  final _countCtrl = TextEditingController(text: '5');
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _pageFromCtrl.dispose();
    _pageToCtrl.dispose();
    _countCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Generate Questions'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _pageFromCtrl,
                      decoration: const InputDecoration(labelText: 'Page From', border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _pageToCtrl,
                      decoration: const InputDecoration(labelText: 'Page To', border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _countCtrl,
                decoration: const InputDecoration(labelText: 'Number of Questions', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    ref.read(studyProvider.notifier).generateQuestions(
                      materialId: widget.material['id'],
                      pageFrom: int.parse(_pageFromCtrl.text),
                      pageTo: int.parse(_pageToCtrl.text),
                      count: int.parse(_countCtrl.text),
                    );
                    Navigator.pop(context);
                  }
                },
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Generate'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
