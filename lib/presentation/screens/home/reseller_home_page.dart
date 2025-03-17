import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/theme.dart';
import '../services/services_page.dart';
import 'dart:ui';

class ResellerHomePage extends StatefulWidget {
  const ResellerHomePage({super.key});

  @override
  State<ResellerHomePage> createState() => _ResellerHomePageState();
}

class _ResellerHomePageState extends State<ResellerHomePage> {
  bool _isEarningsVisible = false;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final bool isSmallScreen = width < 600;

    return _buildMainContent(isSmallScreen);
  }

  Widget _buildMainContent(bool isSmallScreen) {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24.0,
        24.0,
        isSmallScreen ? 24.0 : 16.0,
        24.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Reseller Info and Settings (Web)
          if (isSmallScreen)
            // Mobile layout - centered with icon on top
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Center(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 2,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.white.withOpacity(0.1),
                      child: Icon(
                        Icons.person,
                        size: 40,
                        color: AppTheme.foreground,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Bernardo Ribeiro',
                  style: AppTextStyles.h2.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.foreground,
                    fontSize: 28,
                  ),
                  textAlign: TextAlign.center,
                ),
                Text(
                  'bernardoribeiro55@gmail.com',
                  style: AppTextStyles.body2.copyWith(
                    color: AppTheme.foreground.withOpacity(0.7),
                    fontSize: 15,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          const SizedBox(height: 32),

          // Earnings Card
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Ganhos em Comissões',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.foreground,
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            _isEarningsVisible
                                ? Icons.visibility
                                : Icons.visibility_off,
                            size: 20,
                            color: AppTheme.foreground.withOpacity(0.5),
                          ),
                          onPressed: () {
                            setState(() {
                              _isEarningsVisible = !_isEarningsVisible;
                            });
                          },
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _isEarningsVisible = !_isEarningsVisible;
                        });
                      },
                      child: SizedBox(
                        height: 48,
                        child:
                            _isEarningsVisible
                                ? Text(
                                  '€ 5.500,00',
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.foreground,
                                  ),
                                )
                                : ClipRect(
                                  child: ImageFiltered(
                                    imageFilter: ColorFilter.mode(
                                      AppTheme.foreground.withOpacity(0.5),
                                      BlendMode.srcOut,
                                    ),
                                    child: Text(
                                      '€ 5.500,00',
                                      style: TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.transparent,
                                        shadows: [
                                          Shadow(
                                            color: AppTheme.foreground
                                                .withOpacity(0.5),
                                            blurRadius: 16,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                      ),
                    ),
                    TextButton(
                      onPressed:
                          () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ServicesPage(),
                            ),
                          ),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        foregroundColor: AppTheme.foreground.withOpacity(0.7),
                      ),
                      child: Text('Ver Detalhes'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Add New Service Button
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap:
                      () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ServicesPage()),
                      ),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.primary.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_circle_outline,
                          color: AppTheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Adicionar Novo Serviço',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Notifications Section
          Text(
            'Notificações',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppTheme.foreground,
            ),
          ),
          const SizedBox(height: 16),
          ..._buildNotificationItems(),
        ],
      ),
    );
  }

  List<Widget> _buildNotificationItems() {
    return [
      _buildNotificationItem(
        icon: Icons.calendar_today,
        title: 'Reunião Agendada',
        description: 'Você tem uma reunião agendada para hoje às 14h',
      ),
      _buildNotificationItem(
        icon: Icons.assignment,
        title: 'Nova Solicitação de Serviço',
        description: 'Uma nova solicitação de serviço requer sua atenção',
      ),
      _buildNotificationItem(
        icon: Icons.payment,
        title: 'Pagamento Recebido',
        description: 'O pagamento da comissão foi processado',
      ),
    ];
  }

  Widget _buildNotificationItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: AppTheme.primary, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.foreground,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.foreground.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
