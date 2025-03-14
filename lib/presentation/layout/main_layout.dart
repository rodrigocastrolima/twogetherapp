import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../core/theme/text_styles.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/base_layout.dart';
import '../screens/home/reseller_home_page.dart';
import '../screens/services/services_page.dart';
import '../screens/clients/clients_page.dart';
import '../screens/messages/messages_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const ResellerHomePage(),
    const ClientsPage(),
    const MessagesPage(),
    const ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final width = MediaQuery.of(context).size.width;
    final isSmallScreen = width < 600;

    return Scaffold(
      body: BaseLayout(
        child: Row(
          children: [
            if (!isSmallScreen)
              NavigationRail(
                extended: width >= 800,
                backgroundColor: AppTheme.background.withOpacity(0.8),
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
                  _buildRailDestination(
                    icon: Icons.home_outlined,
                    selectedIcon: Icons.home,
                    label: 'Início',
                    isSelected: _selectedIndex == 0,
                  ),
                  _buildRailDestination(
                    icon: Icons.people_outline,
                    selectedIcon: Icons.people,
                    label: 'Clientes',
                    isSelected: _selectedIndex == 1,
                  ),
                  _buildRailDestination(
                    icon: Icons.message_outlined,
                    selectedIcon: Icons.message,
                    label: 'Mensagens',
                    isSelected: _selectedIndex == 2,
                  ),
                  _buildRailDestination(
                    icon: Icons.person_outline,
                    selectedIcon: Icons.person,
                    label: 'Perfil',
                    isSelected: _selectedIndex == 3,
                  ),
                ],
              ),
            Expanded(
              child: Column(
                children: [
                  if (isSmallScreen)
                    AppBar(
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      title: Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Image.asset(
                          'assets/images/twogether_logo_light_br.png',
                          height: 32,
                        ),
                      ),
                      centerTitle: true,
                      actions: [
                        Padding(
                          padding: const EdgeInsets.only(top: 16, right: 8),
                          child: IconButton(
                            icon: Icon(
                              Icons.notifications_outlined,
                              color: AppTheme.foreground,
                            ),
                            onPressed: () {
                              // TODO: Implement notifications
                            },
                          ),
                        ),
                      ],
                    ),
                  Expanded(
                    child: Container(
                      color: Colors.transparent,
                      child: _pages[_selectedIndex],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar:
          isSmallScreen
              ? Container(
                decoration: BoxDecoration(
                  color: AppTheme.background.withOpacity(0.8),
                  border: Border(
                    top: BorderSide(color: AppTheme.border, width: 1),
                  ),
                ),
                child: NavigationBar(
                  height: 64,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (index) {
                    setState(() {
                      _selectedIndex = index;
                    });
                  },
                  destinations: [
                    _buildNavDestination(
                      icon: Icons.home_outlined,
                      selectedIcon: Icons.home,
                      label: 'Início',
                      isSelected: _selectedIndex == 0,
                    ),
                    _buildNavDestination(
                      icon: Icons.people_outline,
                      selectedIcon: Icons.people,
                      label: 'Clientes',
                      isSelected: _selectedIndex == 1,
                    ),
                    _buildNavDestination(
                      icon: Icons.message_outlined,
                      selectedIcon: Icons.message,
                      label: 'Mensagens',
                      isSelected: _selectedIndex == 2,
                    ),
                    _buildNavDestination(
                      icon: Icons.person_outline,
                      selectedIcon: Icons.person,
                      label: 'Perfil',
                      isSelected: _selectedIndex == 3,
                    ),
                  ],
                ),
              )
              : null,
    );
  }

  NavigationRailDestination _buildRailDestination({
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required bool isSelected,
  }) {
    return NavigationRailDestination(
      padding: const EdgeInsets.symmetric(vertical: 8),
      icon: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.secondary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          isSelected ? selectedIcon : icon,
          color: isSelected ? AppTheme.primary : AppTheme.mutedForeground,
          size: 24,
        ),
      ),
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? AppTheme.primary : AppTheme.mutedForeground,
          fontSize: 13,
        ),
      ),
    );
  }

  NavigationDestination _buildNavDestination({
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required bool isSelected,
  }) {
    return NavigationDestination(
      icon: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.secondary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          isSelected ? selectedIcon : icon,
          color: isSelected ? AppTheme.primary : AppTheme.mutedForeground,
          size: 24,
        ),
      ),
      label: label,
    );
  }
}
