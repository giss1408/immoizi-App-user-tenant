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
  final InterestRequestItem? openRequest;
  final VoidCallback? onRequestSent;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: IvoryColors.green,
        foregroundColor: Colors.white,
        title: Text(property.title),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      property.title,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ),
                  Chip(
                      label: Text(tag),
                      backgroundColor: IvoryColors.orange.withOpacity(0.15)),
                ],
              ),
              const SizedBox(height: 16),
              PropertyDetails(
                  property: property,
                  endpoint: endpoint,
                  token: token,
                  openRequest: openRequest,
                  onRequestSent: onRequestSent),
            ],
          ),
        ),
      ),
    );
  }
}

class PropertyDetails extends StatelessWidget {
  const PropertyDetails(
      {required this.property,
      required this.endpoint,
      required this.token,
      this.openRequest,
      this.onRequestSent,
      super.key});

  final Property property;
  final String endpoint;
  final String token;

  /// The tenant's unanswered request for this listing, if any.
  final InterestRequestItem? openRequest;
  final VoidCallback? onRequestSent;

  List<String> get _allImages => [
        if (property.mainImageUrl != null) property.mainImageUrl!,
        ...property.galleryImageUrls,
      ];

  void _openViewer(BuildContext context, int index) {
    final images = _allImages;
    if (images.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => ImageViewerPage(images: images, initialIndex: index)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (property.mainImageUrl != null)
          GestureDetector(
            onTap: () => _openViewer(context, 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                property.mainImageUrl!,
                height: 260,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const MediaPlaceholder(icon: Icons.image_not_supported),
              ),
            ),
          )
        else
          const MediaPlaceholder(icon: Icons.photo_camera_back),
        if (property.galleryImageUrls.isNotEmpty) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 56,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: property.galleryImageUrls.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) => GestureDetector(
                onTap: () => _openViewer(
                    context, (property.mainImageUrl != null ? 1 : 0) + index),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    property.galleryImageUrls[index],
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox(
                            width: 56,
                            height: 56,
                            child: Icon(Icons.broken_image, size: 20)),
                  ),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            DetailChip(icon: Icons.category, label: property.category),
            DetailChip(
                icon: Icons.place,
                label: '${property.city}, ${property.district}'),
            DetailChip(icon: Icons.payments, label: '${property.price} FCFA'),
            DetailChip(
                icon: Icons.meeting_room, label: '${property.rooms} pièces'),
            DetailChip(
                icon: Icons.square_foot, label: '${property.surface} m²'),
            if (property.hasVideo)
              const DetailChip(icon: Icons.videocam, label: 'Vidéo disponible'),
          ],
        ),
        if (property.description.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Description',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(property.description,
              style: const TextStyle(color: Colors.black87)),
        ],
        if (property.videoUrl != null) ...[
          const SizedBox(height: 12),
          VideoCard(videoUrl: property.videoUrl!, title: property.title),
        ],
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
          const Icon(Icons.hourglass_top, color: IvoryColors.orange),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    sentOn.isEmpty
                        ? 'Demande envoyée'
                        : 'Demande envoyée le $sentOn',
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  retryOn.isEmpty
                      ? 'En attente de la réponse du bailleur. Une seule demande par bien est possible à la fois.'
                      : 'En attente de la réponse du bailleur. Vous pourrez envoyer une nouvelle demande après sa réponse, ou à partir du $retryOn.',
                  style: const TextStyle(color: IvoryColors.muted),
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
          label: const Text('Je suis intéressé par ce bien'),
        ),
        if (widget.property.id != null && !signedIn)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: MutedText(
                'Connectez-vous dans « Mon espace » pour envoyer une demande au bailleur.'),
          ),
      ],
    );
  }
}
