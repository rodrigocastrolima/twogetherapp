import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'dart:ui';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/theme/theme.dart';
import '../../../core/providers/theme_provider.dart';
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

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);
    final isDarkMode = themeMode == ThemeMode.dark;
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
            'Definições de Perfil',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 32),

          _buildSettingsGroup('Conta', [
            _buildActionSetting(
              'Perfil de Administrador',
              'Ver e editar perfil',
              CupertinoIcons.person_fill,
              () {
                // Navigate to admin profile
              },
            ),
          ]),
          const SizedBox(height: 24),

          _buildSettingsGroup('Definições Comuns', [
            _buildToggleSetting(
              'Tema',
              isDarkMode ? 'Escuro' : 'Claro',
              isDarkMode
                  ? CupertinoIcons.moon_fill
                  : CupertinoIcons.sun_max_fill,
              isDarkMode,
              (value) {
                if (kDebugMode) {
                  print('[AdminSettingsPage] Theme switch toggled: $value');
                }
                ref.read(themeProvider.notifier).toggleTheme();
              },
            ),
            _buildLanguageSetting(
              'Idioma',
              'Selecionar idioma da aplicação',
              CupertinoIcons.globe,
              'pt',
            ),
            _buildToggleSetting(
              'Notificações',
              'Gerir preferências de notificação',
              CupertinoIcons.bell_fill,
              _notificationsEnabled,
              (value) {
                setState(() {
                  _notificationsEnabled = value;
                });
              },
            ),
            _buildToggleSetting(
              'Alertas de Segurança',
              'Receber alertas sobre atividade suspeita',
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

          _buildSettingsGroup('Preferências de Administrador', [
            _buildActionSetting(
              'Configuração do Sistema',
              'Gerir configurações gerais do sistema',
              CupertinoIcons.gear_alt_fill,
              () {
                // TODO: Navigate to system configuration
              },
            ),
            _buildActionSetting(
              'Conectar Salesforce',
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
            'Terminar Sessão',
            'Encerrar a sessão atual',
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
                          ? Color.alphaBlend(
                            theme.colorScheme.onSurface.withAlpha(
                              (255 * 0.05).round(),
                            ),
                            Colors.transparent,
                          )
                          : Color.alphaBlend(
                            theme.dividerColor.withAlpha((255 * 0.1).round()),
                            Colors.transparent,
                          ),
                  width: 0.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                        isDark
                            ? Color.alphaBlend(
                              theme.colorScheme.shadow.withAlpha(
                                (255 * 0.2).round(),
                              ),
                              Colors.transparent,
                            )
                            : Color.alphaBlend(
                              theme.colorScheme.shadow.withAlpha(
                                (255 * 0.05).round(),
                              ),
                              Colors.transparent,
                            ),
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
                    color: Color.alphaBlend(
                      theme.colorScheme.onSurface.withAlpha(
                        (255 * 0.7).round(),
                      ),
                      Colors.transparent,
                    ),
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
                    color: Color.alphaBlend(
                      theme.colorScheme.onSurface.withAlpha(
                        (255 * 0.7).round(),
                      ),
                      Colors.transparent,
                    ),
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
                color: Color.alphaBlend(
                  theme.colorScheme.surface.withAlpha((255 * 0.5).round()),
                  Colors.transparent,
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Color.alphaBlend(
                    theme.colorScheme.outline.withAlpha((255 * 0.2).round()),
                    Colors.transparent,
                  ),
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
                  dropdownColor: Color.alphaBlend(
                    theme.colorScheme.surface.withAlpha((255 * 0.95).round()),
                    Colors.transparent,
                  ),
                  style: TextStyle(color: theme.colorScheme.onSurface),
                  onChanged: (String? value) async {
                    // Language changing is removed, so this callback does nothing
                  },
                  items: const [
                    DropdownMenuItem<String>(
                      value: 'pt',
                      child: Text('Português'),
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
                color: Color.alphaBlend(
                  iconColor.withAlpha((255 * 0.1).round()),
                  Colors.transparent,
                ),
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
                      color: Color.alphaBlend(
                        color ?? defaultColor,
                        Colors.transparent,
                      ),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Color.alphaBlend(
                        (color ?? defaultColor).withAlpha((255 * 0.7).round()),
                        Colors.transparent,
                      ),
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
                color: Color.alphaBlend(
                  (color ?? defaultColor).withAlpha((255 * 0.7).round()),
                  Colors.transparent,
                ),
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

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: AlertDialog(
            backgroundColor: Color.alphaBlend(
              theme.colorScheme.surface.withAlpha((255 * 0.95).round()),
              Colors.transparent,
            ),
            title: Text(
              'Terminar Sessão',
              style: TextStyle(color: theme.colorScheme.onSurface),
            ),
            content: Text(
              'Tem a certeza que deseja terminar a sessão?',
              style: TextStyle(
                color: Color.alphaBlend(
                  theme.colorScheme.onSurface.withAlpha((255 * 0.7).round()),
                  Colors.transparent,
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.primary,
                ),
                child: Text('Cancelar'),
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
                child: Text('Terminar Sessão'),
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
