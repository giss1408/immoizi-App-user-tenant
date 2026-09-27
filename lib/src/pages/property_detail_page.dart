import 'package:flutter/material.dart';
import 'package:immoizi_core/immoizi_core.dart';

import '../models/dashboard.dart';
import 'interest_request_page.dart';

class PropertyDetailPage extends StatelessWidget {
  const PropertyDetailPage(
      {required this.property,
      required this.tag,
      required this.endpoint,
      required this.token,
      this.openRequest,
      this.onRequestSent,
      super.key});

  final Property property;
  final String tag;
  final String endpoint;
  final String token;

  /// The tenant's unanswered request for this listing, if any.
  final InterestRequestItem? openRequest;
  final VoidCallback? onRequestSent;

  @override
  Widget build(BuildContext context) {
    return PropertyPageScaffold(
      title: property.title,
      statusLabel: tag,
      children: [
        PropertyDetails(property: property),
        const SizedBox(height: 16),
        InterestAction(
            property: property,
            endpoint: endpoint,
            token: token,
            openRequest: openRequest,
            onRequestSent: onRequestSent),
      ],
    );
  }
}

/// "Je suis intéressé" button, or the pending-request notice that replaces
/// it: one open request per listing until the landlord answers or 6 days pass.
class InterestAction extends StatefulWidget {
  const InterestAction(
      {required this.property,
      required this.endpoint,
      required this.token,
      this.openRequest,
      this.onRequestSent,
      super.key});

  final Property property;
  final String endpoint;
  final String token;
  final InterestRequestItem? openRequest;
  final VoidCallback? onRequestSent;

  @override
  State<InterestAction> createState() => _InterestActionState();
}

class _InterestActionState extends State<InterestAction> {
  bool _sentNow = false;

  Future<void> _openForm() async {
    final sent = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => InterestRequestPage(
            property: widget.property,
            endpoint: widget.endpoint,
            token: widget.token)));
    if (sent == true && mounted) {
      setState(() => _sentNow = true);
      widget.onRequestSent?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.openRequest;
    if (request != null || _sentNow) {
      final sentOn = formatShortDate(request?.createdAt);
      final retryOn = formatShortDate(request?.expiresAt);
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: IvoryColors.orange.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: IvoryColors.orange.withOpacity(0.35)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.hourglass_top, color: IvoryColors.orange),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    sentOn.isEmpty
                        ? tr('Demande envoyée')
                        : tr('Demande envoyée le {date}', {'date': sentOn}),
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  retryOn.isEmpty
                      ? tr(
                          'En attente de la réponse du bailleur. Une seule demande par bien est possible à la fois.')
                      : tr(
                          'En attente de la réponse du bailleur. Vous pourrez envoyer une nouvelle demande après sa réponse, ou à partir du {date}.',
                          {'date': retryOn}),
                  style: TextStyle(color: IvoryColors.muted),
                ),
              ],
            ),
          ),
        ]),
      );
    }

    final signedIn = widget.token.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: widget.property.id == null || !signedIn ? null : _openForm,
          icon: const Icon(Icons.mark_email_unread),
          label: Text(tr('Je suis intéressé par ce bien')),
        ),
        if (widget.property.id != null && !signedIn)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: MutedText(tr(
                'Connectez-vous dans « Mon espace » pour envoyer une demande au bailleur.')),
          ),
      ],
    );
  }
}
