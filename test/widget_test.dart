import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:night_walkers_app/screens/onboarding_screen.dart';

void main() {
  testWidgets('feature tile renders provided icon and text', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FeatureTile(
            icon: Icons.warning,
            text: 'Panic alerts are available',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.warning), findsOneWidget);
    expect(find.text('Panic alerts are available'), findsOneWidget);
  });
}
