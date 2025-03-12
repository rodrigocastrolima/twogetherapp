import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/theme.dart';
import '../../../core/utils/constants.dart';
import '../services/services_page.dart';

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
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: Color(0xFFF5F5F5),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Color(0xFFE0E0E0),
                              width: 2,
                            ),
                          ),
                        ),
                        Icon(Icons.person, size: 40, color: Color(0xFF757575)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Bernardo Ribeiro',
                  style: AppTextStyles.h2.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2C2C2C),
                  ),
                  textAlign: TextAlign.center,
                ),
                Text(
                  'bernardoribeiro55@gmail.com',
                  style: AppTextStyles.body2.copyWith(
                    color: Color(0xFF757575),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            )
          else
            // Desktop layout - horizontal with icon on left
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Color(0xFFF5F5F5),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Color(0xFFE0E0E0),
                            width: 1.5,
                          ),
                        ),
                      ),
                      Icon(Icons.person, size: 24, color: Color(0xFF757575)),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bernardo Ribeiro',
                      style: AppTextStyles.h2.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2C2C2C),
                      ),
                    ),
                    Text(
                      'bernardoribeiro55@gmail.com',
                      style: AppTextStyles.body2.copyWith(
                        color: Color(0xFF757575),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          const SizedBox(height: 32),

          // Earnings Card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 16.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.homeCommissionEarnings,
                        style: AppTextStyles.h3.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF2C2C2C),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          _isEarningsVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                          size: 20,
                          color: Color(0xFF757575),
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
                                style: AppTextStyles.h1.copyWith(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2C2C2C),
                                ),
                              )
                              : ClipRect(
                                child: ImageFiltered(
                                  imageFilter: ColorFilter.mode(
                                    Colors.grey.shade200,
                                    BlendMode.srcOut,
                                  ),
                                  child: Text(
                                    '€ 5.500,00',
                                    style: AppTextStyles.h1.copyWith(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.transparent,
                                      shadows: [
                                        Shadow(
                                          color: Colors.grey.shade300,
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
                    onPressed: () {
                      // TODO: Navigate to detailed dashboard
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Text(
                      l10n.homeViewDetails,
                      style: AppTextStyles.body2.copyWith(
                        color: Theme.of(context).primaryColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Services Button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ServicesPage()),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.charcoal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  vertical: 20,
                  horizontal: 24,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.add_circle_outline, size: 24),
              label: Text(
                l10n.homeServices,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Notifications Panel
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12.0,
                    horizontal: 20.0,
                  ),
                  child: Center(
                    child: Text(
                      l10n.homeNotifications,
                      style: AppTextStyles.h3.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF2C2C2C),
                      ),
                    ),
                  ),
                ),
                Divider(height: 1, color: Colors.grey.shade200),
                _buildNotificationItem(
                  l10n.homeNotificationMeeting,
                  l10n.homeNotificationMeetingDesc,
                  Icons.calendar_today,
                ),
                _buildNotificationItem(
                  l10n.homeNotificationRequest,
                  l10n.homeNotificationRequestDesc,
                  Icons.business_center,
                ),
                _buildNotificationItem(
                  l10n.homeNotificationPayment,
                  l10n.homeNotificationPaymentDesc,
                  Icons.payments,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(String title, String subtitle, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: Color(0xFF757575), size: 22),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: Color(0xFF2C2C2C),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 13, color: Color(0xFF757575)),
      ),
      onTap: () {
        // TODO: Handle notification tap
      },
    );
  }
}
