import 'package:flutter/material.dart';
import 'package:immoizi_core/immoizi_core.dart';

import 'src/home_page.dart';

void main() => runApp(const ImmoiziUserTenantApp());

class ImmoiziUserTenantApp extends StatelessWidget {
  const ImmoiziUserTenantApp({this.client, super.key});

  final GraphQLClient? client;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Immoizi',
      theme: AppTheme.light(),
      home: TenantHomePage(client: client),
    );
  }
}
