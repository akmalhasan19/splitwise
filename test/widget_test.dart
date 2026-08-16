import 'package:flutter_test/flutter_test.dart';

import 'package:debt_splitter/main.dart';

void main() {
  testWidgets('DebtSplitterApp renders offline-first placeholder', (
    tester,
  ) async {
    await tester.pumpWidget(const DebtSplitterApp());

    // App bar title
    expect(find.text('Debt-Splitter'), findsWidgets);
    // Tagline offline-first dari layar placeholder di lib/main.dart
    expect(find.textContaining('Offline-First'), findsOneWidget);
    expect(find.textContaining('tersimpan lokal'), findsOneWidget);
  });
}
