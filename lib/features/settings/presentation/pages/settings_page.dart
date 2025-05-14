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
            vertical: AppConstants.spacing24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Configurações',
                style: AppTextStyles.h2.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppConstants.spacing32),
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
            subtitle: 'Editar perfil',
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
                  print('[SettingsPage] Theme switch toggled: $value');
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spacing16,
              vertical: AppConstants.spacing8,
            ),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withAlpha(
                  (255 * 0.5).round(),
                ),
              ),
            ),
          ),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              decoration: BoxDecoration(
                color: theme.brightness == Brightness.dark ? const Color(0xFF1C1C1E) : const Color(0xFFF5F5F7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color:
                      theme.brightness == Brightness.dark
                          ? theme.colorScheme.onSurface.withAlpha(
                            (255 * 0.05).round(),
                          )
                          : theme.dividerColor.withAlpha((255 * 0.1).round()),
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                        theme.brightness == Brightness.dark
                            ? theme.colorScheme.shadow.withAlpha(
                              (255 * 0.2).round(),
                            )
                            : theme.colorScheme.shadow.withAlpha(
                              (255 * 0.08).round(),
                            ),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Column(children: items),
            ),
          ),
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
    final Color defaultTextColor = theme.colorScheme.onSurface;
    final Color iconColor =
        textColor ?? theme.colorScheme.onSurface.withAlpha((255 * 0.7).round());
    final Color subtitleColor =
        textColor != null
            ? textColor.withAlpha((255 * 0.7).round())
            : theme.colorScheme.onSurface.withAlpha((255 * 0.6).round());

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacing16,
          vertical: AppConstants.spacing12,
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 24),
            const SizedBox(width: AppConstants.spacing16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: textColor ?? defaultTextColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 14, color: subtitleColor),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }
}
