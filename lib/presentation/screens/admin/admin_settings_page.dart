import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:ui';
import 'package:go_router/go_router.dart';
import '../../../core/theme/theme.dart';
import '../../../../app/router/app_router.dart';
import '../../../features/user_management/presentation/pages/user_management_page.dart';

class AdminSettingsPage extends StatefulWidget {
  const AdminSettingsPage({super.key});

  @override
  State<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends State<AdminSettingsPage> {
  bool _isDarkMode = true;
  bool _notificationsEnabled = true;
  bool _securityAlertsEnabled = true;
  String _selectedLanguage = 'English';

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Settings',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: AppTheme.foreground,
            ),
          ),
          const SizedBox(height: 32),
          _buildSettingsGroup('System Settings', [
            _buildToggleSetting(
              'Dark Mode',
              'Switch between light and dark themes',
              CupertinoIcons.moon_fill,
              _isDarkMode,
              (value) {
                setState(() {
                  _isDarkMode = value;
                });
              },
            ),
            _buildToggleSetting(
              'Notifications',
              'Enable push notifications',
              CupertinoIcons.bell_fill,
              _notificationsEnabled,
              (value) {
                setState(() {
                  _notificationsEnabled = value;
                });
              },
            ),
            _buildToggleSetting(
              'Security Alerts',
              'Receive alerts about security events',
              CupertinoIcons.shield_fill,
              _securityAlertsEnabled,
              (value) {
                setState(() {
                  _securityAlertsEnabled = value;
                });
              },
            ),
          ]),
          const SizedBox(height: 24),
          _buildSettingsGroup('Admin Preferences', [
            _buildDropdownSetting(
              'Language',
              'Change the application language',
              CupertinoIcons.globe,
              _selectedLanguage,
              ['English', 'Portuguese', 'Spanish', 'French', 'German'],
              (value) {
                setState(() {
                  _selectedLanguage = value!;
                });
              },
            ),
            _buildActionSetting(
              'User Management',
              'Create and manage user accounts',
              CupertinoIcons.person_2_fill,
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const UserManagementPage(),
                  ),
                );
              },
            ),
            _buildActionSetting(
              'System Configuration',
              'Advanced system settings',
              CupertinoIcons.gear_alt_fill,
              () {
                // Navigate to system configuration
              },
            ),
            _buildActionSetting(
              'Salesforce Integration',
              'Connect and configure Salesforce',
              CupertinoIcons.cloud,
              () {
                context.go('/admin/salesforce-setup');
              },
            ),
            _buildActionSetting(
              'Export Database',
              'Export a backup of the database',
              CupertinoIcons.cloud_download_fill,
              () {
                _showBackupDialog(context);
              },
            ),
          ]),
          const SizedBox(height: 24),
          _buildSettingsGroup('Account', [
            _buildActionSetting(
              'Admin Profile',
              'View and edit your admin profile',
              CupertinoIcons.person_fill,
              () {
                // Navigate to admin profile
              },
            ),
            _buildActionSetting(
              'Security',
              'Change password and security settings',
              CupertinoIcons.lock_fill,
              () {
                // Navigate to security settings
              },
            ),
            _buildActionSetting(
              'Logout',
              'Sign out of your account',
              CupertinoIcons.square_arrow_right,
              () {
                _handleLogout(context);
              },
              color: Colors.red,
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildSettingsGroup(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.foreground,
          ),
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(20),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withAlpha(26),
                  width: 0.5,
                ),
              ),
              child: Column(children: children),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToggleSetting(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(26),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppTheme.foreground, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.foreground,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppTheme.foreground.withAlpha(179),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged, activeColor: Colors.amber),
        ],
      ),
    );
  }

  Widget _buildDropdownSetting(
    String title,
    String subtitle,
    IconData icon,
    String value,
    List<String> options,
    ValueChanged<String?> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(26),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppTheme.foreground, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.foreground,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppTheme.foreground.withAlpha(179),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(26),
                borderRadius: BorderRadius.circular(10),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: value,
                  icon: const Icon(CupertinoIcons.chevron_down, size: 16),
                  iconEnabledColor: AppTheme.foreground,
                  dropdownColor: Colors.grey[800],
                  style: TextStyle(color: AppTheme.foreground),
                  onChanged: onChanged,
                  items:
                      options.map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionSetting(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap, {
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(26),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color ?? AppTheme.foreground, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: color ?? AppTheme.foreground,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: (color ?? AppTheme.foreground).withAlpha(179),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              CupertinoIcons.chevron_right,
              color: (color ?? AppTheme.foreground).withAlpha(179),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _handleLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: AlertDialog(
            backgroundColor: Colors.grey[850],
            title: const Text('Logout', style: TextStyle(color: Colors.white)),
            content: const Text(
              'Are you sure you want to logout?',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(foregroundColor: Colors.white70),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // Set authenticated to false and redirect to login
                  AppRouter.authNotifier.setAuthenticated(false);
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Logout'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showBackupDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: AlertDialog(
            backgroundColor: Colors.grey[850],
            title: const Text(
              'Export Database',
              style: TextStyle(color: Colors.white),
            ),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select export format:',
                  style: TextStyle(color: Colors.white70),
                ),
                SizedBox(height: 16),
                RadioListTile(
                  value: true,
                  groupValue: true,
                  title: Text('JSON', style: TextStyle(color: Colors.white70)),
                  onChanged: null,
                  activeColor: Colors.amber,
                ),
                RadioListTile(
                  value: false,
                  groupValue: true,
                  title: Text('CSV', style: TextStyle(color: Colors.white70)),
                  onChanged: null,
                  activeColor: Colors.amber,
                ),
                RadioListTile(
                  value: false,
                  groupValue: true,
                  title: Text('SQL', style: TextStyle(color: Colors.white70)),
                  onChanged: null,
                  activeColor: Colors.amber,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(foregroundColor: Colors.white70),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // Show export success dialog
                  _showExportSuccessDialog(context);
                },
                style: TextButton.styleFrom(foregroundColor: Colors.amber),
                child: const Text('Export'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showExportSuccessDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: AlertDialog(
            backgroundColor: Colors.grey[850],
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  'Export Successful',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
            content: const Text(
              'Database has been exported successfully to your downloads folder.',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(foregroundColor: Colors.amber),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      },
    );
  }
}
