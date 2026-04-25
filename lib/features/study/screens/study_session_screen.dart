import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/study_provider.dart';
import 'session_result_screen.dart';

class StudySessionScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> bundle;

  const StudySessionScreen({super.key, required this.bundle});

  @override
  ConsumerState<StudySessionScreen> createState() => _StudySessionScreenState();
}

class _StudySessionScreenState extends ConsumerState<StudySessionScreen> {
  late List<String> _questions;
  int _currentIndex = 0;
  final List<String> _answers = [];
  final TextEditingController _answerController = TextEditingController();
  bool _isEvaluating = false;

  @override
  void initState() {
    super.initState();
    _questions = (jsonDecode(widget.bundle['questions']) as List).map((e) => e.toString()).toList();
  }

  void _nextQuestion() {
    if (_answerController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter an answer.')));
      return;
    }
    
    _answers.add(_answerController.text.trim());
    _answerController.clear();
    
    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
      });
    } else {
      _submitSession();
    }
  }

  Future<void> _submitSession() async {
    setState(() {
      _isEvaluating = true;
    });
    
    try {
      final evaluation = await ref.read(studyProvider.notifier).evaluateSession(
        bundleId: widget.bundle['id'],
        questions: _questions,
        userAnswers: _answers,
        checkGrammar: true, // we could read this from settings
      );
      
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => SessionResultScreen(
              questions: _questions,
              userAnswers: _answers,
              evaluation: evaluation,
            )
          )
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Evaluation failed: $e')));
        setState(() {
          _isEvaluating = false;
          _answers.removeLast(); // allow them to try submitting again
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isEvaluating) {
      return Scaffold(
        appBar: AppBar(title: const Text('Evaluating...')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Mentora is reviewing your answers...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Question ${_currentIndex + 1} of ${_questions.length}'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LinearProgressIndicator(value: (_currentIndex + 1) / _questions.length),
            const SizedBox(height: 32),
            Text(
              _questions[_currentIndex],
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _answerController,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'Type your answer here...',
                border: OutlineInputBorder(),
              ),
            ),
            const Spacer(),
            FilledButton(
              onPressed: _nextQuestion,
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              child: Text(_currentIndex == _questions.length - 1 ? 'Submit Answers' : 'Next Question'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
