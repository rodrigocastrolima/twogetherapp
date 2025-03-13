import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../screens/admin/tasks_page.dart';
import '../screens/admin/admin_dashboard_page.dart';
import '../screens/admin/reseller_management_page.dart';
import '../screens/admin/clients_page.dart';
import '../screens/admin/submissions_page.dart';
import '../screens/admin/reports_page.dart';
import '../screens/admin/settings_page.dart';
import '../../core/theme/colors.dart';

class AdminLayout extends StatefulWidget {
  const AdminLayout({super.key});

  @override
  State<AdminLayout> createState() => _AdminLayoutState();
}

class _AdminLayoutState extends State<AdminLayout> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final width = MediaQuery.of(context).size.width;
    final isSmallScreen = width < 600;

    final List<Widget> _pages = [
      const TasksPage(),
      const AdminDashboardPage(),
      const ResellerManagementPage(),
      const ClientsPage(),
      const SubmissionsPage(),
      const ReportsPage(),
      const SettingsPage(),
    ];

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: width >= 800,
            backgroundColor: theme.colorScheme.surface,
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Image.asset(
                'assets/images/twogether_logo_light_br.png',
                height: 48,
              ),
            ),
            destinations: [
              NavigationRailDestination(
                icon: const Icon(Icons.task_outlined),
                selectedIcon: const Icon(Icons.task),
                label: Text(l10n.adminTasks),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.dashboard_outlined),
                selectedIcon: const Icon(Icons.dashboard),
                label: Text(l10n.adminDashboard),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.business_outlined),
                selectedIcon: const Icon(Icons.business),
                label: Text(l10n.adminResellers),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.people_outlined),
                selectedIcon: const Icon(Icons.people),
                label: Text(l10n.adminClients),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.description_outlined),
                selectedIcon: const Icon(Icons.description),
                label: Text(l10n.adminSubmissions),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.analytics_outlined),
                selectedIcon: const Icon(Icons.analytics),
                label: Text(l10n.adminReports),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.settings_outlined),
                selectedIcon: const Icon(Icons.settings),
                label: Text(l10n.adminSettings),
              ),
            ],
          ),
          Expanded(
            child: Column(
              children: [
                if (isSmallScreen)
                  AppBar(
                    title: Image.asset(
                      'assets/images/twogether_logo_light_br.png',
                      height: 32,
                    ),
                    centerTitle: true,
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.logout),
                        onPressed: () {
                          // TODO: Implement logout
                        },
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                Expanded(child: _pages[_selectedIndex]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
