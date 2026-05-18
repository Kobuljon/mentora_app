import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../settings/providers/settings_provider.dart';
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
  final FocusNode _answerFocus = FocusNode();
  bool _isEvaluating = false;

  @override
  void initState() {
    super.initState();
    _questions = (jsonDecode(widget.bundle['questions']) as List)
        .map((e) => e.toString())
        .toList();
  }

  @override
  void dispose() {
    _answerController.dispose();
    _answerFocus.dispose();
    super.dispose();
  }

  void _nextQuestion() {
    final text = _answerController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter an answer.')));
      return;
    }

    _answers.add(text);
    _answerController.clear();

    if (_currentIndex < _questions.length - 1) {
      setState(() => _currentIndex++);
      _answerFocus.requestFocus();
    } else {
      _submitSession();
    }
  }

  void _previousQuestion() {
    if (_currentIndex == 0) return;
    setState(() {
      _currentIndex--;
      final previous = _answers.removeLast();
      _answerController.text = previous;
      _answerController.selection = TextSelection.fromPosition(
        TextPosition(offset: previous.length),
      );
    });
    _answerFocus.requestFocus();
  }

  Future<void> _submitSession() async {
    setState(() => _isEvaluating = true);
    final settings = ref.read(settingsProvider);

    try {
      final evaluation = await ref
          .read(studyProvider.notifier)
          .evaluateSession(
            bundleId: widget.bundle['id'],
            questions: _questions,
            userAnswers: _answers,
            checkGrammar: settings.languageLearnerModeEnabled,
          );

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => SessionResultScreen(
              questions: _questions,
              userAnswers: _answers,
              evaluation: evaluation,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Evaluation failed: $e')));
        setState(() {
          _isEvaluating = false;
          if (_answers.isNotEmpty) _answers.removeLast();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isLast = _currentIndex == _questions.length - 1;
    final progress = (_currentIndex + 1) / _questions.length;

    if (_isEvaluating) {
      return Scaffold(
        backgroundColor: scheme.surface,
        appBar: AppBar(title: const Text('Evaluating')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: scheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Reviewing your answers',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Mentora is checking each response and preparing feedback.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: scheme.surface,
      // resizeToAvoidBottomInset defaults to true; combined with the
      // SingleChildScrollView body this avoids the 68px bottom overflow when
      // the keyboard opens on shorter devices.
      appBar: AppBar(
        title: Text('Question ${_currentIndex + 1} of ${_questions.length}'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 4,
            backgroundColor: scheme.surfaceContainerHigh,
            color: scheme.primary,
          ),
        ),
      ),
      // Button row lives in the persistent footer so the keyboard can never
      // push it off-screen.
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              if (_currentIndex > 0)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _previousQuestion,
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('Previous'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              if (_currentIndex > 0) const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: _nextQuestion,
                  icon: Icon(
                    isLast ? Icons.check_rounded : Icons.arrow_forward_rounded,
                  ),
                  label: Text(isLast ? 'Submit answers' : 'Next question'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _QuestionCard(
                index: _currentIndex,
                total: _questions.length,
                question: _questions[_currentIndex],
              ),
              const SizedBox(height: 18),
              Text(
                'Your answer',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _answerController,
                focusNode: _answerFocus,
                minLines: 3,
                maxLines: 5,
                // "Done" / "Next" key submits the answer without needing to
                // scroll or dismiss the keyboard manually.
                textInputAction: isLast
                    ? TextInputAction.done
                    : TextInputAction.next,
                onSubmitted: (_) => _nextQuestion(),
                decoration: const InputDecoration(
                  hintText: 'Type your answer here...',
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.index,
    required this.total,
    required this.question,
  });

  final int index;
  final int total;
  final String question;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.primary, Color(0xFF4C1D95)],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.25),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: scheme.onPrimary.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Q${index + 1} / $total',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onPrimary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              const Spacer(),
              Icon(
                Icons.help_outline_rounded,
                color: scheme.onPrimary.withValues(alpha: 0.85),
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            question,
            style: theme.textTheme.titleLarge?.copyWith(
              color: scheme.onPrimary,
              fontWeight: FontWeight.w800,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
