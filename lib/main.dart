import 'package:flutter/material.dart';
import 'package:immoizi_core/immoizi_core.dart';

import 'src/home_page.dart';
import 'src/i18n/tenant_strings.dart';

Future<void> main() => runImmoiziApp(const ImmoiziUserTenantApp());

class ImmoiziUserTenantApp extends StatelessWidget {
  const ImmoiziUserTenantApp({this.client, super.key});

  final GraphQLClient? client;

  @override
  Widget build(BuildContext context) => ImmoiziApp(
        title: 'Immoizi',
        translations: tenantEnglish,
        home: (_) => TenantHomePage(client: client),
      );
}
