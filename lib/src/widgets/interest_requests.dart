import 'package:flutter/material.dart';
import 'package:immoizi_core/immoizi_core.dart';

import '../models/dashboard.dart';

class InterestRequestTile extends StatelessWidget {
  const InterestRequestTile(this.request,
      {required this.endpoint, required this.token, super.key});

  final InterestRequestItem request;
  final String endpoint;
  final String token;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: const Icon(Icons.forum, color: IvoryColors.green),
          title: Text(request.propertyTitle,
              style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text('Statut : ${request.status}'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => InterestChatPage(
                    isManager: false,
                    interestRequestId: request.id,
                    propertyTitle: request.propertyTitle,
                    endpoint: endpoint,
                    token: token,
                  ))),
        ),
      );
}
