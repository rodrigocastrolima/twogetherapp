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
        statusSubtitle = 'Conectado';
        isConnected = true;
        break;
      case SalesforceAuthState.unauthenticated:
      case SalesforceAuthState.error:
        statusColor = AppTheme.destructive;
        statusSubtitle = 'Desconectado - Toque para conectar';
        break;
      case SalesforceAuthState.authenticating:
      case SalesforceAuthState.unknown:
        statusColor = AppTheme.muted;
        statusSubtitle = 'A verificar estado...';
        break;
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Page Title ---
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
          // --- Conta Section ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                child: ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  leading: Icon(CupertinoIcons.person_fill, color: theme.colorScheme.primary, size: 24),
                  title: Text('Perfil de Administrador', style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
                  subtitle: Text('Ver e editar perfil', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 14)),
                  onTap: () {},
                  trailing: Icon(CupertinoIcons.chevron_right, color: theme.colorScheme.onSurfaceVariant, size: 20),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // --- Definições Comuns Section ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    child: ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      leading: Icon(isDarkMode ? CupertinoIcons.moon_fill : CupertinoIcons.sun_max_fill, color: theme.colorScheme.primary, size: 24),
                      title: Text('Tema', style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
                      subtitle: Text(isDarkMode ? 'Escuro' : 'Claro', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 14)),
                      trailing: Switch(
                        value: isDarkMode,
                        onChanged: (value) => ref.read(themeProvider.notifier).toggleTheme(),
                        activeColor: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    child: ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      leading: Icon(CupertinoIcons.bell_fill, color: theme.colorScheme.primary, size: 24),
                      title: Text('Notificações', style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
                      subtitle: Text('Gerir preferências de notificação', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 14)),
                      trailing: Switch(
                        value: _notificationsEnabled,
                        onChanged: (value) => setState(() => _notificationsEnabled = value),
                        activeColor: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // --- Preferências de Administrador Section ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                child: ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  leading: Icon(CupertinoIcons.cloud, color: theme.colorScheme.primary, size: 24),
                  title: Text('Conectar Salesforce', style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
                  subtitle: Text(statusSubtitle, style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 14)),
                  onTap: () async {
                    if (!isConnected) {
                      final loadingService = ref.read(loadingServiceProvider);
                      final salesforceNotifier = ref.read(salesforceAuthProvider.notifier);
                      loadingService.show(context, message: 'Conectando ao Salesforce...');
                      try {
                        await salesforceNotifier.signIn();
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Falha na conexão com o Salesforce: $e')),
                          );
                        }
                      } finally {
                        if (mounted) loadingService.hide();
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Conectado')),
                      );
                    }
                  },
                  trailing: Container(width: 10, height: 10, margin: const EdgeInsets.only(right: 8), decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // --- Terminar Sessão ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                child: ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  leading: Icon(CupertinoIcons.square_arrow_right, color: theme.colorScheme.error, size: 24),
                  title: Text('Terminar Sessão', style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.error)),
                  subtitle: Text('Encerrar a sessão atual', style: TextStyle(color: theme.colorScheme.error.withOpacity(0.7), fontSize: 14)),
                  onTap: () => _handleLogout(context, ref),
                  trailing: null,
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
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
}
