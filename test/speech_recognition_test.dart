import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import '../lib/main.dart';

// Generate mock class
@GenerateMocks([stt.SpeechToText])
void main() {
  group('BMI Voice Input Tests', () {
    late VoiceBMIPageState pageState;

    setUp(() {
      pageState = VoiceBMIPageState();
    });

    test('Extract height and weight from normal format', () {
      const input = "tinggi 170 cm berat 65 kg";
      pageState._recognizedWords = input;
      pageState._extractData(input);

      expect(pageState._heightCm, 170);
      expect(pageState._weightKg, 65);
    });

    test('Extract height and weight from reverse format', () {
      const input = "65 kg 170 cm";
      pageState._recognizedWords = input;
      pageState._extractData(input);

      expect(pageState._heightCm, 170);
      expect(pageState._weightKg, 65);
    });

    test('Extract height and weight with decimals', () {
      const input = "tinggi 170,5 cm berat 65,5 kg";
      pageState._recognizedWords = input;
      pageState._extractData(input);

      expect(pageState._heightCm, 170.5);
      expect(pageState._weightKg, 65.5);
    });

    test('Handle invalid height input', () {
      const input = "tinggi 300 cm berat 65 kg";
      pageState._recognizedWords = input;
      
      expect(
        () => pageState._extractData(input),
        throwsA(isA<FormatException>()),
      );
    });

    test('Handle invalid weight input', () {
      const input = "tinggi 170 cm berat 500 kg";
      pageState._recognizedWords = input;
      
      expect(
        () => pageState._extractData(input),
        throwsA(isA<FormatException>()),
      );
    });

    test('Handle empty input', () {
      const input = "";
      pageState._recognizedWords = input;
      
      expect(
        () => pageState._extractData(input),
        throwsA(isA<FormatException>()),
      );
    });

    test('Calculate BMI correctly', () {
      pageState._heightCm = 170;
      pageState._weightKg = 65;
      pageState._calculateBMI();

      // BMI = weight / (height in meters)²
      // 65 / (1.7)² = 22.49
      expect(pageState._bmi, closeTo(22.49, 0.01));
    });

    test('Get correct BMI category', () {
      pageState._bmi = 22.49;
      expect(pageState._getBMICategory(), 'Normal Weight');

      pageState._bmi = 17.0;
      expect(pageState._getBMICategory(), 'Underweight');

      pageState._bmi = 24.0;
      expect(pageState._getBMICategory(), 'Overweight with Risk');

      pageState._bmi = 27.0;
      expect(pageState._getBMICategory(), 'Obese I');

      pageState._bmi = 35.0;
      expect(pageState._getBMICategory(), 'Obese II');
    });
  });
} 