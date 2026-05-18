import 'package:flutter_test/flutter_test.dart';
import 'package:mentora_app/features/study/services/ai_study_service.dart';

void main() {
  group('AiStudyService question quality filter', () {
    test('rejects grammar-role questions about prompt metadata words', () {
      expect(
        AiStudyService.isLowQualityGeneratedQuestion(
          'What is the function of the word "instruction" in the context of the text?',
        ),
        isTrue,
      );
    });

    test('allows useful vocabulary questions from the material', () {
      expect(
        AiStudyService.isLowQualityGeneratedQuestion(
          'What does the word "courage" mean when the character enters the cave?',
        ),
        isFalse,
      );
    });

    test('rejects quiz formats that do not ask for written understanding', () {
      expect(
        AiStudyService.isLowQualityGeneratedQuestion(
          'True or false: the character enters the cave before sunset?',
        ),
        isTrue,
      );
    });
  });
}
