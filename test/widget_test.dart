import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:immoizi_app_user_tenant/main.dart';
import 'package:immoizi_core/immoizi_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records requests and answers with [handler].
class FakeBackend {
  FakeBackend(this.handler);

  final http.Response Function(Map<String, dynamic> body, http.Request request)
      handler;
  final requests = <http.Request>[];

  GraphQLClient get client =>
      GraphQLClient(httpClient: MockClient((request) async {
        requests.add(request);
        return handler(
            jsonDecode(request.body) as Map<String, dynamic>, request);
      }));
}

http.Response _json(Object body) => http.Response(jsonEncode(body), 200,
    headers: {'content-type': 'application/json; charset=utf-8'});

Map<String, dynamic> _dashboard(
        {String title = 'Villa Riviera',
        String rentalType = 'LONG_TERM',
        int price = 650000}) =>
    {
      'me': null,
      'publicDescriptions': [
        {
          'id': '1',
          'title': title,
          'city': 'Abidjan',
          'district': 'Riviera',
          'rooms': 4,
          'surfaceM2': 140,
          'price': price,
          'category': {'title': 'Residence'},
          'rentalType': rentalType,
        }
      ],
      'myTenantProperties': [],
      'myTenantPayments': [],
      'myTenantDocuments': [],
      'myTenantMaintenanceRequests': [],
      'myPropertyInterestRequests': [],
      'notifications': [],
    };

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('falls back to demo data when the backend is unreachable',
      (tester) async {
    final backend = FakeBackend((_, __) => throw http.ClientException('down'));
    await tester.pumpWidget(ImmoiziUserTenantApp(client: backend.client));
    await tester.pumpAndSettle();

    expect(find.text('Immoizi'), findsOneWidget);
    expect(find.text('Recherche & espace locataire'), findsOneWidget);
    expect(find.byTooltip('Synchroniser'), findsOneWidget);
    expect(find.textContaining('Serveur injoignable'), findsOneWidget);
    expect(find.text('Appartement vue jardin'), findsOneWidget);
  });

  testWidgets('loads public listings without signing in', (tester) async {
    // Like the real backend: touching a protected field without a token
    // fails the whole response.
    final backend = FakeBackend((body, request) {
      final query = body['query'] as String;
      if (!request.headers.containsKey('Authorization') &&
          query.contains('myTenant')) {
        return _json({
          'errors': [
            {'message': "L'authentification est obligatoire."}
          ]
        });
      }
      return _json({'data': _dashboard()});
    });
    await tester.pumpWidget(ImmoiziUserTenantApp(client: backend.client));
    await tester.pumpAndSettle();

    expect(find.text('Villa Riviera'), findsOneWidget);
    expect(find.text('650 000 FCFA / mois'), findsOneWidget);
    expect(
        backend.requests.single.headers.containsKey('Authorization'), isFalse);
  });

  testWidgets('restores the stored session on startup', (tester) async {
    FlutterSecureStorage.setMockInitialValues({
      'tenant_token': 'stored-token',
      'tenant_username': 'nadia',
      'tenant_endpoint': 'http://backend.test/graphql',
    });
    final backend = FakeBackend((_, __) => _json({'data': _dashboard()}));
    await tester.pumpWidget(ImmoiziUserTenantApp(client: backend.client));
    await tester.pumpAndSettle();

    final request = backend.requests.single;
    expect(request.url.toString(), 'http://backend.test/graphql');
    expect(request.headers['Authorization'], 'Bearer stored-token');
    expect(find.text('Connecté — nadia'), findsOneWidget);
  });

  testWidgets('an expired token signs the user out', (tester) async {
    FlutterSecureStorage.setMockInitialValues({'tenant_token': 'expired'});
    final backend = FakeBackend((_, __) => _json({
          'errors': [
            {'message': "L'authentification est obligatoire."}
          ]
        }));
    await tester.pumpWidget(ImmoiziUserTenantApp(client: backend.client));
    await tester.pumpAndSettle();

    expect(find.textContaining('Session expirée'), findsOneWidget);
    expect(find.text('Mode démonstration'), findsOneWidget);
    expect(
        await const FlutterSecureStorage().read(key: 'tenant_token'), isNull);
  });

  testWidgets('a search result does not overwrite the offline cache',
      (tester) async {
    final backend = FakeBackend((body, _) {
      final search = (body['variables'] as Map)['search'];
      return _json({
        'data': _dashboard(title: search == null ? 'Villa Riviera' : 'Studio')
      });
    });
    await tester.pumpWidget(ImmoiziUserTenantApp(client: backend.client));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'studio');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(backend.requests, hasLength(2));

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('tenant_dashboard_cache_v1'),
        contains('Villa Riviera'));
  });

  testWidgets('the rental duration chips filter listings on the backend',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final backend = FakeBackend((body, _) {
      final rentalType = (body['variables'] as Map)['rentalType'];
      return _json({
        'data': rentalType == 'short_term'
            ? _dashboard(
                title: 'Appartement meublé Riviera',
                rentalType: 'SHORT_TERM',
                price: 35000)
            : _dashboard()
      });
    });
    await tester.pumpWidget(ImmoiziUserTenantApp(client: backend.client));
    await tester.pumpAndSettle();
    expect(find.text('Villa Riviera'), findsOneWidget);

    await tester.tap(find.text('Courte durée'));
    await tester.pumpAndSettle();

    expect((jsonDecode(backend.requests.last.body) as Map)['variables'],
        {'search': null, 'rentalType': 'short_term'});
    expect(find.text('Appartement meublé Riviera'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(
        prefs.getString('tenant_dashboard_cache_v1'), contains('Villa Riviera'),
        reason: 'filtered results must not replace the offline cache');
  });
}
