import 'package:flutter/material.dart';
import 'package:immoizi_core/immoizi_core.dart';

import 'src/home_page.dart';
import 'src/i18n/tenant_strings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSettings.instance.load();
  runApp(const ImmoiziUserTenantApp());
}

class ImmoiziUserTenantApp extends StatelessWidget {
  const ImmoiziUserTenantApp({this.client, super.key});

  final GraphQLClient? client;

  @override
  Widget build(BuildContext context) {
    AppStrings.register(tenantEnglish);
    // Rebuilds the whole app when the theme or language changes.
    return ListenableBuilder(
      listenable: AppSettings.instance,
      builder: (context, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Immoizi',
        theme: AppTheme.current(),
        locale: AppSettings.instance.locale,
        supportedLocales: AppSettings.supportedLocales,
        localizationsDelegates: AppSettings.localizationsDelegates,
        home: TenantHomePage(client: client),
      ),
    );
  }
}
