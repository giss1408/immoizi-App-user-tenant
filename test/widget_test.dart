// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:immoizi_app_user_tenant/main.dart';

void main() {
    testWidgets('renders tenant dashboard shell', (WidgetTester tester) async {
      await tester.pumpWidget(const ImmoiziUserTenantApp());
      await tester.pumpAndSettle();

      expect(find.text('Immoizi'), findsOneWidget);
      expect(find.text('Recherche & espace locataire'), findsOneWidget);
      expect(find.text('Synchroniser'), findsOneWidget);
  });
}
