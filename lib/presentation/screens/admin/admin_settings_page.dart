import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'dart:ui';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/theme/theme.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/providers/locale_provider.dart';
import '../../../core/theme/ui_styles.dart';
import '../../../app/router/app_router.dart';
import '../../../features/user_management/presentation/pages/user_management_page.dart';
import '../../../core/services/loading_service.dart';
import '../../../core/services/salesforce_auth_service.dart';

class AdminSettingsPage extends ConsumerStatefulWidget {
  const AdminSettingsPage({super.key});

  @override
  ConsumerState<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends ConsumerState<AdminSettingsPage> {
  bool _notificationsEnabled = true;
  bool _securityAlertsEnabled = true;

  Future<void> _testSalesforceApiCall() async {
    final salesforceNotifier = ref.read(salesforceAuthProvider.notifier);
    final accessToken = salesforceNotifier.currentAccessToken;
    final instanceUrl = salesforceNotifier.currentInstanceUrl;
    final loadingService = ref.read(loadingServiceProvider);

    if (accessToken == null || instanceUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Salesforce is not connected.')),
      );
      return;
    }

    loadingService.show(context, message: 'Testing API Call...');

    try {
      final url = Uri.parse('$instanceUrl/services/oauth2/userinfo');

      if (kDebugMode) {
        print('Making GET request to: $url');
        print('Using Access Token: Bearer $accessToken');
      }

      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (mounted) {
        loadingService.hide();
      }

      if (response.statusCode == 200) {
        final userInfo = jsonDecode(response.body);
        final userName = userInfo['name'] ?? 'N/A';
        final userEmail = userInfo['email'] ?? 'N/A';
        if (kDebugMode) {
          print('Salesforce API Call Success!');
          print('Response: ${response.body}');
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('API Call Success! User: $userName ($userEmail)'),
              backgroundColor: AppTheme.success,
            ),
          );
        }
      } else {
        if (kDebugMode) {
          print(
            'Salesforce API Call Failed: ${response.statusCode} ${response.reasonPhrase}',
          );
          print('Response Body: ${response.body}');
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'API Call Failed: ${response.statusCode} - ${response.reasonPhrase}',
              ),
              backgroundColor: AppTheme.destructive,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        loadingService.hide();
      }
      if (kDebugMode) {
        print('Error during Salesforce API call: $e');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error during API call: $e'),
            backgroundColor: AppTheme.destructive,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);
    final isDarkMode = themeMode == ThemeMode.dark;
    final currentLocale = ref.watch(localeProvider);
    final localeNotifier = ref.watch(localeProvider.notifier);
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;

    final salesforceState = ref.watch(salesforceAuthProvider);

    Color statusColor;
    String statusSubtitle;
    bool isConnected = false;

    switch (salesforceState) {
      case SalesforceAuthState.authenticated:
        statusColor = AppTheme.success;
        statusSubtitle = 'Connected';
        isConnected = true;
        break;
      case SalesforceAuthState.unauthenticated:
      case SalesforceAuthState.error:
        statusColor = AppTheme.destructive;
        statusSubtitle = 'Disconnected - Tap to connect';
        break;
      case SalesforceAuthState.authenticating:
      case SalesforceAuthState.unknown:
      default:
        statusColor = AppTheme.muted;
        statusSubtitle = 'Checking Status...';
        break;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.profileSettings,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 32),

          _buildSettingsGroup(l10n.account, [
            _buildActionSetting(
              l10n.adminProfile,
              l10n.viewEditProfile,
              CupertinoIcons.person_fill,
              () {
                // Navigate to admin profile
              },
            ),
          ]),
          const SizedBox(height: 24),

          _buildSettingsGroup(l10n.commonSettings, [
            _buildToggleSetting(
              l10n.profileTheme,
              isDarkMode ? l10n.profileThemeDark : l10n.profileThemeLight,
              isDarkMode
                  ? CupertinoIcons.moon_fill
                  : CupertinoIcons.sun_max_fill,
              isDarkMode,
              (value) {
                ref.read(themeProvider.notifier).toggleTheme();
              },
            ),
            _buildLanguageSetting(
              l10n.commonLanguage,
              l10n.commonLanguageSelection,
              CupertinoIcons.globe,
              currentLocale.languageCode,
              localeNotifier,
            ),
            _buildToggleSetting(
              l10n.homeNotifications,
              l10n.notificationPreferences,
              CupertinoIcons.bell_fill,
              _notificationsEnabled,
              (value) {
                setState(() {
                  _notificationsEnabled = value;
                });
              },
            ),
            _buildToggleSetting(
              l10n.securityAlerts,
              l10n.securityAlertsDescription,
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

          _buildSettingsGroup(l10n.adminPreferences, [
            _buildActionSetting(
              l10n.adminSystemConfig,
              l10n.adminSystemConfigDescription,
              CupertinoIcons.gear_alt_fill,
              () {
                // TODO: Navigate to system configuration
              },
            ),
            _buildActionSetting(
              l10n.profileSalesforceConnect,
              statusSubtitle,
              CupertinoIcons.cloud,
              () async {
                if (!isConnected) {
                  final loadingService = ref.read(loadingServiceProvider);
                  final salesforceNotifier = ref.read(
                    salesforceAuthProvider.notifier,
                  );
                  loadingService.show(
                    context,
                    message: 'Connecting to Salesforce...',
                  );
                  try {
                    await salesforceNotifier.signIn();
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Salesforce connection failed: $e'),
                        ),
                      );
                    }
                  } finally {
                    if (mounted) {
                      loadingService.hide();
                    }
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Already connected. Disconnect functionality not implemented yet.',
                      ),
                    ),
                  );
                }
              },
              statusIndicator: _buildStatusIndicator(statusColor),
              hideChevron: true,
            ),
            _buildActionSetting(
              'Developer Tools',
              'Access admin-only scripts and tools.',
              CupertinoIcons.hammer_fill,
              () => context.push('/admin/dev-tools'),
            ),
          ]),
          const SizedBox(height: 24),

          _buildActionSetting(
            l10n.profileLogout,
            l10n.profileEndSession,
            CupertinoIcons.square_arrow_right,
            () {
              _handleLogout(context, ref);
            },
            color: Theme.of(context).colorScheme.error,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsGroup(String title, List<Widget> children) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: AppStyles.standardBlur,
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withOpacity(0.8),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color:
                      isDark
                          ? theme.colorScheme.onSurface.withOpacity(0.05)
                          : theme.dividerColor.withOpacity(0.1),
                  width: 0.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                        isDark
                            ? theme.colorScheme.shadow.withOpacity(0.2)
                            : theme.colorScheme.shadow.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
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
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: theme.colorScheme.primary, size: 24),
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
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: theme.colorScheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageSetting(
    String title,
    String subtitle,
    IconData icon,
    String currentLocale,
    LocaleNotifier localeNotifier,
  ) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: theme.colorScheme.primary, size: 24),
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
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
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
                color: theme.colorScheme.surface.withOpacity(0.5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: theme.colorScheme.outline.withOpacity(0.2),
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: currentLocale,
                  icon: Icon(
                    CupertinoIcons.chevron_down,
                    size: 16,
                    color: theme.colorScheme.onSurface,
                  ),
                  dropdownColor: theme.colorScheme.surface.withOpacity(0.95),
                  style: TextStyle(color: theme.colorScheme.onSurface),
                  onChanged: (String? value) async {
                    if (value != null) {
                      if (kDebugMode) {
                        print("Changing language to: $value");
                      }
                      try {
                        await localeNotifier.setLocale(value);
                        if (kDebugMode) {
                          print("Language changed successfully to: $value");
                        }
                      } catch (e) {
                        if (kDebugMode) {
                          print("Error changing language: $e");
                        }
                      }
                    }
                  },
                  items: [
                    DropdownMenuItem<String>(
                      value: 'pt',
                      child: Text(localeNotifier.getLanguageNameFromCode('pt')),
                    ),
                    DropdownMenuItem<String>(
                      value: 'en',
                      child: Text(localeNotifier.getLanguageNameFromCode('en')),
                    ),
                    DropdownMenuItem<String>(
                      value: 'es',
                      child: Text(localeNotifier.getLanguageNameFromCode('es')),
                    ),
                  ],
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
    Widget? statusIndicator,
    bool hideChevron = false,
  }) {
    final theme = Theme.of(context);
    final defaultColor = theme.colorScheme.onSurface;
    final iconColor = color ?? theme.colorScheme.primary;

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
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 24),
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
                      color: color ?? defaultColor,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: (color ?? defaultColor).withOpacity(0.7),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            if (statusIndicator != null) statusIndicator,
            if (!hideChevron) ...[
              const SizedBox(width: 8),
              Icon(
                CupertinoIcons.chevron_right,
                color: (color ?? defaultColor).withOpacity(0.7),
                size: 20,
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _handleLogout(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: AlertDialog(
            backgroundColor: theme.colorScheme.surface.withOpacity(0.95),
            title: Text(
              l10n.profileLogout,
              style: TextStyle(color: theme.colorScheme.onSurface),
            ),
            content: Text(
              l10n.profileLogoutConfirm,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.primary,
                ),
                child: Text(l10n.commonCancel),
              ),
              FilledButton(
                onPressed: () async {
                  Navigator.of(dialogContext).pop();

                  final loadingService = ref.read(loadingServiceProvider);
                  loadingService.show(
                    context,
                    message: 'Signing out...',
                    showLogo: true,
                  );

                  try {
                    await ref.read(salesforceAuthProvider.notifier).signOut();
                    await AppRouter.authNotifier.setAuthenticated(false);
                    if (mounted) {
                      loadingService.hide();
                    }
                  } catch (error) {
                    if (mounted) {
                      loadingService.hide();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error signing out: $error'),
                          backgroundColor: AppTheme.destructive,
                        ),
                      );
                    }
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: theme.colorScheme.onError,
                ),
                child: Text(l10n.profileLogout),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusIndicator(Color color) {
    return Container(
      width: 10,
      height: 10,
      margin: const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
