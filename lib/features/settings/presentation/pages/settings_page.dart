import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/loading_service.dart';

import 'dart:ui';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/theme_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../notifications/presentation/providers/notification_provider.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    final currentTheme = ref.watch(themeProvider);
    final themeNotifier = ref.watch(themeProvider.notifier);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          // --- Title ---
          Padding(
            padding: const EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 0),
            child: Text(
              'Definições',
              style: theme.textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSettingsTile(
                  icon: Icons.person_outline,
                  title: 'Perfil',
                  subtitle: 'Ver perfil',
                  trailing: Icon(
                    Icons.chevron_right,
                    color: theme.colorScheme.onSurface.withAlpha((255 * 0.5).round()),
                  ),
                  onTap: () {
                    context.push('/profile-details');
                  },
                  theme: theme,
                  iconColor: theme.colorScheme.primary,
                ),
                const SizedBox(height: 24),
                // Group Tema and Notificações in a single card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(Icons.dark_mode, color: theme.colorScheme.primary, size: 24),
                        title: Text('Tema', style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
                        subtitle: Text(getThemeName(), style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 14)),
                        trailing: Switch(
                          value: currentTheme == ThemeMode.dark,
                          activeColor: theme.colorScheme.primary,
                          inactiveThumbColor: theme.colorScheme.outline,
                          trackOutlineColor: WidgetStateProperty.resolveWith((states) {
                            if (states.contains(WidgetState.selected)) {
                              return theme.colorScheme.primary;
                            }
                            return theme.colorScheme.outline.withAlpha((255 * 0.5).round());
                          }),
                          onChanged: (bool value) {
                            themeNotifier.setTheme(value ? ThemeMode.dark : ThemeMode.light);
                          },
                        ),
                      ),
                      ListTile(
                        leading: Icon(Icons.notifications_outlined, color: theme.colorScheme.primary, size: 24),
                        title: Text('Notificações', style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
                        subtitle: Text(ref.watch(pushNotificationSettingsProvider) ? 'Ativadas' : 'Desativadas', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 14)),
                        trailing: Switch(
                          value: ref.watch(pushNotificationSettingsProvider),
                          activeColor: theme.colorScheme.primary,
                          inactiveThumbColor: theme.colorScheme.outline,
                          trackOutlineColor: WidgetStateProperty.resolveWith((states) {
                            if (states.contains(WidgetState.selected)) {
                              return theme.colorScheme.primary;
                            }
                            return theme.colorScheme.outline.withAlpha((255 * 0.5).round());
                          }),
                          onChanged: (bool value) {
                            ref.read(pushNotificationSettingsProvider.notifier).setEnabled(value);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _buildSettingsTile(
                  icon: Icons.logout,
                  title: 'Sair',
                  subtitle: 'Encerrar a sessão atual',
                  textColor: theme.colorScheme.error,
                  onTap: () => _handleLogout(context),
                  theme: theme,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    final theme = Theme.of(context);

    final bool? shouldLogout = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: theme.colorScheme.surface.withAlpha(
              (255 * 0.95).round(),
            ),
            title: Text(
              'Sair',
              style: TextStyle(color: theme.colorScheme.onSurface),
            ),
            content: Text(
              'Tem certeza que deseja sair?',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withAlpha(
                  (255 * 0.7).round(),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'Cancelar',
                  style: TextStyle(color: theme.colorScheme.primary),
                ),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  'Sair',
                  style: TextStyle(color: theme.colorScheme.onError),
                ),
              ),
            ],
          ),
    );

    if (!context.mounted) return;

    if (shouldLogout == true) {
      final loadingService = ref.read(loadingServiceProvider);

      loadingService.show(context, message: 'Saindo...', showLogo: true);
      try {
        await FirebaseAuth.instance.signOut();
      } catch (e, stackTrace) {
        if (mounted) {
          loadingService.hide();
        }
        if (kDebugMode) {
          print('Error during sign out: $e');
          print(stackTrace);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao sair: ${e.toString()}')),
          );
        }
      }
    }
  }

  String getThemeName() {
    final currentTheme = ref.watch(themeProvider);
    switch (currentTheme) {
      case ThemeMode.light:
        return 'Claro';
      case ThemeMode.dark:
        return 'Escuro';
      case ThemeMode.system:
        return 'Sistema';
    }
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    Color? textColor,
    required ThemeData theme,
    Color? iconColor,
  }) {
    final isError = textColor == theme.colorScheme.error;
    // For single-action cards, return a _SingleActionSettingsTile
    if (onTap != null) {
      return _SingleActionSettingsTile(
        icon: icon,
        title: title,
        subtitle: subtitle,
        trailing: trailing,
        onTap: onTap,
        textColor: textColor,
        theme: theme,
        iconColor: iconColor,
      );
    }
    // For multi-row cards, return the row widget
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: EdgeInsets.zero,
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, color: iconColor ?? (isError ? theme.colorScheme.error : theme.colorScheme.onSurface), size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isError ? theme.colorScheme.error : theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: isError ? theme.colorScheme.error.withOpacity(0.8) : theme.colorScheme.onSurfaceVariant.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SingleActionSettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? textColor;
  final ThemeData theme;
  final Color? iconColor;
  const _SingleActionSettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
    this.textColor,
    required this.theme,
    this.iconColor,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isError = textColor == theme.colorScheme.error;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      highlightColor: Colors.transparent,
      splashColor: Colors.transparent,
      child: Material(
        color: theme.colorScheme.surface,
        elevation: 2,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, color: iconColor ?? (isError ? theme.colorScheme.error : theme.colorScheme.onSurface), size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isError ? theme.colorScheme.error : theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: isError ? theme.colorScheme.error.withOpacity(0.8) : theme.colorScheme.onSurfaceVariant.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
