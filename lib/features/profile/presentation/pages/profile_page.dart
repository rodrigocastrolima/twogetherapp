import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui';
import 'package:go_router/go_router.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/utils/constants.dart';
import '../../../../core/theme/ui_styles.dart';
import '../../../../app/router/app_router.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/providers/theme_provider.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localeNotifier = ref.watch(localeProvider.notifier);
    final currentLocale = ref.watch(localeProvider);
    final currentTheme = ref.watch(themeProvider);
    final themeNotifier = ref.watch(themeProvider.notifier);
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return NoScrollbarBehavior.noScrollbars(
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
              l10n.profileTitle,
              style: AppTextStyles.h2.copyWith(
                color: isDark ? Colors.white : AppTheme.foreground,
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
              isDark,
            ),
          ],
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
            backgroundColor:
                Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.darkBackground.withAlpha(230)
                    : Colors.white.withAlpha(230),
            title: Text(l10n.profileLogout),
            content: Text(l10n.profileLogoutConfirm),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  l10n.commonCancel,
                  style: TextStyle(
                    color:
                        Theme.of(context).brightness == Brightness.dark
                            ? Colors.white70
                            : AppTheme.foreground,
                  ),
                ),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(context, true),
                child: Text(l10n.profileLogout),
              ),
            ],
          ),
    );

    if (shouldLogout == true) {
      // Set authentication to false which will trigger the router to redirect to login
      await AppRouter.authNotifier.setAuthenticated(false);
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
    bool isDark,
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
        Text(
          l10n.profileSettings,
          style: AppTextStyles.h2.copyWith(
            color: isDark ? Colors.white : AppTheme.foreground,
            fontSize: 28,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppConstants.spacing24),
        _buildSettingsSection(l10n.profilePersonalInfo, [
          _buildSettingsTile(
            icon: Icons.dashboard_outlined,
            title: 'Dashboard',
            subtitle: l10n.profilePersonalInfo,
            trailing: const Icon(Icons.chevron_right, color: Colors.white54),
            onTap: () {
              // Navigate to dashboard
            },
            isDark: isDark,
          ),
          _buildSettingsTile(
            icon: Icons.lock_outline,
            title: l10n.profileChangePassword,
            subtitle: l10n.profileUpdatePassword,
            trailing: const Icon(Icons.chevron_right, color: Colors.white54),
            onTap: () {
              // Handle password change
            },
            isDark: isDark,
          ),
        ], isDark),
        const SizedBox(height: AppConstants.spacing32),
        _buildSettingsSection(l10n.commonFilter, [
          _buildSettingsTile(
            icon: Icons.dark_mode,
            title: l10n.profileTheme,
            subtitle: getThemeName(),
            trailing: Switch(
              value: currentTheme == ThemeMode.dark,
              activeColor: isDark ? AppTheme.darkPrimary : AppTheme.primary,
              inactiveTrackColor:
                  isDark
                      ? Colors.white.withOpacity(0.3)
                      : Colors.black.withOpacity(0.3),
              onChanged: (bool value) {
                themeNotifier.setTheme(
                  value ? ThemeMode.dark : ThemeMode.light,
                );
              },
            ),
            isDark: isDark,
          ),
          _buildSettingsTile(
            icon: Icons.language,
            title: l10n.commonLanguage,
            subtitle: localeNotifier.getLanguageName(),
            trailing: DropdownButton<String>(
              value: currentLocale.languageCode,
              underline: const SizedBox(),
              icon: const Icon(Icons.chevron_right, color: Colors.white54),
              dropdownColor:
                  isDark
                      ? AppTheme.darkBackground.withOpacity(0.9)
                      : Colors.white.withOpacity(0.9),
              items: [
                DropdownMenuItem(
                  value: 'pt',
                  child: Text(
                    localeNotifier.getLanguageNameFromCode('pt'),
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ),
                DropdownMenuItem(
                  value: 'en',
                  child: Text(
                    localeNotifier.getLanguageNameFromCode('en'),
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ),
                DropdownMenuItem(
                  value: 'es',
                  child: Text(
                    localeNotifier.getLanguageNameFromCode('es'),
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black87,
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
            isDark: isDark,
          ),
          _buildSettingsTile(
            icon: Icons.cloud_outlined,
            title: 'Salesforce',
            subtitle: l10n.profileSalesforceConnect,
            trailing: const Icon(Icons.chevron_right, color: Colors.white54),
            onTap: () {
              context.go('/salesforce-setup');
            },
            isDark: isDark,
          ),
          _buildSettingsTile(
            icon: Icons.notifications_outlined,
            title: l10n.homeNotifications,
            subtitle: l10n.homeNoNotifications,
            trailing: DropdownButton<String>(
              value: 'Todas',
              underline: const SizedBox(),
              icon: const Icon(Icons.chevron_right, color: Colors.white54),
              dropdownColor:
                  isDark
                      ? AppTheme.darkBackground.withOpacity(0.9)
                      : Colors.white.withOpacity(0.9),
              items: [
                DropdownMenuItem(
                  value: 'Todas',
                  child: Text(
                    'Todas',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ),
                DropdownMenuItem(
                  value: 'Importantes',
                  child: Text(
                    'Importantes',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ),
                DropdownMenuItem(
                  value: 'Nenhuma',
                  child: Text(
                    'Nenhuma',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ),
              ],
              onChanged: (value) {
                // Handle notifications change
              },
            ),
            isDark: isDark,
          ),
        ], isDark),
        const SizedBox(height: AppConstants.spacing32),
        _buildSettingsSection('', [
          _buildSettingsTile(
            icon: Icons.logout,
            title: l10n.profileLogout,
            subtitle: l10n.profileEndSession,
            textColor: Colors.red,
            onTap: () => _handleLogout(context, l10n),
            isDark: isDark,
          ),
        ], isDark),
      ],
    );
  }

  Widget _buildSettingsSection(String title, List<Widget> items, bool isDark) {
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
                color:
                    isDark
                        ? Colors.white.withAlpha(128)
                        : AppTheme.foreground.withAlpha(128),
              ),
            ),
          ),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              decoration: BoxDecoration(
                color:
                    isDark
                        ? Colors.white.withAlpha(10)
                        : Colors.white.withAlpha(20),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color:
                      isDark
                          ? Colors.white.withAlpha(15)
                          : Colors.white.withAlpha(38),
                ),
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
    required bool isDark,
  }) {
    final Color defaultTextColor = isDark ? Colors.white : AppTheme.foreground;

    final Color subtitleColor =
        textColor != null
            ? Colors.red.withAlpha(179)
            : (isDark
                ? Colors.white.withAlpha(153)
                : AppTheme.foreground.withAlpha(153));

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacing16,
          vertical: AppConstants.spacing12,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color:
                  textColor ??
                  (isDark
                      ? Colors.white.withAlpha(179)
                      : AppTheme.foreground.withAlpha(179)),
              size: 24,
            ),
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
