import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../core/theme/text_styles.dart';
import '../../core/theme/colors.dart';
import '../screens/home/reseller_home_page.dart';
import '../screens/services/services_page.dart';
import '../screens/clients/clients_page.dart';
import '../screens/messages/messages_page.dart';

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
    const Center(child: Text('Perfil')), // Placeholder for Profile page
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final width = MediaQuery.of(context).size.width;
    final isSmallScreen = width < 600;

    return Scaffold(
      body: Row(
        children: [
          if (!isSmallScreen)
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
                  icon: const Icon(Icons.home_outlined),
                  selectedIcon: const Icon(Icons.home),
                  label: Text('Início'),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.people_outline),
                  selectedIcon: const Icon(Icons.people),
                  label: Text('Clientes'),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.message_outlined),
                  selectedIcon: const Icon(Icons.message),
                  label: Text('Mensagens'),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.person_outline),
                  selectedIcon: const Icon(Icons.person),
                  label: Text('Perfil'),
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
                        icon: const Icon(Icons.notifications_outlined),
                        onPressed: () {
                          // TODO: Implement notifications
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
      bottomNavigationBar:
          isSmallScreen
              ? Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Theme(
                  data: Theme.of(context).copyWith(
                    navigationBarTheme: NavigationBarThemeData(
                      indicatorColor: Colors.transparent,
                      labelTextStyle: MaterialStateProperty.resolveWith((
                        states,
                      ) {
                        return TextStyle(
                          color:
                              states.contains(MaterialState.selected)
                                  ? Colors.black
                                  : Colors.grey[600],
                          fontSize: 12,
                        );
                      }),
                    ),
                  ),
                  child: NavigationBar(
                    height: 64,
                    backgroundColor: Colors.white,
                    elevation: 0,
                    labelBehavior:
                        NavigationDestinationLabelBehavior.alwaysShow,
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
                ),
              )
              : null,
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
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.transparent,
          borderRadius: BorderRadius.circular(50),
        ),
        child: Icon(
          isSelected ? selectedIcon : icon,
          color: isSelected ? Colors.white : Colors.grey[600],
          size: 24,
        ),
      ),
      label: label,
    );
  }
}
