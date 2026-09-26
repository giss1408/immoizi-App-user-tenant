import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:immoizi_app_user_tenant/main.dart';
import 'package:immoizi_core/immoizi_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('changing the theme keeps the current tab', (tester) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    addTearDown(() {
      AppPalette.current = AppPalette.ivoire;
      AppStrings.language = AppLanguage.fr;
    });
    var requests = 0;
    final client = GraphQLClient(httpClient: MockClient((_) async {
      requests++;
      return http.Response('{}', 500);
    }));
    await tester.pumpWidget(ImmoiziUserTenantApp(client: client));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mon espace').last);
    await tester.pumpAndSettle();
    final before = requests;

    await AppSettings.instance.setPalette(AppPalette.dracula);
    await tester.pumpAndSettle();
    expect(find.text('Suivi, paiements et actions locataires'), findsOneWidget,
        reason: 'still on Mon espace after a theme change');

    await AppSettings.instance.setLanguage(AppLanguage.en);
    await tester.pumpAndSettle();
    expect(find.text('Tracking, payments and tenant actions'), findsOneWidget,
        reason: 'still on Mon espace after a language change');
    expect(requests, before, reason: 'settings changes must not reload data');
  });
}
