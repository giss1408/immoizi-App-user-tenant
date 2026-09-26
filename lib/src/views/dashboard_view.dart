import 'package:flutter/material.dart';
import 'package:immoizi_core/immoizi_core.dart';

import '../models/dashboard.dart';
import '../pages/property_detail_page.dart';

class TenantDashboardView extends StatelessWidget {
  const TenantDashboardView(
    this.dashboard, {
    required this.endpoint,
    required this.token,
    required this.onSubmitted,
    this.searchQuery = '',
    this.filters = const PropertyFilters(),
    this.onRentalTypeChanged,
    super.key,
  });

  final TenantDashboard dashboard;
  final String endpoint;
  final String token;
  final VoidCallback onSubmitted;
  final String searchQuery;
  final PropertyFilters filters;

  /// Quick "Toutes / Au mois / Courte durée" filter.
  final ValueChanged<RentalType?>? onRentalTypeChanged;

  @override
  Widget build(BuildContext context) {
    final query = searchQuery.trim().toLowerCase();
    final availableProperties = dashboard.publicProperties.where((property) {
      final matchesSearch = query.isEmpty ||
          property.title.toLowerCase().contains(query) ||
          property.city.toLowerCase().contains(query) ||
          property.district.toLowerCase().contains(query);
      return matchesSearch && filters.matches(property);
    }).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(tr('Biens disponibles'),
            count: availableProperties.length,
            subtitle: tr('Logements et locaux à louer près de chez vous')),
        if (onRentalTypeChanged != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: RentalTypeChips(
                value: filters.rentalType, onChanged: onRentalTypeChanged!),
          ),
        GroupedPropertyList(
          properties: availableProperties,
          cardBuilder: (property) => PropertyCard(property,
              tag: tr('Disponible'),
              endpoint: endpoint,
              token: token,
              openRequest: dashboard.openRequestFor(property.id),
              onRequestSent: onSubmitted),
        ),
      ],
    );
  }
}

class SummaryRow extends StatelessWidget {
  const SummaryRow({required this.dashboard, super.key});

  final TenantDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: MetricChip(
            label: tr('Biens'),
            value: '${dashboard.publicProperties.length}',
            icon: Icons.home,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: MetricChip(
            label: tr('Loués'),
            value: '${dashboard.tenantProperties.length}',
            icon: Icons.key,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: MetricChip(
            label: tr('Paiements'),
            value: '${dashboard.payments.length}',
            icon: Icons.receipt_long,
          ),
        ),
      ],
    );
  }
}

class MetricChip extends StatelessWidget {
  const MetricChip({
    required this.label,
    required this.value,
    required this.icon,
    super.key,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: IvoryColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: IvoryColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: IvoryColors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: IvoryColors.green),
          ),
          const SizedBox(height: 10),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  color: IvoryColors.ink)),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: IvoryColors.muted)),
        ],
      ),
    );
  }
}

class ProfileCard extends StatelessWidget {
  const ProfileCard({required this.name, required this.role, super.key});

  final String name;
  final String role;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: IvoryColors.orange.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: IvoryColors.orange,
              child: Icon(Icons.person, color: IvoryColors.onAccent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(role, style: TextStyle(color: IvoryColors.muted)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: IvoryColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.verified, size: 16, color: IvoryColors.orange),
                  const SizedBox(width: 4),
                  Text(tr('Actif'),
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PropertyCard extends StatelessWidget {
  const PropertyCard(this.property,
      {required this.tag,
      required this.endpoint,
      required this.token,
      this.openRequest,
      this.onRequestSent,
      super.key});

  final InterestRequestItem? openRequest;
  final VoidCallback? onRequestSent;

  final Property property;
  final String tag;
  final String endpoint;
  final String token;

  @override
  Widget build(BuildContext context) {
    return PropertyListingCard(
      property,
      statusLabel: tag,
      fallbackIcon: Icons.apartment,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
            builder: (_) => PropertyDetailPage(
                property: property,
                tag: tag,
                endpoint: endpoint,
                token: token,
                openRequest: openRequest,
                onRequestSent: onRequestSent)),
      ),
    );
  }
}
