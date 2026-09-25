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
    super.key,
  });

  final TenantDashboard dashboard;
  final String endpoint;
  final String token;
  final VoidCallback onSubmitted;
  final String searchQuery;
  final PropertyFilters filters;

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
        SectionHeader('Biens disponibles',
            count: availableProperties.length,
            subtitle: 'Logements et locaux à louer près de chez vous'),
        GroupedPropertyList(
          properties: availableProperties,
          cardBuilder: (property) => PropertyCard(property,
              tag: 'Disponible', endpoint: endpoint, token: token),
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
            label: 'Biens',
            value: '${dashboard.publicProperties.length}',
            icon: Icons.home,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: MetricChip(
            label: 'Loués',
            value: '${dashboard.tenantProperties.length}',
            icon: Icons.key,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: MetricChip(
            label: 'Paiements',
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
        color: Colors.white,
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
              style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  color: IvoryColors.ink)),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: IvoryColors.muted)),
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
      color: const Color(0xFFFFF3E6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 28,
              backgroundColor: Color(0xFFFF8C00),
              child: Icon(Icons.person, color: Colors.white),
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
                  Text(role, style: const TextStyle(color: Colors.black54)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.verified, size: 16, color: Color(0xFFFF8C00)),
                  SizedBox(width: 4),
                  Text('Actif', style: TextStyle(fontWeight: FontWeight.w700)),
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
      super.key});

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
                token: token)),
      ),
    );
  }
}
