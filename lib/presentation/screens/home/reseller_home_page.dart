import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/theme.dart';
import '../services/services_page.dart';
import '../../screens/notifications/rejection_details_page.dart';
import '../dashboard/dashboard_page.dart';
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
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(24.0, 32.0, 24.0, 32.0),
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
                        color: Colors.white.withAlpha(25),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(13),
                          blurRadius: 10,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.white.withAlpha(38),
                      child: Icon(
                        CupertinoIcons.person_fill,
                        size: 36,
                        color: AppTheme.foreground.withAlpha(204),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Bernardo Ribeiro',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.foreground,
                    fontSize: 28,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'bernardo.ribeiro@mail.com',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.foreground.withAlpha(178),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          const SizedBox(height: 40),

          // Section Title - Earnings
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              'Resumo Financeiro',
              style: TextStyle(
                fontFamily: '.SF Pro Display',
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppTheme.foreground,
                letterSpacing: -0.5,
              ),
            ),
          ),

          // Earnings Card
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                    width: 0.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
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
                            fontFamily: '.SF Pro Display',
                            fontSize: 17,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.foreground.withOpacity(0.9),
                            letterSpacing: -0.2,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _isEarningsVisible = !_isEarningsVisible;
                            });
                          },
                          child: Icon(
                            _isEarningsVisible
                                ? CupertinoIcons.eye_fill
                                : CupertinoIcons.eye_slash_fill,
                            size: 20,
                            color: AppTheme.foreground.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
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
                                    fontFamily: '.SF Pro Display',
                                    fontSize: 34,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.foreground,
                                    letterSpacing: -0.5,
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
                                        fontFamily: '.SF Pro Display',
                                        fontSize: 34,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.transparent,
                                        letterSpacing: -0.5,
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
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap:
                          () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const DashboardPage(),
                            ),
                          ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Ver Detalhes',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.primary,
                              letterSpacing: -0.1,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            CupertinoIcons.chevron_right,
                            size: 14,
                            color: AppTheme.primary,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),

          // Section Title - Actions
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              'Ações Rápidas',
              style: TextStyle(
                fontFamily: '.SF Pro Display',
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppTheme.foreground,
                letterSpacing: -0.5,
              ),
            ),
          ),

          // Quick Actions
          _buildQuickActions(),

          const SizedBox(height: 40),

          // Section Title - Notifications
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                Text(
                  'Notificações',
                  style: TextStyle(
                    fontFamily: '.SF Pro Display',
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.foreground,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: AppTheme.destructive,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '4',
                      style: TextStyle(
                        fontFamily: '.SF Pro Text',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          ..._buildNotificationItems(),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Center(
        child: _buildActionButton(
          'Novo Serviço',
          CupertinoIcons.add,
          onTap:
              () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const ServicesPage())),
          color: AppTheme.primary,
        ),
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon, {
    Color? color,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: 100,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(20),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withAlpha(25), width: 0.5),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: (color ?? AppTheme.primary).withAlpha(38),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color ?? AppTheme.primary, size: 20),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.foreground.withAlpha(178),
                    letterSpacing: -0.2,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildNotificationItems() {
    final notifications = [
      {
        'title': 'Submission Rejected',
        'description':
            'Your solar commercial submission TR003_0001 was rejected',
        'type': 'rejection',
        'data': {
          'submissionId': 'TR003_0001',
          'rejectionReason':
              'The invoice image is not clear enough. Please provide a higher quality image where all text and numbers are clearly legible.',
          'rejectionDate': DateTime.now(),
          'isPermanentRejection': false,
        },
      },
      {
        'title': 'Permanent Rejection',
        'description': 'Your submission SUB67890 has been permanently rejected',
        'type': 'rejection',
        'data': {
          'submissionId': 'SUB67890',
          'rejectionReason':
              'Invalid business registration number. This submission has been permanently rejected and cannot be resubmitted.',
          'rejectionDate': DateTime.now(),
          'isPermanentRejection': true,
        },
      },
      {
        'title': 'Reunião Agendada',
        'description': 'Você tem uma reunião agendada para hoje às 14h',
        'type': 'calendar',
      },
      {
        'title': 'Nova Solicitação de Serviço',
        'description': 'Uma nova solicitação de serviço requer sua atenção',
        'type': 'service',
      },
      {
        'title': 'Pagamento Recebido',
        'description': 'O pagamento da comissão foi processado',
        'type': 'payment',
      },
      {
        'title': 'Nova Proposta',
        'description':
            'A proposta para João Silva foi enviada e aguarda aprovação.',
        'type': 'proposal',
      },
    ];

    return notifications.map((notification) {
      IconData icon;
      Color iconColor;

      switch (notification['type']) {
        case 'rejection':
          icon = CupertinoIcons.exclamationmark_triangle_fill;
          iconColor = AppTheme.destructive;
          break;
        case 'calendar':
          icon = CupertinoIcons.calendar;
          iconColor = const Color(0xFF0A84FF);
          break;
        case 'service':
          icon = CupertinoIcons.doc_text_fill;
          iconColor = const Color(0xFF5856D6);
          break;
        case 'payment':
          icon = CupertinoIcons.money_dollar_circle_fill;
          iconColor = const Color(0xFF34C759);
          break;
        case 'proposal':
          icon = Icons.description_outlined;
          iconColor = Colors.blue;
          break;
        default:
          icon = CupertinoIcons.info;
          iconColor = Colors.orange;
      }

      return _buildNotificationItem(
        icon: icon,
        title: notification['title'] as String,
        description: notification['description'] as String,
        iconColor: iconColor,
        onTap:
            notification['type'] == 'rejection'
                ? () {
                  final data = notification['data'] as Map<String, dynamic>;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => RejectionDetailsPage(
                            submissionId: data['submissionId'],
                            rejectionReason: data['rejectionReason'],
                            rejectionDate: data['rejectionDate'],
                            isPermanentRejection: data['isPermanentRejection'],
                          ),
                    ),
                  );
                }
                : null,
      );
    }).toList();
  }

  Widget _buildNotificationItem({
    required IconData icon,
    required String title,
    required String description,
    VoidCallback? onTap,
    Color? iconColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                  width: 0.5,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: (iconColor ?? AppTheme.primary).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon,
                      color: iconColor ?? AppTheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontFamily: '.SF Pro Text',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.foreground,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: TextStyle(
                            fontFamily: '.SF Pro Text',
                            fontSize: 14,
                            color: AppTheme.foreground.withOpacity(0.7),
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    CupertinoIcons.chevron_right,
                    size: 16,
                    color: AppTheme.foreground.withOpacity(0.4),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
