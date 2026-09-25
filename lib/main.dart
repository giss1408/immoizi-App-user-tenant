import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

class IvoryColors {
  static const Color orange = Color(0xFFFF8200);
  static const Color green = Color(0xFF009A44);
  static const Color background = Color(0xFFF0FAF3);
}

const _cacheKey = 'tenant_dashboard_cache_v1';
const _cacheTimeKey = 'tenant_dashboard_cache_time_v1';

void main() => runApp(const ImmoiziUserTenantApp());

class ImmoiziUserTenantApp extends StatelessWidget {
  const ImmoiziUserTenantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Immoizi',
      theme: AppTheme.theme(IvoryColors.orange, IvoryColors.background),
      home: const TenantHomePage(),
    );
  }
}

class TenantHomePage extends StatefulWidget {
  const TenantHomePage({super.key});

  @override
  State<TenantHomePage> createState() => _TenantHomePageState();
}

class _TenantHomePageState extends State<TenantHomePage> {
  final endpoint = TextEditingController(text: 'http://127.0.0.1:8000/graphql');
  final token = TextEditingController();
  final username = TextEditingController(text: 'tenant_demo');
  final password = TextEditingController(text: 'DemoPass123!');
  final propertySearch = TextEditingController();
  final client = GraphQLClient();
  TenantDashboard dashboard = TenantDashboard.demo();
  bool loading = false;
  bool loggingIn = false;
  bool connected = false;
  bool hasData = false;
  DateTime? lastSynced;
  String? error;
  Timer? notificationTimer;
  Timer? searchDebounce;
  String searchQuery = '';
  PropertyFilters filters = const PropertyFilters();

  @override
  void initState() {
    super.initState();
    _restoreCache();
    notificationTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (connected && !loading) load();
    });
  }

  @override
  void dispose() {
    endpoint.dispose();
    token.dispose();
    username.dispose();
    password.dispose();
    propertySearch.dispose();
    searchDebounce?.cancel();
    notificationTimer?.cancel();
    super.dispose();
  }

  Future<void> _restoreCache() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_cacheKey);
    final cachedAtMs = prefs.getInt(_cacheTimeKey);
    if (cached == null || !mounted) return;

    try {
      final data = jsonDecode(cached) as Map<String, dynamic>;
      setState(() {
        dashboard = TenantDashboard.fromJson(data);
        hasData = true;
        lastSynced = cachedAtMs != null
            ? DateTime.fromMillisecondsSinceEpoch(cachedAtMs)
            : null;
      });
    } catch (_) {
      // Corrupt or outdated cache format — ignore and keep the demo fallback.
    }
  }

  Future<void> _saveCache(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, jsonEncode(data));
    final now = DateTime.now();
    await prefs.setInt(_cacheTimeKey, now.millisecondsSinceEpoch);
    if (mounted) setState(() => lastSynced = now);
  }

  Future<void> login() async {
    setState(() {
      loggingIn = true;
      error = null;
    });

    try {
      final endpointValue = endpoint.text.trim();
      final newToken = await client.login(
          endpointValue, username.text.trim(), password.text.trim());
      token.text = newToken;
      await load();
    } catch (_) {
      setState(() => error =
          'Connexion échouée — vérifiez vos identifiants ou le backend.');
    } finally {
      if (mounted) {
        setState(() => loggingIn = false);
      }
    }
  }

  void logout() {
    token.clear();
    setState(() => connected = false);
    load();
  }

  Future<void> load({String? search}) async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final endpointValue = endpoint.text.trim();
      if (endpointValue.isEmpty) {
        throw Exception('Endpoint vide');
      }

      final activeSearch = (search ?? searchQuery).trim();
      final data = await client.query(
        endpointValue,
        token.text.trim(),
        tenantQuery,
        variables: {'search': activeSearch.isEmpty ? null : activeSearch},
      );
      setState(() {
        dashboard = TenantDashboard.fromJson(data);
        connected = token.text.trim().isNotEmpty;
        hasData = true;
      });
      await _saveCache(data);
    } catch (_) {
      setState(() {
        connected = false;
        if (!hasData) {
          dashboard = TenantDashboard.demo();
          error = 'Backend indisponible — mode démonstration activé';
        } else {
          error =
              'Synchronisation impossible — dernières données en cache affichées';
        }
      });
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  void _searchProperties(String value) {
    setState(() => searchQuery = value);
    searchDebounce?.cancel();
    if (token.text.trim().isEmpty) return;
    searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) load(search: value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: AppDrawer(
        name: connected ? username.text.trim() : dashboard.username,
        role: dashboard.roleText,
        connected: connected,
        onLogout: logout,
      ),
      bottomNavigationBar: AppBottomBar(
        connected: connected,
        loading: loading,
        onRefresh: load,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            children: [
              AppHeader(
                title: 'Immoizi',
                subtitle: 'Recherche & espace locataire',
                icon: Icons.real_estate_agent,
                connected: connected,
                connectedLabel: username.text.trim(),
                onOpenMore: _showMoreTools,
              ),
              const SizedBox(height: 14),
              PropertySearchBar(
                controller: propertySearch,
                onChanged: _searchProperties,
                activeFilterCount: filters.activeCount,
                onOpenFilters: _showFilters,
              ),
              const SizedBox(height: 12),
              CacheStatusBar(lastSynced: lastSynced, loading: loading),
              if (error != null) ...[
                const SizedBox(height: 12),
                ErrorCard(error!),
              ],
              const SizedBox(height: 18),
              TenantDashboardView(
                dashboard,
                searchQuery: searchQuery,
                filters: filters,
                endpoint: endpoint.text.trim(),
                token: token.text.trim(),
                onSubmitted: load,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMoreTools() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Mon espace',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              const Text('Suivi, paiements et actions locataires.',
                  style: TextStyle(color: Colors.black54)),
              const SizedBox(height: 14),
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
                    notification: dashboard.notifications
                        .firstWhere((item) => !item.isRead)),
              CategorySection(
                  title: 'Mes biens loués',
                  icon: Icons.key,
                  count: dashboard.tenantProperties.length,
                  children:
                      groupPropertiesByCategory(dashboard.tenantProperties)
                          .entries
                          .map((entry) => PropertyCategoryGroup(
                              category: entry.key,
                              properties: entry.value,
                              tag: 'Loué',
                              endpoint: endpoint.text.trim(),
                              token: token.text.trim()))
                          .toList()),
              CategorySection(
                  title: 'Paiements',
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
                        endpoint: endpoint.text.trim(),
                        token: token.text.trim(),
                        onSubmitted: load)
                  ]),
              CategorySection(
                  title: 'Notifications',
                  icon: Icons.notifications_none,
                  count: dashboard.notifications.length,
                  children: dashboard.notifications
                      .map(NotificationTile.new)
                      .toList()),
              CategorySection(
                  title: "Mes demandes d'intérêt",
                  icon: Icons.forum_outlined,
                  count: dashboard.interestRequests.length,
                  children: dashboard.interestRequests
                      .map((item) => InterestRequestTile(item,
                          endpoint: endpoint.text.trim(),
                          token: token.text.trim()))
                      .toList()),
            ],
          ),
        ),
      ),
    );
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
    if (result != null && mounted) setState(() => filters = result);
  }
}

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
        CategorySection(
          title: 'Biens disponibles',
          icon: Icons.home_work,
          count: availableProperties.length,
          initiallyExpanded: true,
          children: groupPropertiesByCategory(availableProperties)
              .entries
              .map((entry) => PropertyCategoryGroup(
                    category: entry.key,
                    properties: entry.value,
                    tag: 'Disponibilité',
                    endpoint: endpoint,
                    token: token,
                  ))
              .toList(),
        ),
      ],
    );
  }
}

Map<String, List<Property>> groupPropertiesByCategory(
    List<Property> properties) {
  final grouped = <String, List<Property>>{};
  for (final property in properties) {
    grouped.putIfAbsent(property.category, () => []).add(property);
  }
  return grouped;
}

class AppTheme {
  static ThemeData theme(Color seed, Color background) {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: seed),
      scaffoldBackgroundColor: background,
      cardTheme: const CardTheme(
          elevation: 0, color: Colors.white, margin: EdgeInsets.zero),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: IvoryColors.green,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: IvoryColors.orange,
          side: const BorderSide(color: IvoryColors.orange),
          minimumSize: const Size.fromHeight(48),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      useMaterial3: true,
    );
  }
}

class AppHeader extends StatelessWidget {
  const AppHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.connected = false,
    this.connectedLabel = '',
    this.onOpenMore,
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool connected;
  final String connectedLabel;
  final VoidCallback? onOpenMore;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 3))
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: IvoryColors.background,
                borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: IvoryColors.green),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w900)),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ])),
          ConnectionStatusPill(connected: connected, label: connectedLabel),
          if (onOpenMore != null)
            IconButton(
              onPressed: onOpenMore,
              icon: const Icon(Icons.more_horiz),
              tooltip: 'Mon espace',
            ),
        ],
      ),
    );
  }
}

class ConnectionStatusPill extends StatelessWidget {
  const ConnectionStatusPill(
      {required this.connected, required this.label, super.key});

  final bool connected;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: connected ? IvoryColors.green : Colors.black38,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            connected ? 'Connecté — $label' : 'Mode démonstration',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: connected ? IvoryColors.green : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}

class AppBottomBar extends StatelessWidget {
  const AppBottomBar({
    required this.connected,
    required this.loading,
    required this.onRefresh,
    super.key,
  });

  final bool connected;
  final bool loading;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      color: Colors.white,
      elevation: 8,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => Scaffold.of(context).openDrawer(),
            icon: const Icon(Icons.menu, color: IvoryColors.green),
            tooltip: 'Menu',
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: connected ? IvoryColors.green : Colors.black38,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                connected ? 'Connect\u00e9' : 'Mode d\u00e9mo',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.black54),
              ),
            ],
          ),
          IconButton(
            onPressed: loading ? null : onRefresh,
            icon: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh, color: IvoryColors.orange),
            tooltip: 'Synchroniser',
          ),
        ],
      ),
    );
  }
}

class AppDrawer extends StatelessWidget {
  const AppDrawer({
    required this.name,
    required this.role,
    required this.connected,
    required this.onLogout,
    super.key,
  });

  final String name;
  final String role;
  final bool connected;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [IvoryColors.green, Color(0xFF00733A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(
                    radius: 26,
                    backgroundColor: Colors.white24,
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  const SizedBox(height: 10),
                  Text(name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16)),
                  Text(role,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 8),
                  ConnectionStatusPill(connected: connected, label: name),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  ListTile(
                    leading: const Icon(Icons.home, color: IvoryColors.green),
                    title: const Text('Accueil'),
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const DrawerComingSoonTile(
                      icon: Icons.notifications_none, title: 'Notifications'),
                  const DrawerComingSoonTile(
                      icon: Icons.translate, title: 'Langue (FR / EN)'),
                  const DrawerComingSoonTile(
                      icon: Icons.support_agent, title: 'Aide & support'),
                  const DrawerComingSoonTile(
                      icon: Icons.privacy_tip_outlined,
                      title: 'Confidentialit\u00e9 & conditions'),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.info_outline,
                        color: IvoryColors.green),
                    title: const Text('\u00c0 propos'),
                    onTap: () {
                      Navigator.of(context).pop();
                      showAboutDialog(
                        context: context,
                        applicationName: 'Immoizi',
                        applicationVersion: '1.0.0',
                        applicationLegalese:
                            '\u00a9 Immoizi \u2014 C\u00f4te d\u2019Ivoire',
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.redAccent),
                    title: const Text('D\u00e9connexion'),
                    onTap: () {
                      Navigator.of(context).pop();
                      onLogout();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DrawerComingSoonTile extends StatelessWidget {
  const DrawerComingSoonTile(
      {required this.icon, required this.title, super.key});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      enabled: false,
      leading: Icon(icon, color: Colors.black26),
      title: Text(title, style: const TextStyle(color: Colors.black45)),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: IvoryColors.orange.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text('Bient\u00f4t',
            style: TextStyle(
                fontSize: 11,
                color: IvoryColors.orange,
                fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class PropertyFilters {
  const PropertyFilters(
      {this.location = '',
      this.priceRange = const RangeValues(0, 5000000),
      this.minRooms = 0,
      this.minSurface = 0,
      this.categories = const {}});

  final String location;
  final RangeValues priceRange;
  final int minRooms;
  final int minSurface;
  final Set<String> categories;

  int get activeCount =>
      (location.trim().isNotEmpty ? 1 : 0) +
      (priceRange.start > 0 ? 1 : 0) +
      (priceRange.end < 5000000 ? 1 : 0) +
      (minRooms > 0 ? 1 : 0) +
      (minSurface > 0 ? 1 : 0) +
      (categories.isNotEmpty ? 1 : 0);
  bool matches(Property property) {
    final query = location.trim().toLowerCase();
    return (query.isEmpty ||
            property.city.toLowerCase().contains(query) ||
            property.district.toLowerCase().contains(query)) &&
        property.price >= priceRange.start &&
        property.price <= priceRange.end &&
        property.rooms >= minRooms &&
        property.surface >= minSurface &&
        (categories.isEmpty || categories.contains(property.category));
  }
}

class PropertyFilterSheet extends StatefulWidget {
  const PropertyFilterSheet(
      {required this.initial, required this.categories, super.key});
  final PropertyFilters initial;
  final List<String> categories;
  @override
  State<PropertyFilterSheet> createState() => _PropertyFilterSheetState();
}

class _PropertyFilterSheetState extends State<PropertyFilterSheet> {
  late final TextEditingController locationController =
      TextEditingController(text: widget.initial.location);
  late RangeValues priceRange = widget.initial.priceRange;
  late int minRooms = widget.initial.minRooms;
  late int minSurface = widget.initial.minSurface;
  late Set<String> categories = {...widget.initial.categories};
  void reset() => setState(() {
        locationController.clear();
        priceRange = const RangeValues(0, 5000000);
        minRooms = 0;
        minSurface = 0;
        categories = {};
      });

  @override
  void dispose() {
    locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
      child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Filtres',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w900)),
              TextButton(onPressed: reset, child: const Text('Réinitialiser'))
            ]),
            const Text('Affinez les biens disponibles.',
                style: TextStyle(color: Colors.black54)),
            const SizedBox(height: 20),
            TextField(
                controller: locationController,
                decoration: const InputDecoration(
                    labelText: 'Localisation',
                    hintText: 'Ville ou quartier',
                    prefixIcon: Icon(Icons.location_on_outlined))),
            const SizedBox(height: 14),
            Text(
                'Budget mensuel: ${priceRange.start.round()} - ${priceRange.end.round()} FCFA',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            RangeSlider(
                values: priceRange,
                min: 0,
                max: 5000000,
                divisions: 100,
                activeColor: IvoryColors.orange,
                labels: RangeLabels(
                    '${priceRange.start.round()}', '${priceRange.end.round()}'),
                onChanged: (value) => setState(() => priceRange = value)),
            const SizedBox(height: 12),
            _FilterStepper(
                label: 'Pièces minimum',
                value: minRooms,
                onChanged: (value) => setState(() => minRooms = value)),
            _FilterStepper(
                label: 'Surface minimum',
                suffix: ' m²',
                value: minSurface,
                step: 10,
                onChanged: (value) => setState(() => minSurface = value)),
            if (widget.categories.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text('Types de biens',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.categories.map((category) {
                  return FilterChip(
                    label: Text(category),
                    selected: categories.contains(category),
                    selectedColor: IvoryColors.orange.withOpacity(.2),
                    onSelected: (selected) => setState(() {
                      if (selected) {
                        categories.add(category);
                      } else {
                        categories.remove(category);
                      }
                    }),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 22),
            SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                    onPressed: () => Navigator.pop(
                        context,
                        PropertyFilters(
                            location: locationController.text,
                            priceRange: priceRange,
                            minRooms: minRooms,
                            minSurface: minSurface,
                            categories: categories)),
                    icon: const Icon(Icons.check),
                    label: const Text('Appliquer les filtres'))),
          ])));
}

class _FilterStepper extends StatelessWidget {
  const _FilterStepper(
      {required this.label,
      required this.value,
      required this.onChanged,
      this.step = 1,
      this.suffix = ''});
  final String label, suffix;
  final int value, step;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(child: Text('$label: $value$suffix')),
        IconButton(
            onPressed: value > 0 ? () => onChanged(value - step) : null,
            icon: const Icon(Icons.remove_circle_outline)),
        Text('$value'),
        IconButton(
            onPressed: () => onChanged(value + step),
            icon: const Icon(Icons.add_circle_outline))
      ]);
}

class PropertySearchBar extends StatelessWidget {
  const PropertySearchBar(
      {required this.controller,
      required this.onChanged,
      required this.onOpenFilters,
      this.activeFilterCount = 0,
      super.key});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onOpenFilters;
  final int activeFilterCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            decoration: InputDecoration(
              hintText: 'Rechercher un bien...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: controller.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        controller.clear();
                        onChanged('');
                      },
                    ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(32),
                  borderSide: BorderSide.none),
            ),
          ),
        ),
        const SizedBox(width: 10),
        DecoratedBox(
          decoration: BoxDecoration(
              color: IvoryColors.orange,
              borderRadius: BorderRadius.circular(32)),
          child: IconButton(
              onPressed: onOpenFilters,
              icon: Badge(
                  isLabelVisible: activeFilterCount > 0,
                  label: Text('$activeFilterCount'),
                  child: const Icon(Icons.tune, color: Colors.white))),
        ),
      ],
    );
  }
}

class ConnectionCard extends StatefulWidget {
  const ConnectionCard({
    required this.endpoint,
    required this.token,
    required this.username,
    required this.password,
    required this.loading,
    required this.loggingIn,
    required this.connected,
    required this.onPressed,
    required this.onLogin,
    required this.onLogout,
    super.key,
  });

  final TextEditingController endpoint;
  final TextEditingController token;
  final TextEditingController username;
  final TextEditingController password;
  final bool loading;
  final bool loggingIn;
  final bool connected;
  final VoidCallback onPressed;
  final VoidCallback onLogin;
  final VoidCallback onLogout;

  @override
  State<ConnectionCard> createState() => _ConnectionCardState();
}

class _ConnectionCardState extends State<ConnectionCard> {
  late bool expanded = !widget.connected;

  @override
  void didUpdateWidget(covariant ConnectionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.connected != oldWidget.connected) {
      expanded = !widget.connected;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => expanded = !expanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    widget.connected
                        ? Icons.check_circle
                        : Icons.wifi_tethering,
                    color: widget.connected
                        ? IvoryColors.green
                        : IvoryColors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.connected
                          ? 'Connect\u00e9 en tant que ${widget.username.text.trim()}'
                          : 'Connexion au backend',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: widget.connected
                            ? IvoryColors.green
                            : Colors.black87,
                      ),
                    ),
                  ),
                  if (widget.connected)
                    TextButton.icon(
                      onPressed: widget.onLogout,
                      icon: const Icon(Icons.logout, size: 16),
                      label: const Text('D\u00e9connexion'),
                    ),
                  Icon(expanded ? Icons.expand_less : Icons.expand_more,
                      color: Colors.black45),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 14),
                  TextField(
                    controller: widget.endpoint,
                    decoration: const InputDecoration(
                      labelText: 'Endpoint GraphQL',
                      prefixIcon: Icon(Icons.link),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: widget.username,
                          decoration: const InputDecoration(
                            labelText: 'Identifiant',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: widget.password,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Mot de passe',
                            prefixIcon: Icon(Icons.lock_outline),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: widget.loggingIn ? null : widget.onLogin,
                    icon: widget.loggingIn
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.login),
                    label: Text(widget.loggingIn
                        ? 'Connexion...'
                        : (widget.connected
                            ? 'Se reconnecter'
                            : 'Se connecter')),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: widget.token,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Token API',
                      prefixIcon: Icon(Icons.lock),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: widget.loading ? null : widget.onPressed,
                    icon: widget.loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    label:
                        Text(widget.loading ? 'Chargement...' : 'Synchroniser'),
                  ),
                ],
              ),
            ),
        ],
      ),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon,
                size: 18, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 18)),
                Text(label,
                    style:
                        const TextStyle(fontSize: 11, color: Colors.black54)),
              ],
            ),
          ),
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

class CategorySection extends StatelessWidget {
  const CategorySection({
    required this.title,
    required this.icon,
    required this.count,
    required this.children,
    this.initiallyExpanded = false,
    super.key,
  });

  final String title;
  final IconData icon;
  final int count;
  final List<Widget> children;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: initiallyExpanded,
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Theme.of(context).colorScheme.primary),
            ),
            title: Text(title,
                style:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Chip(
                    label: Text('$count'),
                    visualDensity: VisualDensity.compact),
                const Icon(Icons.expand_more),
              ],
            ),
            childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            children: [
              if (children.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: MutedText('Aucune donnée disponible.'),
                )
              else
                ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class PropertyCategoryGroup extends StatelessWidget {
  const PropertyCategoryGroup({
    required this.category,
    required this.properties,
    required this.tag,
    required this.endpoint,
    required this.token,
    super.key,
  });

  final String category;
  final List<Property> properties;
  final String tag;
  final String endpoint;
  final String token;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          initiallyExpanded: true,
          title: Row(
            children: [
              Icon(Icons.label,
                  size: 16, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 6),
              Text(category,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(width: 8),
              Chip(
                  label: Text('${properties.length}'),
                  visualDensity: VisualDensity.compact),
            ],
          ),
          children: properties
              .map((item) => PropertyCard(item,
                  tag: tag, endpoint: endpoint, token: token))
              .toList(),
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
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
              builder: (_) => PropertyDetailPage(
                  property: property,
                  tag: tag,
                  endpoint: endpoint,
                  token: token)),
        ),
        child: Column(
          children: [
            if (property.mainImageUrl != null)
              Image.network(
                property.mainImageUrl!,
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const _PropertyImageFallback(),
              )
            else
              const _PropertyImageFallback(),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFF0E0), Color(0xFFFFD9B3)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child:
                        const Icon(Icons.apartment, color: IvoryColors.orange),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(property.title,
                            style:
                                const TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text('${property.city} \u2022 ${property.district}',
                            style: const TextStyle(color: Colors.black54)),
                        const SizedBox(height: 4),
                        Text(
                            '${property.rooms} pi\u00e8ces \u2022 ${property.surface} m\u00b2',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.black54)),
                        if (property.isTestData) ...[
                          const SizedBox(height: 6),
                          const TestDataBadge(),
                        ],
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${property.price} FCFA',
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Chip(
                          label: Text(tag),
                          visualDensity: VisualDensity.compact,
                          backgroundColor:
                              IvoryColors.orange.withOpacity(0.15)),
                      const SizedBox(height: 6),
                      const Icon(Icons.arrow_forward_ios,
                          size: 14, color: Colors.black45),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PropertyImageFallback extends StatelessWidget {
  const _PropertyImageFallback();

  @override
  Widget build(BuildContext context) => Container(
        height: 150,
        color: const Color(0xFFFFF0E0),
        child: const Center(
            child: Icon(Icons.apartment, size: 48, color: IvoryColors.orange)),
      );
}

class PropertyDetailPage extends StatelessWidget {
  const PropertyDetailPage(
      {required this.property,
      required this.tag,
      required this.endpoint,
      required this.token,
      super.key});

  final Property property;
  final String tag;
  final String endpoint;
  final String token;

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
                  property: property, endpoint: endpoint, token: token),
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
      super.key});

  final Property property;
  final String endpoint;
  final String token;

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
        FilledButton.icon(
          onPressed: property.id == null || token.isEmpty
              ? null
              : () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => InterestRequestPage(
                          property: property, endpoint: endpoint, token: token),
                    ),
                  ),
          icon: const Icon(Icons.mark_email_unread),
          label: const Text('Je suis intéressé par ce bien'),
        ),
      ],
    );
  }
}

class InterestRequestPage extends StatefulWidget {
  const InterestRequestPage(
      {required this.property,
      required this.endpoint,
      required this.token,
      super.key});

  final Property property;
  final String endpoint;
  final String token;

  @override
  State<InterestRequestPage> createState() => _InterestRequestPageState();
}

class _InterestRequestPageState extends State<InterestRequestPage> {
  final employerController = TextEditingController();
  final messageController = TextEditingController();
  String profession = 'Employé du secteur privé';
  String salaryRange = '300 000 - 500 000 FCFA';
  int occupants = 1;
  DateTime? startDate;
  bool sending = false;
  String? error;

  static const professions = [
    'Employé du secteur privé',
    'Fonctionnaire',
    'Entrepreneur',
    'Indépendant / Freelance',
    'Étudiant',
    'Retraité',
    'Autre',
  ];

  static const salaries = [
    'Moins de 200 000 FCFA',
    '200 000 - 300 000 FCFA',
    '300 000 - 500 000 FCFA',
    '500 000 - 750 000 FCFA',
    'Plus de 750 000 FCFA',
  ];

  @override
  void dispose() {
    employerController.dispose();
    messageController.dispose();
    super.dispose();
  }

  Future<void> _chooseDate() async {
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      initialDate: startDate ?? DateTime.now(),
    );
    if (selected != null) setState(() => startDate = selected);
  }

  Future<void> _send() async {
    if (startDate == null || messageController.text.trim().isEmpty) {
      setState(() =>
          error = 'Choisissez une date et ajoutez un message de présentation.');
      return;
    }
    setState(() {
      sending = true;
      error = null;
    });
    try {
      await GraphQLClient().query(
        widget.endpoint,
        widget.token,
        createInterestRequestMutation,
        variables: {
          'propertyId': widget.property.id,
          'profession': profession,
          'salaryRange': salaryRange,
          'employer': employerController.text.trim(),
          'occupantsCount': occupants,
          'leaseStartDate': _dateValue(startDate!),
          'message': messageController.text.trim(),
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Votre demande a été envoyée au bailleur.')));
        Navigator.of(context).pop();
      }
    } catch (exception) {
      setState(() => error = 'Envoi impossible : $exception');
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Je suis intéressé')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(widget.property.title,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: profession,
            decoration: const InputDecoration(labelText: 'Profession'),
            items: professions
                .map((value) =>
                    DropdownMenuItem(value: value, child: Text(value)))
                .toList(),
            onChanged: (value) =>
                setState(() => profession = value ?? profession),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: salaryRange,
            decoration: const InputDecoration(labelText: 'Tranche de salaire'),
            items: salaries
                .map((value) =>
                    DropdownMenuItem(value: value, child: Text(value)))
                .toList(),
            onChanged: (value) =>
                setState(() => salaryRange = value ?? salaryRange),
          ),
          const SizedBox(height: 12),
          TextField(
              controller: employerController,
              decoration: const InputDecoration(labelText: 'Employeur')),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: occupants,
            decoration:
                const InputDecoration(labelText: 'Nombre de personnes à loger'),
            items: List.generate(
                8,
                (index) => DropdownMenuItem(
                    value: index + 1,
                    child:
                        Text('${index + 1} personne${index == 0 ? '' : 's'}'))),
            onChanged: (value) =>
                setState(() => occupants = value ?? occupants),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _chooseDate,
            icon: const Icon(Icons.event),
            label: Text(startDate == null
                ? 'Date de début souhaitée'
                : 'Début souhaité : ${_dateValue(startDate!)}'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: messageController,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Message au bailleur',
              hintText:
                  'Présentez votre projet et ajoutez toute information utile.',
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: sending ? null : _send,
            icon: sending
                ? const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator())
                : const Icon(Icons.send),
            label: Text(sending ? 'Envoi...' : 'Envoyer ma demande'),
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            ErrorCard(error!),
          ],
        ],
      ),
    );
  }
}

String _dateValue(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

class VideoCard extends StatelessWidget {
  const VideoCard({required this.videoUrl, required this.title, super.key});

  final String videoUrl;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
              builder: (_) =>
                  VideoPlayerPage(videoUrl: videoUrl, title: title)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: IvoryColors.green.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.play_circle_fill,
                    color: IvoryColors.green, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Vidéo de présentation',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      style:
                          const TextStyle(fontSize: 12, color: Colors.black54),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios,
                  size: 14, color: Colors.black45),
            ],
          ),
        ),
      ),
    );
  }
}

class VideoPlayerPage extends StatefulWidget {
  const VideoPlayerPage(
      {required this.videoUrl, required this.title, super.key});

  final String videoUrl;
  final String title;

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

String _videoUrlForPlayback(String rawUrl) {
  final trimmed = rawUrl.trim();
  if (trimmed.isEmpty) return '';

  final lower = trimmed.toLowerCase();
  if (lower.contains('w3schools.com') ||
      lower.contains('example.com') ||
      lower.contains('commondatastorage.googleapis.com')) {
    return 'https://media.w3.org/2010/05/sintel/trailer.mp4';
  }

  return trimmed;
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  late final VideoPlayerController controller;
  bool initialized = false;
  String? error;

  @override
  void initState() {
    super.initState();
    final resolvedUrl = _videoUrlForPlayback(widget.videoUrl);
    final uri = Uri.tryParse(resolvedUrl);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      setState(() => error = 'URL vidéo invalide.');
      return;
    }

    controller = VideoPlayerController.networkUrl(uri);
    controller.initialize().then((_) {
      if (!mounted) return;
      setState(() => initialized = true);
      controller.play();
    }).catchError((_) {
      if (mounted) setState(() => error = 'Impossible de lire la vidéo.');
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.title),
      ),
      body: Center(
        child: error != null
            ? Text(error!, style: const TextStyle(color: Colors.white70))
            : initialized
                ? AspectRatio(
                    aspectRatio: controller.value.aspectRatio,
                    child: VideoPlayer(controller),
                  )
                : const CircularProgressIndicator(color: Colors.white),
      ),
      floatingActionButton: initialized
          ? FloatingActionButton(
              backgroundColor: IvoryColors.green,
              onPressed: () => setState(() {
                controller.value.isPlaying
                    ? controller.pause()
                    : controller.play();
              }),
              child: Icon(
                  controller.value.isPlaying ? Icons.pause : Icons.play_arrow),
            )
          : null,
    );
  }
}

class DetailChip extends StatelessWidget {
  const DetailChip({required this.icon, required this.label, super.key});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 4),
          Text(label,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class MediaPlaceholder extends StatelessWidget {
  const MediaPlaceholder({required this.icon, super.key});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF3EDE4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(icon, size: 32, color: Colors.black26),
    );
  }
}

class ImageViewerPage extends StatefulWidget {
  const ImageViewerPage(
      {required this.images, required this.initialIndex, super.key});

  final List<String> images;
  final int initialIndex;

  @override
  State<ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<ImageViewerPage> {
  late final PageController controller =
      PageController(initialPage: widget.initialIndex);
  late int currentIndex = widget.initialIndex;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${currentIndex + 1} / ${widget.images.length}'),
      ),
      body: PageView.builder(
        controller: controller,
        itemCount: widget.images.length,
        onPageChanged: (index) => setState(() => currentIndex = index),
        itemBuilder: (context, index) => InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          child: Center(
            child: Image.network(
              widget.images[index],
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.broken_image,
                  color: Colors.white54,
                  size: 64),
            ),
          ),
        ),
      ),
    );
  }
}

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

class InfoTile extends StatelessWidget {
  const InfoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? trailing;

  @override
  Widget build(BuildContext context) => Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: ListTile(
          leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: trailing == null ? null : Text(trailing!),
        ),
      );
}

class EmptyState extends StatelessWidget {
  const EmptyState({required this.message, super.key});
  final String message;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Text(message),
        ),
      );
}

class ErrorCard extends StatelessWidget {
  const ErrorCard(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) => Card(
        color: const Color(0xFFFFF1E8),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child:
              Text(message, style: const TextStyle(color: Color(0xFF9A3D16))),
        ),
      );
}

class CacheStatusBar extends StatelessWidget {
  const CacheStatusBar(
      {required this.lastSynced, required this.loading, super.key});

  final DateTime? lastSynced;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final label = loading
        ? 'Synchronisation en cours...'
        : lastSynced == null
            ? 'Aucune donn\u00e9e en cache \u2014 tirez vers le bas pour synchroniser'
            : 'Donn\u00e9es en cache \u2014 derni\u00e8re mise \u00e0 jour ${_formatTimestamp(lastSynced!)}';

    return Row(
      children: [
        Icon(loading ? Icons.sync : Icons.cached,
            size: 14, color: Colors.black45),
        const SizedBox(width: 6),
        Expanded(
          child: Text(label,
              style: const TextStyle(fontSize: 11, color: Colors.black45)),
        ),
      ],
    );
  }
}

class CreateMaintenanceCard extends StatelessWidget {
  const CreateMaintenanceCard(
      {required this.properties,
      required this.endpoint,
      required this.token,
      required this.onSubmitted,
      super.key});

  final List<Property> properties;
  final String endpoint;
  final String token;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: IvoryColors.green.withOpacity(0.08),
      child: ListTile(
        leading: const Icon(Icons.add_task, color: IvoryColors.green),
        title: const Text('Signaler un problème'),
        subtitle: const Text('Créer une demande de maintenance'),
        onTap:
            token.isEmpty || properties.every((property) => property.id == null)
                ? null
                : () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CreateMaintenancePage(
                          properties: properties,
                          endpoint: endpoint,
                          token: token,
                          onSubmitted: onSubmitted,
                        ),
                      ),
                    ),
      ),
    );
  }
}

class CreateMaintenancePage extends StatefulWidget {
  const CreateMaintenancePage(
      {required this.properties,
      required this.endpoint,
      required this.token,
      required this.onSubmitted,
      super.key});

  final List<Property> properties;
  final String endpoint;
  final String token;
  final VoidCallback onSubmitted;

  @override
  State<CreateMaintenancePage> createState() => _CreateMaintenancePageState();
}

class _CreateMaintenancePageState extends State<CreateMaintenancePage> {
  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  String? propertyId;
  String priority = 'normal';
  bool saving = false;
  String? error;

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (propertyId == null ||
        titleController.text.trim().isEmpty ||
        descriptionController.text.trim().isEmpty) {
      setState(() => error =
          'Choisissez un bien et renseignez le sujet et la description.');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await GraphQLClient().query(
        widget.endpoint,
        widget.token,
        createMaintenanceMutation,
        variables: {
          'propertyId': propertyId,
          'title': titleController.text.trim(),
          'description': descriptionController.text.trim(),
          'priority': priority,
        },
      );
      widget.onSubmitted();
      if (mounted) Navigator.of(context).pop();
    } catch (exception) {
      setState(() => error = 'Envoi impossible : $exception');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Signaler un problème')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          DropdownButtonFormField<String>(
            value: propertyId,
            decoration: const InputDecoration(labelText: 'Bien concerné'),
            items: widget.properties
                .where((property) => property.id != null)
                .map((property) => DropdownMenuItem(
                    value: property.id, child: Text(property.title)))
                .toList(),
            onChanged: (value) => setState(() => propertyId = value),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: titleController,
            decoration: const InputDecoration(
                labelText: 'Sujet du problème',
                hintText: 'Ex. Fuite sous évier'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: descriptionController,
            maxLines: 6,
            decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Décrivez le problème et sa localisation'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: priority,
            decoration: const InputDecoration(labelText: 'Priorité'),
            items: const [
              DropdownMenuItem(value: 'low', child: Text('Faible')),
              DropdownMenuItem(value: 'normal', child: Text('Normale')),
              DropdownMenuItem(value: 'high', child: Text('Haute')),
              DropdownMenuItem(value: 'urgent', child: Text('Urgente')),
            ],
            onChanged: (value) => setState(() => priority = value ?? priority),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: saving ? null : _submit,
            icon: saving
                ? const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator())
                : const Icon(Icons.send),
            label: Text(saving ? 'Envoi...' : 'Envoyer la demande'),
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            ErrorCard(error!),
          ],
        ],
      ),
    );
  }
}

String _formatTimestamp(DateTime dt) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(dt.day)}/${two(dt.month)} \u00e0 ${two(dt.hour)}:${two(dt.minute)}';
}

class MutedText extends StatelessWidget {
  const MutedText(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: const TextStyle(color: Colors.black54));
}

class TestDataBadge extends StatelessWidget {
  const TestDataBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3CD),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0A800)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.science, size: 12, color: Color(0xFF8A6D00)),
          SizedBox(width: 4),
          Text('Donnée de test',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF8A6D00))),
        ],
      ),
    );
  }
}

class GraphQLClient {
  Future<Map<String, dynamic>> query(
    String endpoint,
    String token,
    String query, {
    Map<String, dynamic> variables = const {},
  }) async {
    final response = await http.post(
      Uri.parse(endpoint),
      headers: {
        'Content-Type': 'application/json',
        'Accept-Language': 'fr',
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'query': query, 'variables': variables}),
    );

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        payload['errors'] != null) {
      throw Exception(payload['errors'] ?? 'HTTP ${response.statusCode}');
    }

    return payload['data'] as Map<String, dynamic>;
  }

  Future<String> login(
      String endpoint, String username, String password) async {
    final data = await query(
      endpoint,
      '',
      loginMutation,
      variables: {'username': username, 'password': password},
    );
    return data['tokenAuth']['token'] as String;
  }
}

const loginMutation = r'''
mutation Login($username: String!, $password: String!) {
  tokenAuth(username: $username, password: $password) { token }
}
''';

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

  factory TenantDashboard.fromJson(Map<String, dynamic> json) {
    final me = json['me'] as Map<String, dynamic>? ?? {};
    final roles = [
      if (me['isSeeker'] == true) 'Recherche',
      if (me['isTenant'] == true) 'Locataire',
    ];

    return TenantDashboard(
      me['username'] as String? ?? 'Utilisateur',
      roles.isEmpty ? 'Utilisateur' : roles.join(' • '),
      _items(json['publicDescriptions']).map(Property.fromJson).toList(),
      _items(json['myTenantProperties']).map(Property.fromJson).toList(),
      _items(json['myTenantPayments']).map(Payment.fromJson).toList(),
      _items(json['myTenantDocuments']).map(DocumentItem.fromJson).toList(),
      _items(json['myTenantMaintenanceRequests'])
          .map(Maintenance.fromJson)
          .toList(),
      _items(json['myPropertyInterestRequests'])
          .map(InterestRequestItem.fromJson)
          .toList(),
      _items(json['notifications']).map(NotificationItem.fromJson).toList(),
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

class Property {
  Property(
    this.title,
    this.category,
    this.city,
    this.district,
    this.rooms,
    this.surface,
    this.price, {
    this.id,
    this.isTestData = false,
    this.description = '',
    this.mainImageUrl,
    this.galleryImageUrls = const [],
    this.hasVideo = false,
    this.videoUrl,
  });

  final String title;
  final String category;
  final String city;
  final String district;
  final int rooms;
  final int surface;
  final int price;
  final String? id;
  final bool isTestData;
  final String description;
  final String? mainImageUrl;
  final List<String> galleryImageUrls;
  final bool hasVideo;
  final String? videoUrl;

  factory Property.fromJson(Map<String, dynamic> json) => Property(
        json['title'] as String? ?? '-',
        (json['category'] as Map<String, dynamic>?)?['title'] as String? ??
            'Autres',
        json['city'] as String? ?? '-',
        json['district'] as String? ?? '-',
        _int(json['rooms']),
        _int(json['surfaceM2']),
        _int(json['price']),
        id: json['id'] as String?,
        isTestData: json['isTestData'] as bool? ?? false,
        description: json['description'] as String? ?? '',
        mainImageUrl: json['mainImageUrl'] as String?,
        galleryImageUrls:
            (json['galleryImageUrls'] as List<dynamic>? ?? const [])
                .cast<String>(),
        hasVideo: json['hasVideo'] as bool? ?? false,
        videoUrl: json['videoUrl'] as String?,
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
      this.id, this.title, this.message, this.propertyTitle, this.isRead);

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
        _nestedTitle(json['property']),
        json['isRead'] as bool? ?? false,
      );
}

class TenantUnreadNotificationBanner extends StatelessWidget {
  const TenantUnreadNotificationBanner({required this.notification, super.key});

  final NotificationItem notification;

  @override
  Widget build(BuildContext context) => Card(
        color: const Color(0xFFFFF4E5),
        child: ListTile(
          leading:
              const Icon(Icons.mark_email_unread, color: IvoryColors.orange),
          title: Text(notification.title,
              style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(
              '${notification.message}\n${notification.propertyTitle}',
              maxLines: 3,
              overflow: TextOverflow.ellipsis),
          isThreeLine: true,
        ),
      );
}

class NotificationTile extends StatelessWidget {
  const NotificationTile(this.notification, {super.key});

  final NotificationItem notification;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: Icon(
              notification.isRead
                  ? Icons.notifications_none
                  : Icons.notifications_active,
              color: notification.isRead ? Colors.grey : IvoryColors.orange),
          title: Text(notification.title,
              style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(
              '${notification.message}\n${notification.propertyTitle}',
              maxLines: 3,
              overflow: TextOverflow.ellipsis),
          isThreeLine: true,
        ),
      );
}

class InterestRequestItem {
  InterestRequestItem(this.id, this.propertyTitle, this.status);

  final String id;
  final String propertyTitle;
  final String status;

  factory InterestRequestItem.fromJson(Map<String, dynamic> json) =>
      InterestRequestItem(
        json['id'] as String? ?? '',
        _nestedTitle(json['property']),
        _interestStatus(json['status']),
      );
}

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
                    interestRequestId: request.id,
                    propertyTitle: request.propertyTitle,
                    endpoint: endpoint,
                    token: token,
                  ))),
        ),
      );
}

class InterestChatPage extends StatefulWidget {
  const InterestChatPage(
      {required this.interestRequestId,
      required this.propertyTitle,
      required this.endpoint,
      required this.token,
      super.key});

  final String interestRequestId;
  final String propertyTitle;
  final String endpoint;
  final String token;

  @override
  State<InterestChatPage> createState() => _InterestChatPageState();
}

class _InterestChatPageState extends State<InterestChatPage> {
  final messageController = TextEditingController();
  List<InterestMessageItem> messages = [];
  String messageType = 'message';
  bool loading = true;
  bool sending = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void dispose() {
    messageController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    try {
      final data = await GraphQLClient().query(
          widget.endpoint, widget.token, interestMessagesQuery,
          variables: {'interestRequestId': widget.interestRequestId});
      if (mounted) {
        setState(() => messages = _items(data['propertyInterestMessages'])
            .map(InterestMessageItem.fromJson)
            .toList());
      }
    } catch (exception) {
      if (mounted) setState(() => error = 'Chargement impossible : $exception');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _send() async {
    if (messageController.text.trim().isEmpty) return;
    setState(() {
      sending = true;
      error = null;
    });
    try {
      await GraphQLClient().query(
          widget.endpoint, widget.token, sendInterestMessageMutation,
          variables: {
            'interestRequestId': widget.interestRequestId,
            'message': messageController.text.trim(),
            'messageType': messageType,
          });
      messageController.clear();
      await _loadMessages();
    } catch (exception) {
      if (mounted) setState(() => error = 'Envoi impossible : $exception');
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.propertyTitle)),
        body: Column(
          children: [
            if (error != null)
              Padding(
                  padding: const EdgeInsets.all(12),
                  child:
                      Text(error!, style: const TextStyle(color: Colors.red))),
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : messages.isEmpty
                      ? const Center(child: Text('Aucun message.'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: messages.length,
                          itemBuilder: (_, index) =>
                              _MessageBubble(message: messages[index])),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              color: Colors.white,
              child: Row(children: [
                Expanded(
                    child: Column(children: [
                  DropdownButtonFormField<String>(
                      value: messageType,
                      decoration: const InputDecoration(labelText: 'Réponse'),
                      items: const [
                        DropdownMenuItem(
                            value: 'message', child: Text('Message')),
                        DropdownMenuItem(
                            value: 'visit_confirmation',
                            child: Text('Confirmer la visite')),
                        DropdownMenuItem(
                            value: 'visit_declined',
                            child: Text('Refuser la visite')),
                      ],
                      onChanged: (value) =>
                          setState(() => messageType = value ?? 'message')),
                  const SizedBox(height: 8),
                  TextField(
                      controller: messageController,
                      maxLines: 3,
                      decoration:
                          const InputDecoration(hintText: 'Votre réponse')),
                ])),
                const SizedBox(width: 8),
                IconButton(
                    onPressed: sending ? null : _send,
                    icon: sending
                        ? const CircularProgressIndicator()
                        : const Icon(Icons.send),
                    color: IvoryColors.green,
                    tooltip: 'Envoyer'),
              ]),
            ),
          ],
        ),
      );
}

class InterestMessageItem {
  InterestMessageItem(this.message, this.messageType, this.proposedVisitAt,
      this.senderUsername);

  final String message;
  final String messageType;
  final String? proposedVisitAt;
  final String senderUsername;

  factory InterestMessageItem.fromJson(Map<String, dynamic> json) =>
      InterestMessageItem(
        json['message'] as String? ?? '',
        json['messageType'] as String? ?? 'message',
        json['proposedVisitAt'] as String?,
        (json['sender'] as Map<String, dynamic>?)?['username'] as String? ??
            'Utilisateur',
      );
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});
  final InterestMessageItem message;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message.senderUsername,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(message.message),
              if (message.proposedVisitAt != null)
                Text('Visite proposée : ${message.proposedVisitAt}'),
            ],
          ),
        ),
      ),
    );
  }
}

List<Map<String, dynamic>> _items(Object? value) =>
    (value as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
int _int(Object? value) =>
    value is int ? value : int.tryParse('${value ?? ''}') ?? 0;
String _nestedTitle(Object? value) =>
    (value as Map<String, dynamic>?)?['title'] as String? ?? '-';
String _interestStatus(Object? value) =>
    const {
      'PENDING': 'En attente',
      'REVIEWING': 'En cours d’examen',
      'ACCEPTED': 'Acceptée',
      'REJECTED': 'Refusée',
    }['${value ?? ''}'] ??
    '${value ?? '-'}';

const tenantQuery = r'''
query TenantDashboard($search: String) {
  me { username isSeeker isTenant }
  publicDescriptions(first: 10, search: $search) { id title city district rooms surfaceM2 price category { title } isTestData description mainImageUrl galleryImageUrls hasVideo videoUrl }
  myTenantProperties { id title city district rooms surfaceM2 price category { title } isTestData description mainImageUrl galleryImageUrls hasVideo videoUrl }
  myTenantPayments { amount status dueDate }
  myTenantDocuments { title documentType }
  myTenantMaintenanceRequests { title priority status }
  myPropertyInterestRequests { id property { title } status }
  notifications { id title message isRead property { title } }
}
''';

const interestMessagesQuery = r'''
query InterestMessages($interestRequestId: ID!) {
  propertyInterestMessages(interestRequestId: $interestRequestId) {
    id message messageType proposedVisitAt createdAt sender { username }
  }
}
''';

const sendInterestMessageMutation = r'''
mutation SendInterestMessage($interestRequestId: ID!, $message: String!, $messageType: String, $proposedVisitAt: DateTime) {
  sendPropertyInterestMessage(interestRequestId: $interestRequestId, message: $message, messageType: $messageType, proposedVisitAt: $proposedVisitAt) {
    interestMessage { id message messageType proposedVisitAt createdAt }
  }
}
''';

const createMaintenanceMutation = r'''
mutation CreateMaintenance($propertyId: ID!, $title: String!, $description: String!, $priority: String) {
  createMaintenanceRequest(propertyId: $propertyId, title: $title, description: $description, priority: $priority) {
    maintenanceRequest { id title description priority status }
  }
}
''';

const createInterestRequestMutation = r'''
mutation CreateInterestRequest($propertyId: ID!, $profession: String!, $salaryRange: String!, $employer: String, $occupantsCount: Int!, $leaseStartDate: Date!, $message: String) {
  createPropertyInterestRequest(propertyId: $propertyId, profession: $profession, salaryRange: $salaryRange, employer: $employer, occupantsCount: $occupantsCount, leaseStartDate: $leaseStartDate, message: $message) {
    interestRequest { id status }
  }
}
''';
