import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:immoizi_app_user_tenant/src/models/dashboard.dart';
import 'package:immoizi_app_user_tenant/src/pages/property_detail_page.dart';
import 'package:immoizi_core/immoizi_core.dart';

InterestRequestItem _request(String status,
        {bool expired = false, String propertyId = '7'}) =>
    InterestRequestItem('1', 'Villa Cocody', status,
        propertyId: propertyId,
        isExpired: expired,
        createdAt: '2026-09-25T10:00:00+00:00',
        expiresAt: '2026-10-01T10:00:00+00:00');

TenantDashboard _dashboard(List<InterestRequestItem> requests) =>
    TenantDashboard('Nadia', 'Locataire', [], [], [], [], [], requests, []);

void main() {
  final property = Property(
      'Villa Cocody', 'Residence', 'Abidjan', 'Cocody', 5, 220, 920000,
      id: '7');

  Future<void> pumpAction(WidgetTester tester,
      {InterestRequestItem? openRequest}) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: InterestAction(
            property: property,
            endpoint: 'http://backend.test/graphql',
            token: 'tok',
            openRequest: openRequest),
      ),
    ));
  }

  testWidgets('shows the request button when nothing is pending',
      (tester) async {
    await pumpAction(tester);
    expect(find.text('Je suis intéressé par ce bien'), findsOneWidget);
  });

  testWidgets('replaces the button while a request is open', (tester) async {
    await pumpAction(tester, openRequest: _request('PENDING'));
    expect(find.text('Je suis intéressé par ce bien'), findsNothing);
    expect(find.text('Demande envoyée le 25/09/2026'), findsOneWidget);
    expect(find.textContaining('à partir du 01/10/2026'), findsOneWidget);
  });

  test('only unanswered, unexpired requests for the listing block', () {
    expect(_dashboard([_request('PENDING')]).openRequestFor('7'), isNotNull);
    expect(_dashboard([_request('REVIEWING')]).openRequestFor('7'), isNotNull);
    for (final request in [
      _request('ACCEPTED'),
      _request('REJECTED'),
      _request('PENDING', expired: true),
      _request('PENDING', propertyId: '8'),
    ]) {
      expect(_dashboard([request]).openRequestFor('7'), isNull,
          reason: '${request.status} expired=${request.isExpired}');
    }
  });

  test('expired requests are labelled as such', () {
    expect(interestStatusLabel('PENDING', expired: true), 'Expirée');
    expect(interestStatusLabel('ACCEPTED'), 'Acceptée');
  });
}
