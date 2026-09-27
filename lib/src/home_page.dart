import 'package:flutter/material.dart';
import 'package:immoizi_core/immoizi_core.dart';

import 'api/queries.dart';
import 'models/dashboard.dart';
import 'pages/create_maintenance_page.dart';
import 'views/dashboard_view.dart';
import 'widgets/interest_requests.dart';
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

  int tab = 0;

  @override
  TenantDashboard parseDashboard(Map<String, dynamic> json) =>
      TenantDashboard.fromJson(json);

  @override
  TenantDashboard demoDashboard() => TenantDashboard.demo();

  @override
  Iterable<AppNotification> notificationsOf(TenantDashboard dashboard) =>
      dashboard.notifications;

  @override
  Widget build(BuildContext context) {
    final onMySpace = tab == 1;
    return DashboardScaffold(
      drawer: AppDrawer(
        name: connected ? username.text.trim() : dashboard.username,
        role: dashboard.roleText,
        connected: connected,
        onLogout: logout,
        applicationName: 'Immoizi',
      ),
      tab: tab,
      onTabChanged: (index) => setState(() => tab = index),
      listingsDestination: NavigationDestination(
        icon: const Icon(Icons.travel_explore_outlined),
        selectedIcon: const Icon(Icons.travel_explore),
        label: tr('Explorer'),
      ),
      unreadCount: dashboard.notifications.where((item) => !item.isRead).length,
      header: (collapsed) => sessionHeader(
        title: onMySpace ? tr('Mon espace') : 'Immoizi',
        subtitle: onMySpace
            ? tr('Suivi, paiements et actions locataires')
            : tr('Recherche & espace locataire'),
        icon: onMySpace ? Icons.person : Icons.real_estate_agent,
        collapsed: collapsed,
        search: onMySpace ? null : listingSearchBar(dashboard.publicProperties),
      ),
      onRefresh: load,
      lastSynced: lastSynced,
      loading: loading,
      error: error,
      children: onMySpace
          ? _mySpace()
          : [
              TenantDashboardView(
                dashboard,
                searchQuery: searchQuery,
                filters: filters,
                onRentalTypeChanged: setRentalType,
                endpoint: endpoint.text.trim(),
                token: token.text.trim(),
                onSubmitted: load,
              ),
            ],
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
        UnreadNotificationsBanner(
            notifications:
                dashboard.notifications.where((item) => !item.isRead).toList(),
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
}
