import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studymate/screens/home_screen.dart';
import 'package:studymate/screens/calculator_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Finder btn(String label) => find.byKey(ValueKey('calc_btn_$label'));
  Finder delBtn() => find.byKey(const ValueKey('calc_btn_del'));
  Finder resultText() => find.byKey(const ValueKey('calc_result_text'));
  Finder errorText() => find.byKey(const ValueKey('calc_error_text'));

  group('Calculator Feature Tests', () {
    testWidgets('HomeScreen displays Calculator shortcut and navigates to CalculatorScreen',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll down so Quick Access Calculator card is in view
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await tester.pumpAndSettle();

      // Verify Calculator shortcut exists in Quick Access
      expect(find.text('Calculator'), findsWidgets);
      expect(find.text('Mini study & quick calculations'), findsOneWidget);
      expect(find.byIcon(Icons.calculate_rounded), findsWidgets);

      // Tap the Calculator shortcut
      await tester.tap(find.text('Mini study & quick calculations'));
      await tester.pumpAndSettle();

      // Verify CalculatorScreen opened with display and keypad
      expect(find.byType(CalculatorScreen), findsOneWidget);
      expect(btn('AC'), findsOneWidget);
      expect(btn('='), findsOneWidget);
    });

    testWidgets('Supports basic arithmetic operations and order of operations',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CalculatorScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Test Addition: 15 + 27 = 42
      await tester.tap(btn('1'));
      await tester.pump();
      await tester.tap(btn('5'));
      await tester.pump();
      await tester.tap(btn('+'));
      await tester.pump();
      await tester.tap(btn('2'));
      await tester.pump();
      await tester.tap(btn('7'));
      await tester.pump();
      await tester.tap(btn('='));
      await tester.pump();

      expect(tester.widget<Text>(resultText()).data, '42');

      // Clear
      await tester.tap(btn('AC'));
      await tester.pump();
      expect(tester.widget<Text>(resultText()).data, '0');

      // Test Subtraction: 50 - 18 = 32
      await tester.tap(btn('5'));
      await tester.pump();
      await tester.tap(btn('0'));
      await tester.pump();
      await tester.tap(btn('−'));
      await tester.pump();
      await tester.tap(btn('1'));
      await tester.pump();
      await tester.tap(btn('8'));
      await tester.pump();
      await tester.tap(btn('='));
      await tester.pump();

      expect(tester.widget<Text>(resultText()).data, '32');

      // Test Multiplication: 9 × 8 = 72
      await tester.tap(btn('AC'));
      await tester.pump();
      await tester.tap(btn('9'));
      await tester.pump();
      await tester.tap(btn('×'));
      await tester.pump();
      await tester.tap(btn('8'));
      await tester.pump();
      await tester.tap(btn('='));
      await tester.pump();

      expect(tester.widget<Text>(resultText()).data, '72');

      // Test Division: 144 ÷ 12 = 12
      await tester.tap(btn('AC'));
      await tester.pump();
      await tester.tap(btn('1'));
      await tester.pump();
      await tester.tap(btn('4'));
      await tester.pump();
      await tester.tap(btn('4'));
      await tester.pump();
      await tester.tap(btn('÷'));
      await tester.pump();
      await tester.tap(btn('1'));
      await tester.pump();
      await tester.tap(btn('2'));
      await tester.pump();
      await tester.tap(btn('='));
      await tester.pump();

      expect(tester.widget<Text>(resultText()).data, '12');

      // Test Order of Operations: 2 + 3 × 4 = 14 (not 20)
      await tester.tap(btn('AC'));
      await tester.pump();
      await tester.tap(btn('2'));
      await tester.pump();
      await tester.tap(btn('+'));
      await tester.pump();
      await tester.tap(btn('3'));
      await tester.pump();
      await tester.tap(btn('×'));
      await tester.pump();
      await tester.tap(btn('4'));
      await tester.pump();
      await tester.tap(btn('='));
      await tester.pump();

      expect(tester.widget<Text>(resultText()).data, '14');
    });

    testWidgets('Supports decimals and percentage calculations',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CalculatorScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Test decimals: 2.5 + 1.25 = 3.75
      await tester.tap(btn('2'));
      await tester.pump();
      await tester.tap(btn('.'));
      await tester.pump();
      await tester.tap(btn('5'));
      await tester.pump();
      await tester.tap(btn('+'));
      await tester.pump();
      await tester.tap(btn('1'));
      await tester.pump();
      await tester.tap(btn('.'));
      await tester.pump();
      await tester.tap(btn('2'));
      await tester.pump();
      await tester.tap(btn('5'));
      await tester.pump();
      await tester.tap(btn('='));
      await tester.pump();

      expect(tester.widget<Text>(resultText()).data, '3.75');

      // Disallow double decimal: 3..5 should not create multiple dots
      await tester.tap(btn('AC'));
      await tester.pump();
      await tester.tap(btn('3'));
      await tester.pump();
      await tester.tap(btn('.'));
      await tester.pump();
      await tester.tap(btn('.'));
      await tester.pump();
      await tester.tap(btn('5'));
      await tester.pump();
      expect(tester.widget<Text>(resultText()).data, '3.5');

      // Percentage: 50% = 0.5
      await tester.tap(btn('AC'));
      await tester.pump();
      await tester.tap(btn('5'));
      await tester.pump();
      await tester.tap(btn('0'));
      await tester.pump();
      await tester.tap(btn('%'));
      await tester.pump();
      expect(tester.widget<Text>(resultText()).data, '0.5');
    });

    testWidgets('Supports delete/backspace and consecutive operator replacement',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CalculatorScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Enter 123
      await tester.tap(btn('1'));
      await tester.pump();
      await tester.tap(btn('2'));
      await tester.pump();
      await tester.tap(btn('3'));
      await tester.pump();
      expect(tester.widget<Text>(resultText()).data, '123');

      // Delete last digit -> 12
      await tester.tap(delBtn());
      await tester.pump();
      expect(tester.widget<Text>(resultText()).data, '12');

      // Operator replacement: + then × replaces with ×
      await tester.tap(btn('+'));
      await tester.pump();
      await tester.tap(btn('×'));
      await tester.pump();
      await tester.tap(btn('3'));
      await tester.pump();
      await tester.tap(btn('='));
      await tester.pump();

      // 12 × 3 = 36
      expect(tester.widget<Text>(resultText()).data, '36');
    });

    testWidgets('Handles division by zero safely without crashing',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CalculatorScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // 10 ÷ 0 =
      await tester.tap(btn('1'));
      await tester.pump();
      await tester.tap(btn('0'));
      await tester.pump();
      await tester.tap(btn('÷'));
      await tester.pump();
      await tester.tap(btn('0'));
      await tester.pump();
      await tester.tap(btn('='));
      await tester.pump();

      // Check error message displayed safely
      expect(tester.widget<Text>(errorText()).data, 'Cannot divide by zero');

      // Press AC to recover
      await tester.tap(btn('AC'));
      await tester.pump();
      expect(tester.widget<Text>(resultText()).data, '0');
      expect(errorText(), findsNothing);
    });

    testWidgets('Supports chained calculations using previous result',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CalculatorScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // 5 + 5 = 10
      await tester.tap(btn('5'));
      await tester.pump();
      await tester.tap(btn('+'));
      await tester.pump();
      await tester.tap(btn('5'));
      await tester.pump();
      await tester.tap(btn('='));
      await tester.pump();
      expect(tester.widget<Text>(resultText()).data, '10');

      // Now press + 7 = 17
      await tester.tap(btn('+'));
      await tester.pump();
      await tester.tap(btn('7'));
      await tester.pump();
      await tester.tap(btn('='));
      await tester.pump();
      expect(tester.widget<Text>(resultText()).data, '17');
    });

    testWidgets('Navigation: tapping back button safely closes CalculatorScreen',
        (WidgetTester tester) async {
      final navKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navKey,
          home: const Scaffold(
            body: Text('Base Screen'),
          ),
        ),
      );

      // Push CalculatorScreen
      navKey.currentState!.push(
        MaterialPageRoute(
          builder: (_) => const CalculatorScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CalculatorScreen), findsOneWidget);

      // Tap back button
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(CalculatorScreen), findsNothing);
      expect(find.text('Base Screen'), findsOneWidget);
    });
  });
}
