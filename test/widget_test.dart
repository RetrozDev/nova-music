import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nova_music/src/theme/app_theme.dart';

void main() {
  testWidgets('Theme builds without errors', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const Scaffold(body: SizedBox()),
      ),
    );
    expect(find.byType(Scaffold), findsOneWidget);
  });
}
