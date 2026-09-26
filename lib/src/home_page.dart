import 'package:flutter/material.dart';
import 'package:immoizi_core/immoizi_core.dart';

import 'api/queries.dart';
import 'models/dashboard.dart';
import 'pages/create_maintenance_page.dart';
import 'views/dashboard_view.dart';
import 'widgets/interest_requests.dart';
import 'widgets/notifications.dart';
import 'widgets/tiles.dart';

class TenantHomePage extends StatefulWidget {
  const TenantHomePage({this.client, super.key});

  /// Injected in tests; a default client is created otherwise.
  final GraphQLClient? client;

  @override
  State<TenantHomePage> createState() => _TenantHomePageState();
}

class _TenantHomePageState extends State<TenantHomePage>
    with DashboardSession<TenantHomePage, TenantDashboard> {
  @override
  late final GraphQLClient client = widget.client ?? GraphQLClient();
  @override
  final cache = const DashboardCache(
      dataKey: 'tenant_dashboard_cache_v1',
      timeKey: 'tenant_dashboard_cache_time_v1');
  @override
  final sessionStore = SessionStore('tenant');
  @override
  final dashboardQuery = tenantQuery;
  @override
  final signedOutQuery = publicListingsQuery;
  @override
  final requiresLogin = false;

  PropertyFilters filters = const PropertyFilters();
  int tab = 0;

  @override
  Map<String, Object?> get extraQueryVariables =>
      {'rentalType': filters.rentalType?.apiValue};

  /// Applies new filters; the rental type is filtered by the backend.
  void _applyFilters(PropertyFilters next) {
    final reload = next.rentalType != filters.rentalType;
    setState(() => filters = next);
    if (reload) load();
  }

  @override
  TenantDashboard parseDashboard(Map<String, dynamic> json) =>
      TenantDashboard.fromJson(json);

  @override
  TenantDashboard demoDashboard() => TenantDashboard.demo();

  @override
  Iterable<AppNotification> notificationsOf(TenantDashboard dashboard) =>
      dashboard.notifications.map((item) => AppNotification(
          id: item.id,
          title: item.title,
          message: item.message,
          isRead: item.isRead,
          interestRequestId: item.interestRequestId));

  @override
  Widget build(BuildContext context) {
    final unread = dashboard.notifications.where((item) => !item.isRead).length;
    final onMySpace = tab == 1;
    return Scaffold(
      drawer: AppDrawer(
        name: connected ? username.text.trim() : dashboard.username,
        role: dashboard.roleText,
        connected: connected,
        onLogout: logout,
        applicationName: 'Immoizi',
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (index) => setState(() => tab = index),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.travel_explore_outlined),
            selectedIcon: const Icon(Icons.travel_explore),
            label: tr('Explorer'),
          ),
          NavigationDestination(
            icon: Badge.count(
                count: unread,
                isLabelVisible: unread > 0,
                child: const Icon(Icons.person_outline)),
            selectedIcon: Badge.count(
                count: unread,
                isLabelVisible: unread > 0,
                child: const Icon(Icons.person)),
            label: tr('Mon espace'),
          ),
        ],
      ),
      body: Column(
        children: [
          AppHeader(
            title: onMySpace ? tr('Mon espace') : 'Immoizi',
            subtitle: onMySpace
                ? tr('Suivi, paiements et actions locataires')
                : tr('Recherche & espace locataire'),
            icon: onMySpace ? Icons.person : Icons.real_estate_agent,
            connected: connected,
            online: online,
            connectedLabel: username.text.trim(),
            loading: loading,
            onRefresh: load,
            bottom: onMySpace
                ? null
                : PropertySearchBar(
                    controller: propertySearch,
                    onChanged: searchProperties,
                    activeFilterCount: filters.activeCount,
                    onOpenFilters: _showFilters,
                  ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: load,
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        CacheStatusBar(
                            lastSynced: lastSynced, loading: loading),
                        if (error != null) ...[
                          const SizedBox(height: 12),
                          ErrorCard(error!),
                        ],
                        const SizedBox(height: 16),
                        if (onMySpace)
                          ..._mySpace()
                        else
                          TenantDashboardView(
                            dashboard,
                            searchQuery: searchQuery,
                            filters: filters,
                            onRentalTypeChanged: (type) => _applyFilters(
                                type == null
                                    ? filters.copyWith(clearRentalType: true)
                                    : filters.copyWith(rentalType: type)),
                            endpoint: endpoint.text.trim(),
                            token: token.text.trim(),
                            onSubmitted: load,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openNotification(NotificationItem notification) {
    if (!notification.isRead) markNotificationRead(notification.id);
    for (final request in dashboard.interestRequests) {
      if (request.id == notification.interestRequestId) {
        openInterestChat(context, request,
            endpoint: endpoint.text.trim(), token: token.text.trim());
        return;
      }
    }
  }

  List<Widget> _mySpace() {
    final endpointValue = endpoint.text.trim();
    final tokenValue = token.text.trim();
    return [
      ConnectionCard(
          endpoint: endpoint,
          token: token,
          username: username,
          password: password,
          loading: loading,
          loggingIn: loggingIn,
          connected: connected,
          onPressed: load,
          onLogin: login,
          onLogout: logout),
      ProfileCard(name: dashboard.username, role: dashboard.roleText),
      SummaryRow(dashboard: dashboard),
      if (dashboard.notifications.any((item) => !item.isRead))
        TenantUnreadNotificationBanner(
            notification:
                dashboard.notifications.firstWhere((item) => !item.isRead),
            onTap: () => _openNotification(
                dashboard.notifications.firstWhere((item) => !item.isRead))),
      const SizedBox(height: 12),
      CategorySection(
          title: tr('Mes biens loués'),
          icon: Icons.key,
          count: dashboard.tenantProperties.length,
          children: dashboard.tenantProperties
              .map((property) => PropertyCard(property,
                  tag: tr('Loué'), endpoint: endpointValue, token: tokenValue))
              .toList()),
      CategorySection(
          title: tr('Paiements'),
          icon: Icons.receipt_long,
          count: dashboard.payments.length,
          children: dashboard.payments.map(PaymentTile.new).toList()),
      CategorySection(
          title: 'Documents',
          icon: Icons.description,
          count: dashboard.documents.length,
          children: dashboard.documents.map(DocumentTile.new).toList()),
      CategorySection(
          title: 'Maintenance',
          icon: Icons.build,
          count: dashboard.maintenance.length,
          children: [
            ...dashboard.maintenance.map(MaintenanceTile.new),
            CreateMaintenanceCard(
                properties: dashboard.tenantProperties,
                endpoint: endpointValue,
                token: tokenValue,
                onSubmitted: load)
          ]),
      CategorySection(
          title: 'Notifications',
          icon: Icons.notifications_none,
          count: dashboard.notifications.length,
          initiallyExpanded:
              dashboard.notifications.any((item) => !item.isRead),
          children: dashboard.notifications
              .map((item) =>
                  NotificationTile(item, onTap: () => _openNotification(item)))
              .toList()),
      CategorySection(
          title: tr("Mes demandes d'intérêt"),
          icon: Icons.forum_outlined,
          count: dashboard.interestRequests.length,
          children: dashboard.interestRequests
              .map((item) => InterestRequestTile(item,
                  endpoint: endpointValue, token: tokenValue))
              .toList()),
      const SizedBox(height: 4),
      const PreferencesCard(),
    ];
  }

  Future<void> _showFilters() async {
    final result = await showModalBottomSheet<PropertyFilters>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => PropertyFilterSheet(
            initial: filters,
            categories: dashboard.publicProperties
                .map((property) => property.category)
                .toSet()
                .toList()
              ..sort()));
    if (result != null && mounted) _applyFilters(result);
  }
}
