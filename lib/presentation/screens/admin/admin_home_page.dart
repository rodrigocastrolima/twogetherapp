import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:ui';
import '../../../core/theme/theme.dart';
import '../../../core/theme/text_styles.dart';
import 'package:cloud_functions/cloud_functions.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  bool _isRunningMigration = false;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Admin Dashboard',
            style: AppTextStyles.h1.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 24),
          _buildOverviewCards(),
          const SizedBox(height: 32),
          _buildRecentActivities(),
          const SizedBox(height: 32),
          _buildSystemStatus(),
          const SizedBox(height: 32),
          _buildTemporaryMigrationSection(),
        ],
      ),
    );
  }

  Widget _buildOverviewCards() {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.2,
      children: [
        _buildStatCard(
          'Total Resellers',
          '123',
          CupertinoIcons.person_2_fill,
          Colors.blue,
        ),
        _buildStatCard(
          'Active Submissions',
          '45',
          CupertinoIcons.doc_text_fill,
          Colors.orange,
        ),
        _buildStatCard(
          'Total Revenue',
          '€ 85,420',
          CupertinoIcons.money_euro_circle_fill,
          Colors.green,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(20),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withAlpha(26), width: 0.5),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withAlpha(51),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 12),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: AppTextStyles.h2.copyWith(color: Colors.white),
                ),
              ),
              const SizedBox(height: 4),
              Flexible(
                child: Text(
                  title,
                  style: AppTextStyles.body1.copyWith(
                    color: Colors.white.withAlpha(153),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentActivities() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Activities',
          style: AppTextStyles.h3.copyWith(color: Colors.white),
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(20),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withAlpha(26),
                  width: 0.5,
                ),
              ),
              child: Column(
                children: [
                  _buildActivityItem(
                    'New Reseller Registered',
                    'Ana Silva joined as a reseller',
                    '5 minutes ago',
                    CupertinoIcons.person_badge_plus,
                    Colors.green,
                  ),
                  Divider(color: Colors.white.withAlpha(26)),
                  _buildActivityItem(
                    'Submission Approved',
                    'João Santos - Solar Commercial Proposal',
                    '1 hour ago',
                    CupertinoIcons.checkmark_circle,
                    Colors.blue,
                  ),
                  Divider(color: Colors.white.withAlpha(26)),
                  _buildActivityItem(
                    'Submission Rejected',
                    'Maria Oliveira - Wind Residential Proposal',
                    '2 hours ago',
                    CupertinoIcons.xmark_circle,
                    Colors.red,
                  ),
                  Divider(color: Colors.white.withAlpha(26)),
                  _buildActivityItem(
                    'Payment Processed',
                    'Commission payment to Carlos Lima',
                    '5 hours ago',
                    CupertinoIcons.money_euro,
                    Colors.amber,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActivityItem(
    String title,
    String description,
    String timeAgo,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withAlpha(51),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.body1.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  description,
                  style: AppTextStyles.body2.copyWith(
                    color: Colors.white.withAlpha(179),
                  ),
                ),
              ],
            ),
          ),
          Text(
            timeAgo,
            style: AppTextStyles.caption.copyWith(
              color: Colors.white.withAlpha(153),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemStatus() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'System Status',
          style: AppTextStyles.h3.copyWith(color: Colors.white),
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(20),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withAlpha(26),
                  width: 0.5,
                ),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildStatusItem('API Availability', 0.98, Colors.green),
                  const SizedBox(height: 16),
                  _buildStatusItem('Database Performance', 0.87, Colors.amber),
                  const SizedBox(height: 16),
                  _buildStatusItem('Storage Usage', 0.45, Colors.blue),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusItem(String title, double percentage, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: AppTextStyles.body1.copyWith(color: Colors.white),
            ),
            Text(
              '${(percentage * 100).toInt()}%',
              style: AppTextStyles.body1.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: percentage,
            minHeight: 10,
            backgroundColor: color.withAlpha(51),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildTemporaryMigrationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Maintenance Tools',
          style: AppTextStyles.h3.copyWith(color: Colors.white),
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(20),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withAlpha(26),
                  width: 0.5,
                ),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Database Migrations',
                    style: AppTextStyles.h4.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Run maintenance tasks and migrations on the database.',
                    style: AppTextStyles.body2.copyWith(
                      color: Colors.white.withAlpha(179),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed:
                        _isRunningMigration
                            ? null
                            : () => _runMigration(context),
                    icon:
                        _isRunningMigration
                            ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                            : const Icon(
                              CupertinoIcons.arrow_clockwise,
                              size: 18,
                            ),
                    label: Text(
                      _isRunningMigration
                          ? 'Running...'
                          : 'Create Missing Conversations',
                    ),
                    style: FilledButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.deepPurple,
                      disabledBackgroundColor: Colors.deepPurple.withOpacity(
                        0.5,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _runMigration(BuildContext context) async {
    try {
      setState(() {
        _isRunningMigration = true;
      });

      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('runMigration');
      final result = await callable.call();

      if (mounted) {
        _showMigrationResultDialog(context, result.data);
      }
    } catch (e) {
      if (mounted) {
        _showMigrationErrorDialog(context, e.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRunningMigration = false;
        });
      }
    }
  }

  void _showMigrationResultDialog(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Migration Completed', style: AppTextStyles.h3),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('The migration was completed successfully.'),
                const SizedBox(height: 16),
                Text('Results:', style: AppTextStyles.h4),
                const SizedBox(height: 8),
                Text('• Created conversations: ${data['created']}'),
                Text('• Existing conversations: ${data['existing']}'),
                Text('• Total resellers: ${data['total']}'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  void _showMigrationErrorDialog(BuildContext context, String error) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Migration Failed', style: AppTextStyles.h3),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('The migration failed with the following error:'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(error, style: const TextStyle(color: Colors.red)),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }
}
