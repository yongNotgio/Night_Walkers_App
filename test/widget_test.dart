import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:night_walkers_app/screens/onboarding_screen.dart';

void main() {
  testWidgets('onboarding welcome renders core headline', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: OnboardingScreen(),
      ),
    );
    await tester.pump();

    expect(find.text('Night Walkers'), findsOneWidget);
    expect(find.text('Setup takes less than a minute.'), findsOneWidget);
  });
}
