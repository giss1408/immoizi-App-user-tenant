import 'package:flutter/material.dart';
import 'package:immoizi_core/immoizi_core.dart';

import '../models/dashboard.dart';

/// Opens the conversation with the landlord about an interest request.
void openInterestChat(BuildContext context, InterestRequestItem request,
    {required String endpoint, required String token}) {
  Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => InterestChatPage(
            isManager: false,
            interestRequestId: request.id,
            propertyTitle: request.propertyTitle,
            endpoint: endpoint,
            token: token,
          )));
}

class InterestRequestTile extends StatelessWidget {
  const InterestRequestTile(this.request,
      {required this.endpoint, required this.token, super.key});

  final InterestRequestItem request;
  final String endpoint;
  final String token;

  @override
  Widget build(BuildContext context) {
    final color =
        interestStatusColor(request.status, expired: request.isExpired);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(Icons.forum_outlined, color: IvoryColors.green),
        title: Text(request.propertyTitle,
            style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(
            interestStatusLabel(request.status, expired: request.isExpired),
            style: TextStyle(color: color, fontWeight: FontWeight.w700)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => openInterestChat(context, request,
            endpoint: endpoint, token: token),
      ),
    );
  }
}
