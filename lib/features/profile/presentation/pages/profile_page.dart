import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui';
import '../../../../core/theme/theme.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/utils/constants.dart';
import '../controllers/profile_controller.dart';
import '../../domain/entities/profile.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(profileControllerProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacing16,
        vertical: AppConstants.spacing24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Perfil',
            style: AppTextStyles.h2.copyWith(
              color: AppTheme.foreground,
              fontSize: 32,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppConstants.spacing24),
          profileState.when(
            data: (profile) => _buildProfileCard(context, profile),
            loading: () => const Center(child: CircularProgressIndicator()),
            error:
                (error, stackTrace) => Center(
                  child: Text(
                    'Erro: ${error.toString()}',
                    style: TextStyle(color: AppTheme.foreground),
                  ),
                ),
          ),
          const SizedBox(height: AppConstants.spacing32),
          _buildSettingsMenu(context),
        ],
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context, Profile profile) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.all(AppConstants.spacing16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.15)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: AppTheme.primary.withOpacity(0.12),
                child: Text(
                  profile.name.substring(0, 1).toUpperCase(),
                  style: TextStyle(
                    fontSize: 24,
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: AppConstants.spacing16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name,
                      style: AppTextStyles.h2.copyWith(
                        color: AppTheme.foreground,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      profile.email,
                      style: AppTextStyles.body2.copyWith(
                        color: AppTheme.foreground.withOpacity(0.6),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: AppConstants.spacing12),
                    Row(
                      children: [
                        _buildStatItem('${profile.totalClients}', 'Total'),
                        const SizedBox(width: AppConstants.spacing16),
                        _buildStatItem('${profile.activeClients}', 'Ativos'),
                        const SizedBox(width: AppConstants.spacing16),
                        _buildStatItem(
                          '${profile.registrationDate.day}/${profile.registrationDate.month}/${profile.registrationDate.year}',
                          'Desde',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppTheme.foreground,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.foreground.withOpacity(0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsMenu(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Configurações',
          style: AppTextStyles.h2.copyWith(
            color: AppTheme.foreground,
            fontSize: 28,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppConstants.spacing24),
        _buildSettingsSection('Conta', [
          _buildSettingsTile(
            icon: Icons.dashboard_outlined,
            title: 'Dashboard',
            subtitle: 'Informações do revendedor',
            trailing: const Icon(Icons.chevron_right, color: Colors.white54),
            onTap: () {
              // Navigate to dashboard
            },
          ),
          _buildSettingsTile(
            icon: Icons.lock_outline,
            title: 'Alterar Senha',
            subtitle: 'Atualizar sua senha',
            trailing: const Icon(Icons.chevron_right, color: Colors.white54),
            onTap: () {
              // Handle password change
            },
          ),
        ]),
        const SizedBox(height: AppConstants.spacing32),
        _buildSettingsSection('Preferências', [
          _buildSettingsTile(
            icon: Icons.palette_outlined,
            title: 'Tema',
            subtitle: 'Claro ou escuro',
            trailing: DropdownButton<String>(
              value: 'Claro',
              underline: const SizedBox(),
              icon: const Icon(Icons.chevron_right, color: Colors.white54),
              items: const [
                DropdownMenuItem(value: 'Claro', child: Text('Claro')),
                DropdownMenuItem(value: 'Escuro', child: Text('Escuro')),
              ],
              onChanged: (value) {
                // Handle theme change
              },
            ),
          ),
          _buildSettingsTile(
            icon: Icons.language,
            title: 'Idioma',
            subtitle: 'Português',
            trailing: DropdownButton<String>(
              value: 'Português',
              underline: const SizedBox(),
              icon: const Icon(Icons.chevron_right, color: Colors.white54),
              items: const [
                DropdownMenuItem(value: 'Português', child: Text('Português')),
                DropdownMenuItem(value: 'English', child: Text('English')),
                DropdownMenuItem(value: 'Español', child: Text('Español')),
              ],
              onChanged: (value) {
                // Handle language change
              },
            ),
          ),
          _buildSettingsTile(
            icon: Icons.notifications_outlined,
            title: 'Notificações',
            subtitle: 'Configurar alertas',
            trailing: DropdownButton<String>(
              value: 'Todas',
              underline: const SizedBox(),
              icon: const Icon(Icons.chevron_right, color: Colors.white54),
              items: const [
                DropdownMenuItem(value: 'Todas', child: Text('Todas')),
                DropdownMenuItem(
                  value: 'Importantes',
                  child: Text('Importantes'),
                ),
                DropdownMenuItem(value: 'Nenhuma', child: Text('Nenhuma')),
              ],
              onChanged: (value) {
                // Handle notifications change
              },
            ),
          ),
        ]),
        const SizedBox(height: AppConstants.spacing32),
        _buildSettingsSection('', [
          _buildSettingsTile(
            icon: Icons.logout,
            title: 'Sair',
            subtitle: 'Encerrar sessão',
            textColor: Colors.red,
            onTap: () {
              // Handle logout
            },
          ),
        ]),
      ],
    );
  }

  Widget _buildSettingsSection(String title, List<Widget> items) {
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
                color: AppTheme.foreground.withOpacity(0.5),
              ),
            ),
          ),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.15)),
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
  }) {
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
              color: textColor ?? AppTheme.foreground.withOpacity(0.7),
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
                      color: textColor ?? AppTheme.foreground,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color:
                          textColor != null
                              ? Colors.red.withOpacity(0.7)
                              : AppTheme.foreground.withOpacity(0.6),
                    ),
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
