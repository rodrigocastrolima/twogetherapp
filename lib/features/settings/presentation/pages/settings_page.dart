import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/loading_service.dart';
import '../../../../app/router/app_router.dart';
import 'dart:ui';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/utils/constants.dart';
import '../../../../core/theme/ui_styles.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/providers/theme_provider.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    final localeNotifier = ref.watch(localeProvider.notifier);
    final currentLocale = ref.watch(localeProvider);
    final currentTheme = ref.watch(themeProvider);
    final themeNotifier = ref.watch(themeProvider.notifier);
    final l10n = AppLocalizations.of(context)!;
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
                l10n.profileSettings,
                style: AppTextStyles.h2.copyWith(
                  color: theme.colorScheme.onBackground,
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppConstants.spacing32),
              _buildSettingsMenu(
                context,
                ref,
                localeNotifier,
                currentLocale,
                themeNotifier,
                currentTheme,
                l10n,
                theme,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleLogout(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    // Show confirmation dialog
    final bool? shouldLogout = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Theme.of(
              context,
            ).colorScheme.surface.withOpacity(0.95),
            title: Text(
              l10n.profileLogout,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
            content: Text(
              l10n.profileLogoutConfirm,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  l10n.commonCancel,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  l10n.profileLogout,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onError,
                  ),
                ),
              ),
            ],
          ),
    );

    if (shouldLogout == true) {
      // Show loading overlay during sign out
      final loadingService = ref.read(loadingServiceProvider);
      loadingService.show(context, message: 'Signing out...', showLogo: true);

      try {
        // Set authentication to false which will trigger the router to redirect to login
        await AppRouter.authNotifier.setAuthenticated(false);
      } finally {
        // Hide loading overlay
        loadingService.hide();
      }
    }
  }

  Widget _buildSettingsMenu(
    BuildContext context,
    WidgetRef ref,
    LocaleNotifier localeNotifier,
    Locale currentLocale,
    ThemeNotifier themeNotifier,
    ThemeMode currentTheme,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    String getThemeName() {
      switch (currentTheme) {
        case ThemeMode.light:
          return l10n.profileThemeLight;
        case ThemeMode.dark:
          return l10n.profileThemeDark;
        case ThemeMode.system:
          return 'System';
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSettingsSection(l10n.profilePersonalInfo, [
          _buildSettingsTile(
            icon: Icons.dashboard_outlined,
            title: 'Dashboard',
            subtitle: l10n.profilePersonalInfo,
            trailing: Icon(
              Icons.chevron_right,
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
            onTap: () {
              // Navigate to dashboard
            },
            theme: theme,
          ),
          _buildSettingsTile(
            icon: Icons.lock_outline,
            title: l10n.profileChangePassword,
            subtitle: l10n.profileUpdatePassword,
            trailing: Icon(
              Icons.chevron_right,
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
            onTap: () {
              // Handle password change
            },
            theme: theme,
          ),
        ], theme),
        const SizedBox(height: AppConstants.spacing32),
        _buildSettingsSection(l10n.commonFilter, [
          _buildSettingsTile(
            icon: Icons.dark_mode,
            title: l10n.profileTheme,
            subtitle: getThemeName(),
            trailing: Switch(
              value: currentTheme == ThemeMode.dark,
              activeColor: theme.colorScheme.primary,
              inactiveTrackColor: theme.colorScheme.onSurface.withOpacity(0.3),
              onChanged: (bool value) {
                themeNotifier.setTheme(
                  value ? ThemeMode.dark : ThemeMode.light,
                );
              },
            ),
            theme: theme,
          ),
          _buildSettingsTile(
            icon: Icons.language,
            title: l10n.commonLanguage,
            subtitle: localeNotifier.getLanguageName(),
            trailing: DropdownButton<String>(
              value: currentLocale.languageCode,
              underline: const SizedBox(),
              icon: Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
              dropdownColor: theme.colorScheme.surface.withOpacity(0.9),
              items: [
                DropdownMenuItem(
                  value: 'pt',
                  child: Text(
                    localeNotifier.getLanguageNameFromCode('pt'),
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ),
                DropdownMenuItem(
                  value: 'en',
                  child: Text(
                    localeNotifier.getLanguageNameFromCode('en'),
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ),
                DropdownMenuItem(
                  value: 'es',
                  child: Text(
                    localeNotifier.getLanguageNameFromCode('es'),
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  localeNotifier.setLocale(value);
                }
              },
            ),
            theme: theme,
          ),
          _buildSettingsTile(
            icon: Icons.cloud_outlined,
            title: 'Salesforce',
            subtitle: l10n.profileSalesforceConnect,
            trailing: Icon(
              Icons.chevron_right,
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
            onTap: () {
              context.go('/salesforce-setup');
            },
            theme: theme,
          ),
          _buildSettingsTile(
            icon: Icons.notifications_outlined,
            title: l10n.homeNotifications,
            subtitle: l10n.homeNoNotifications,
            trailing: DropdownButton<String>(
              value: 'Todas',
              underline: const SizedBox(),
              icon: Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
              dropdownColor: theme.colorScheme.surface.withOpacity(0.9),
              items: [
                DropdownMenuItem(
                  value: 'Todas',
                  child: Text(
                    'Todas',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ),
                DropdownMenuItem(
                  value: 'Importantes',
                  child: Text(
                    'Importantes',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ),
                DropdownMenuItem(
                  value: 'Nenhuma',
                  child: Text(
                    'Nenhuma',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
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
            title: l10n.profileLogout,
            subtitle: l10n.profileEndSession,
            textColor: theme.colorScheme.error,
            onTap: () => _handleLogout(context, l10n),
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
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withOpacity(0.8),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color:
                      theme.brightness == Brightness.dark
                          ? theme.colorScheme.onSurface.withOpacity(0.05)
                          : theme.dividerColor.withOpacity(0.1),
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                        theme.brightness == Brightness.dark
                            ? theme.colorScheme.shadow.withOpacity(0.2)
                            : theme.colorScheme.shadow.withOpacity(0.08),
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
        textColor ?? theme.colorScheme.onSurface.withOpacity(0.7);
    final Color subtitleColor =
        textColor != null
            ? textColor.withOpacity(0.7)
            : theme.colorScheme.onSurface.withOpacity(0.6);

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
