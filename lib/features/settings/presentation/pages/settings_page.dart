import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/loading_service.dart';
import '../../../../app/router/app_router.dart';
import 'dart:ui';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/utils/constants.dart';
import '../../../../core/theme/ui_styles.dart';
import '../../../../core/providers/theme_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../presentation/widgets/app_loading_indicator.dart';

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

    return ClipRect(
      child: NoScrollbarBehavior.noScrollbars(
        context,
        SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacing16,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 32),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      'Definições',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                      textAlign: TextAlign.left,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildSettingsMenu(
                    context,
                    ref,
                    themeNotifier,
                    currentTheme,
                    theme,
                  ),
                ],
              ),
            ),
          ),
        ),
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

  Widget _buildSettingsMenu(
    BuildContext context,
    WidgetRef ref,
    ThemeNotifier themeNotifier,
    ThemeMode currentTheme,
    ThemeData theme,
  ) {
    String getThemeName() {
      switch (currentTheme) {
        case ThemeMode.light:
          return 'Claro';
        case ThemeMode.dark:
          return 'Escuro';
        case ThemeMode.system:
          return 'Sistema';
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSettingsSection('Informações Pessoais', [
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
          ),
        ], theme),
        const SizedBox(height: AppConstants.spacing32),
        _buildSettingsSection('Preferências', [
          _buildSettingsTile(
            icon: Icons.dark_mode,
            title: 'Tema',
            subtitle: getThemeName(),
            trailing: Switch(
              value: currentTheme == ThemeMode.dark,
              activeColor: theme.colorScheme.primary,
              inactiveTrackColor: theme.colorScheme.onSurface.withAlpha(
                (255 * 0.3).round(),
              ),
              onChanged: (bool value) {
                if (kDebugMode) {
                  // print('[SettingsPage] Theme switch toggled: $value');
                }
                themeNotifier.setTheme(
                  value ? ThemeMode.dark : ThemeMode.light,
                );
              },
            ),
            theme: theme,
          ),
          _buildSettingsTile(
            icon: Icons.notifications_outlined,
            title: 'Notificações',
            subtitle: 'Todas',
            trailing: DropdownButton<String>(
              value: 'Todas',
              underline: const SizedBox(),
              icon: Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurface.withAlpha(
                  (255 * 0.5).round(),
                ),
              ),
              dropdownColor: theme.colorScheme.surface.withAlpha(
                (255 * 0.9).round(),
              ),
              items: [
                DropdownMenuItem(
                  value: 'Todas',
                  child: Text(
                    'Todas',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withAlpha(
                        (255 * 0.7).round(),
                      ),
                    ),
                  ),
                ),
                DropdownMenuItem(
                  value: 'Importantes',
                  child: Text(
                    'Importantes',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withAlpha(
                        (255 * 0.7).round(),
                      ),
                    ),
                  ),
                ),
                DropdownMenuItem(
                  value: 'Nenhuma',
                  child: Text(
                    'Nenhuma',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withAlpha(
                        (255 * 0.7).round(),
                      ),
                    ),
                  ),
                ),
              ],
              onChanged: (value) {
                // Handle notifications change
              },
            ),
            theme: theme,
          ),
        ], theme),
        const SizedBox(height: AppConstants.spacing32),
        _buildSettingsSection('', [
          _buildSettingsTile(
            icon: Icons.logout,
            title: 'Sair',
            subtitle: 'Encerrar sessão',
            textColor: theme.colorScheme.error,
            onTap: () => _handleLogout(context),
            theme: theme,
          ),
        ], theme),
      ],
    );
  }

  Widget _buildSettingsSection(
    String title,
    List<Widget> items,
    ThemeData theme,
  ) {
    // If this is a single-action card, build it directly with InkWell+Material
    if (items.length == 1 && items.first is _SingleActionSettingsTile) {
      final data = items.first as _SingleActionSettingsTile;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
              child: Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
                textAlign: TextAlign.left,
              ),
            ),
          data,
        ],
      );
    }
    // Otherwise, multi-row card
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.left,
            ),
          ),
        Material(
          color: theme.colorScheme.surface,
          elevation: 2,
          borderRadius: BorderRadius.circular(10),
          child: Column(children: items),
        ),
      ],
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    Color? textColor,
    required ThemeData theme,
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
      );
    }
    // For multi-row cards, return the row widget
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: isError ? theme.colorScheme.error : theme.colorScheme.onSurface, size: 24),
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
  const _SingleActionSettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
    this.textColor,
    required this.theme,
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
              Icon(icon, color: isError ? theme.colorScheme.error : theme.colorScheme.onSurface, size: 24),
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
