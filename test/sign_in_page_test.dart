import 'package:fitstrongcheckin/sign_in_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Renders the sign in screen at a given size.
///
/// Any row or column that does not fit raises a flutter error while painting,
/// which fails the test - so these cases are really checking that the screen
/// survives a small phone and a wide tablet without overflowing.
Future<void> showAt(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(const MaterialApp(home: SignInPage()));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    // The screen reads a saved email on start up.
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows the brand, the three features and the form', (
    tester,
  ) async {
    await showAt(tester, const Size(390, 844));

    expect(find.text('ATTENDANCE'), findsOneWidget);
    expect(find.text('Simple. Secure. Always On.'), findsOneWidget);
    expect(find.text('Scan\nCheck-ins'), findsOneWidget);
    expect(find.text('Manage\nMembers'), findsOneWidget);
    expect(find.text('Track\nAttendance'), findsOneWidget);
    expect(find.text('Sign In'), findsNWidgets(2)); // heading and button
    expect(find.text('Welcome back!'), findsOneWidget);
    expect(find.text('Remember me'), findsOneWidget);
    expect(find.text('Forgot Password?'), findsOneWidget);
  });

  testWidgets('credits the developer with a link', (tester) async {
    await showAt(tester, const Size(390, 844));

    expect(find.text('Developed by Sahil Potdukhe'), findsOneWidget);
    expect(find.text('sahilpotdukhe.github.io'), findsOneWidget);
  });

  testWidgets('fits a narrow phone and a wide tablet', (tester) async {
    await showAt(tester, const Size(320, 568));
    expect(find.text('Welcome back!'), findsOneWidget);

    await showAt(tester, const Size(1024, 1366));
    expect(find.text('Welcome back!'), findsOneWidget);
  });

  testWidgets('will not sign in with the boxes empty', (tester) async {
    await showAt(tester, const Size(390, 844));

    // The button sits below the fold on a phone, so scroll to it first.
    final button = find.text('Sign In').last;
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();

    // Stopped by the form, so Firebase is never called.
    expect(find.text('Enter the gym email'), findsOneWidget);
    expect(find.text('Enter the password'), findsOneWidget);
  });

  testWidgets('remember me can be switched off', (tester) async {
    await showAt(tester, const Size(390, 844));

    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
    await tester.tap(find.text('Remember me'));
    await tester.pumpAndSettle();
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
  });

  testWidgets('the password starts hidden and can be revealed', (
    tester,
  ) async {
    await showAt(tester, const Size(390, 844));

    final password = find.byType(TextFormField).last;
    expect(tester.widget<TextField>(find.byType(TextField).last).obscureText,
        isTrue);

    await tester.tap(find.byTooltip('Show password'));
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(find.byType(TextField).last).obscureText,
        isFalse);
    expect(password, findsOneWidget);
  });
}
