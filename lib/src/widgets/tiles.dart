import 'package:flutter/material.dart';
import 'package:immoizi_core/immoizi_core.dart';

import '../models/dashboard.dart';

class PaymentTile extends StatelessWidget {
  const PaymentTile(this.payment, {super.key});
  final Payment payment;

  @override
  Widget build(BuildContext context) => InfoTile(
        icon: Icons.payments,
        title: '${payment.amount} FCFA',
        subtitle: 'Échéance ${payment.dueDate}',
        trailing: payment.status,
      );
}

class DocumentTile extends StatelessWidget {
  const DocumentTile(this.document, {super.key});
  final DocumentItem document;

  @override
  Widget build(BuildContext context) => InfoTile(
        icon: Icons.description,
        title: document.title,
        subtitle: document.type,
      );
}

class MaintenanceTile extends StatelessWidget {
  const MaintenanceTile(this.request, {super.key});
  final Maintenance request;

  @override
  Widget build(BuildContext context) => InfoTile(
        icon: Icons.build,
        title: request.title,
        subtitle: request.priority,
        trailing: request.status,
      );
}
