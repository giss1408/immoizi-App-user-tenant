import 'package:immoizi_core/immoizi_core.dart';

class TenantDashboard {
  TenantDashboard(
    this.username,
    this.roleText,
    this.publicProperties,
    this.tenantProperties,
    this.payments,
    this.documents,
    this.maintenance,
    this.interestRequests,
    this.notifications,
  );

  final String username;
  final String roleText;
  final List<Property> publicProperties;
  final List<Property> tenantProperties;
  final List<Payment> payments;
  final List<DocumentItem> documents;
  final List<Maintenance> maintenance;
  final List<InterestRequestItem> interestRequests;
  final List<NotificationItem> notifications;

  /// The open request for a listing, which blocks sending another one.
  InterestRequestItem? openRequestFor(String? propertyId) {
    if (propertyId == null) return null;
    for (final request in interestRequests) {
      if (request.propertyId == propertyId && request.isOpen) return request;
    }
    return null;
  }

  factory TenantDashboard.fromJson(Map<String, dynamic> json) {
    final me = json['me'] as Map<String, dynamic>? ?? {};
    final roles = [
      if (me['isSeeker'] == true) 'Recherche',
      if (me['isTenant'] == true) 'Locataire',
    ];

    return TenantDashboard(
      me['username'] as String? ?? 'Utilisateur',
      roles.isEmpty ? 'Utilisateur' : roles.join(' • '),
      jsonItems(json['publicDescriptions']).map(Property.fromJson).toList(),
      jsonItems(json['myTenantProperties']).map(Property.fromJson).toList(),
      jsonItems(json['myTenantPayments']).map(Payment.fromJson).toList(),
      jsonItems(json['myTenantDocuments']).map(DocumentItem.fromJson).toList(),
      jsonItems(json['myTenantMaintenanceRequests'])
          .map(Maintenance.fromJson)
          .toList(),
      jsonItems(json['myPropertyInterestRequests'])
          .map(InterestRequestItem.fromJson)
          .toList(),
      jsonItems(json['notifications']).map(NotificationItem.fromJson).toList(),
    );
  }

  factory TenantDashboard.demo() => TenantDashboard(
        'Nadia D.',
        'Locataire • Chercheuse',
        [
          Property(
            'Appartement vue jardin',
            'Residence',
            'Abidjan',
            'Cocody',
            3,
            82,
            340000,
            isTestData: true,
            description:
                'Appartement calme avec jardin privé, proche des écoles internationales.',
            mainImageUrl: 'https://placehold.co/600x400',
            hasVideo: true,
            videoUrl: 'https://media.w3.org/2010/05/sintel/trailer.mp4',
          ),
          Property('Studio lumineux', 'Residence', 'Yamoussoukro', 'Centre', 1,
              42, 195000,
              isTestData: true,
              description:
                  'Studio rénové avec cuisine équipée et bonne luminosité.'),
          Property('Villa familiale', 'Residence', 'Abidjan', 'Plateau', 4, 150,
              580000,
              isTestData: true,
              description:
                  'Villa spacieuse avec jardin clôturé et parking pour deux véhicules.'),
          Property('Bureau commercial centre-ville', 'Business', 'Abidjan',
              'Plateau', 2, 98, 480000,
              isTestData: true,
              description:
                  'Espace de bureaux climatisé, proche des institutions financières.'),
          Property('Local commercial passant', 'Commerce', 'Yamoussoukro',
              'Centre', 1, 60, 260000,
              isTestData: true,
              description:
                  'Local en rez-de-chaussée avec forte visibilité et accès client direct.'),
          Property('Entrepôt logistique', 'Industrie', 'Abidjan', 'Vridi', 1,
              540, 1150000,
              isTestData: true,
              description:
                  'Entrepôt sécurisé avec quai de chargement et bureaux annexes.'),
        ],
        [
          Property(
            'Maison d’habitation',
            'Residence',
            'Abidjan',
            'Le Plateau',
            3,
            112,
            440000,
            isTestData: true,
            description:
                'Maison familiale louée avec séjour spacieux et cour extérieure.',
            mainImageUrl: 'https://placehold.co/600x400',
          ),
        ],
        [
          Payment('340000', 'Payé', '05/10/2026'),
          Payment('420000', 'En attente', '05/11/2026'),
        ],
        [
          DocumentItem('Contrat de location', 'Bail'),
          DocumentItem('Carte d’identité', 'Pièce'),
        ],
        [
          Maintenance('Chauffe-eau', 'Moyenne', 'En cours'),
          Maintenance('Fuite sous évier', 'Urgente', 'Planifiée'),
        ],
        [],
        [],
      );
}

class Payment {
  Payment(this.amount, this.status, this.dueDate);

  final String amount;
  final String status;
  final String dueDate;

  factory Payment.fromJson(Map<String, dynamic> json) => Payment(
        '${json['amount'] ?? '-'}',
        json['status'] as String? ?? '-',
        json['dueDate'] as String? ?? '-',
      );
}

class DocumentItem {
  DocumentItem(this.title, this.type);

  final String title;
  final String type;

  factory DocumentItem.fromJson(Map<String, dynamic> json) => DocumentItem(
        json['title'] as String? ?? '-',
        json['documentType'] as String? ?? '-',
      );
}

class Maintenance {
  Maintenance(this.title, this.priority, this.status);

  final String title;
  final String priority;
  final String status;

  factory Maintenance.fromJson(Map<String, dynamic> json) => Maintenance(
        json['title'] as String? ?? '-',
        json['priority'] as String? ?? '-',
        json['status'] as String? ?? '-',
      );
}

class NotificationItem {
  NotificationItem(
      this.id, this.title, this.message, this.propertyTitle, this.isRead,
      {this.interestRequestId});

  /// Set when the notification is about an interest request.
  final String? interestRequestId;

  final String id;
  final String title;
  final String message;
  final String propertyTitle;
  final bool isRead;

  factory NotificationItem.fromJson(Map<String, dynamic> json) =>
      NotificationItem(
        json['id'] as String? ?? '',
        json['title'] as String? ?? 'Notification',
        json['message'] as String? ?? '',
        nestedTitle(json['property']),
        json['isRead'] as bool? ?? false,
        interestRequestId: (json['interestRequest']
            as Map<String, dynamic>?)?['id'] as String?,
      );
}

class InterestRequestItem {
  InterestRequestItem(this.id, this.propertyTitle, this.status,
      {this.propertyId,
      this.isExpired = false,
      this.expiresAt,
      this.createdAt});

  final String id;
  final String propertyTitle;
  final String status;
  final String? propertyId;
  final bool isExpired;
  final String? expiresAt;
  final String? createdAt;

  /// Still waiting for the landlord, within the 6-day window.
  bool get isOpen => isOpenInterestStatus(status, expired: isExpired);

  factory InterestRequestItem.fromJson(Map<String, dynamic> json) =>
      InterestRequestItem(
        json['id'] as String? ?? '',
        nestedTitle(json['property']),
        json['status'] as String? ?? '-',
        propertyId:
            (json['property'] as Map<String, dynamic>?)?['id'] as String?,
        isExpired: json['isExpired'] as bool? ?? false,
        expiresAt: json['expiresAt'] as String?,
        createdAt: json['createdAt'] as String?,
      );
}
