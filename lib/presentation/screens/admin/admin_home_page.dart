import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:ui';
import 'dart:math' as math;
import '../../../core/theme/theme.dart';
import '../../../core/theme/text_styles.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../../features/salesforce/data/services/salesforce_user_sync_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  bool _isRunningMigration = false;
  bool _isRunningSalesforceSync = false;
  bool _isSalesforceDryRun = true;
  Map<String, dynamic>? _lastSyncResult;

  final SalesforceUserSyncService _salesforceService =
      SalesforceUserSyncService();

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
          const SizedBox(height: 32),
          _buildSalesforceIntegrationSection(context),
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
                            : const Icon(Icons.hourglass_empty, size: 18),
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

  Widget _buildSalesforceIntegrationSection(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // State for this section
    bool isRunning = false;
    bool isDryRun = true;
    String? resultMessage;

    return StatefulBuilder(
      builder: (context, setState) {
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title and description
                Text(
                  'Salesforce Integration',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.salesforceIntegrationDescription,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),

                // Platform info
                if (!Platform.isWindows)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primaryContainer.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "PowerShell scripts run on Windows. On this platform, we'll use direct API calls instead.",
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),

                // Check Available Fields Button
                TextButton.icon(
                  onPressed:
                      isRunning
                          ? null
                          : () async {
                            setState(() {
                              isRunning = true;
                              resultMessage = null;
                            });

                            try {
                              // Show a progress indicator
                              if (context.mounted) {
                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (BuildContext ctx) {
                                    return AlertDialog(
                                      title: const Text(
                                        'Checking Salesforce Fields',
                                      ),
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const CircularProgressIndicator(),
                                          const SizedBox(height: 16),
                                          const Text(
                                            'Retrieving available fields from Salesforce...',
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              }

                              // Get available fields
                              final salesforceService =
                                  SalesforceUserSyncService();
                              if (!await salesforceService.initialize()) {
                                throw Exception(
                                  'Failed to initialize Salesforce connection',
                                );
                              }

                              final fields =
                                  await salesforceService
                                      .getFieldInfoForUserObject();

                              // Close the dialog
                              if (context.mounted) {
                                Navigator.pop(context);
                              }

                              if (fields == null) {
                                throw Exception(
                                  'Failed to retrieve field information',
                                );
                              }

                              // Display the fields
                              if (context.mounted) {
                                final standardFields =
                                    fields
                                        .where((f) => !(f['custom'] as bool))
                                        .map((f) => f['name'] as String)
                                        .toList()
                                      ..sort();
                                final customFields =
                                    fields
                                        .where((f) => f['custom'] as bool)
                                        .map((f) => f['name'] as String)
                                        .toList()
                                      ..sort();

                                setState(() {
                                  resultMessage =
                                      'Available Salesforce Fields:\n\n'
                                      'Standard Fields:\n${standardFields.join(', ')}\n\n'
                                      'Custom Fields:\n${customFields.join(', ')}';
                                });
                              }
                            } catch (e) {
                              // Close the dialog if it's open
                              if (context.mounted) {
                                try {
                                  Navigator.pop(context);
                                } catch (_) {
                                  // Dialog might not be open
                                }
                              }

                              if (context.mounted) {
                                setState(() {
                                  resultMessage = 'Error checking fields: $e';
                                });
                              }
                            } finally {
                              if (mounted) {
                                setState(() {
                                  isRunning = false;
                                });
                              }
                            }
                          },
                  icon: const Icon(Icons.list),
                  label: const Text('Check Available Salesforce Fields'),
                ),
                const SizedBox(height: 16),

                // Dry Run Switch
                Row(
                  children: [
                    Text(
                      'Dry Run Mode (Preview Only)',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const Spacer(),
                    Switch(
                      value: isDryRun,
                      onChanged:
                          isRunning
                              ? null
                              : (value) {
                                setState(() {
                                  isDryRun = value;
                                });
                              },
                    ),
                  ],
                ),

                // Run Button
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed:
                      isRunning
                          ? null
                          : () async {
                            setState(() {
                              isRunning = true;
                              resultMessage = null;
                            });

                            // Dialog context to safely dismiss dialogs
                            BuildContext? dialogContext;

                            try {
                              // Show a progress dialog
                              if (context.mounted) {
                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (BuildContext ctx) {
                                    dialogContext = ctx;
                                    return AlertDialog(
                                      title: const Text(
                                        'Syncing Salesforce Data',
                                      ),
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const CircularProgressIndicator(),
                                          const SizedBox(height: 16),
                                          Text(
                                            isDryRun
                                                ? 'Running in Dry Run mode - no changes will be made'
                                                : 'Syncing user data from Salesforce...',
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              }

                              // Different implementations based on platform
                              if (Platform.isWindows) {
                                // Windows implementation using PowerShell
                                final scriptPath = path.join(
                                  Directory.current.path,
                                  'lib',
                                  'scripts',
                                  'Sync-SalesforceUserToFirebase.ps1',
                                );

                                // Prepare the PowerShell command
                                final command = 'powershell.exe';
                                final args = [
                                  '-ExecutionPolicy',
                                  'Bypass',
                                  '-File',
                                  scriptPath,
                                  '-All',
                                  '-FieldsOnly',
                                  'Revendedor_Retail__c',
                                  if (isDryRun) '-DryRun',
                                ];

                                if (kDebugMode) {
                                  print(
                                    'Running command: $command ${args.join(' ')}',
                                  );
                                }

                                // Run the PowerShell script
                                final process = await Process.run(
                                  command,
                                  args,
                                  workingDirectory: Directory.current.path,
                                  runInShell: true,
                                );

                                // Close the progress dialog
                                if (dialogContext != null && context.mounted) {
                                  Navigator.of(dialogContext!).pop();
                                }

                                // Check result
                                if (process.exitCode == 0) {
                                  setState(() {
                                    resultMessage =
                                        'Sync completed successfully.\n\n'
                                        'Output:\n${process.stdout}';
                                  });
                                } else {
                                  setState(() {
                                    resultMessage =
                                        'Error during sync.\n\n'
                                        'Error output:\n${process.stderr}\n\n'
                                        'Standard output:\n${process.stdout}';
                                  });
                                }
                              } else {
                                // Mobile/other platforms implementation using direct API calls
                                Map<String, dynamic>? result;
                                Exception? syncException;

                                try {
                                  // We do the actual work inside a separate try-catch
                                  result = await _syncUsersDirectly(isDryRun);
                                } catch (e) {
                                  syncException = Exception(
                                    'Error during sync: $e',
                                  );
                                }

                                // Close the progress dialog - do this regardless of success or failure
                                if (dialogContext != null && context.mounted) {
                                  Navigator.of(dialogContext!).pop();
                                }

                                // Update the state only after the dialog is closed
                                if (context.mounted) {
                                  setState(() {
                                    if (syncException != null) {
                                      resultMessage = syncException.toString();
                                    } else if (result != null) {
                                      resultMessage =
                                          'Sync completed successfully.\n\n'
                                          'Results:\n'
                                          '- Users processed: ${result['usersProcessed']}\n'
                                          '- Successful syncs: ${result['successCount']}\n'
                                          '- Failed syncs: ${result['failCount']}\n\n'
                                          '${isDryRun ? "(Dry run - no changes were made)" : ""}';
                                    } else {
                                      resultMessage =
                                          'Unknown error occurred during sync';
                                    }
                                  });
                                }
                              }
                            } catch (e) {
                              // Close the progress dialog if it's still open
                              if (dialogContext != null && context.mounted) {
                                try {
                                  Navigator.of(dialogContext!).pop();
                                } catch (_) {
                                  // Ignore if dialog is not open
                                }
                              }

                              if (context.mounted) {
                                setState(() {
                                  resultMessage = 'Exception running sync: $e';
                                });
                              }
                            } finally {
                              if (mounted) {
                                setState(() {
                                  isRunning = false;
                                });
                              }
                            }
                          },
                  icon: Icon(isRunning ? Icons.hourglass_empty : Icons.sync),
                  label: Text(
                    isRunning
                        ? 'Running...'
                        : isDryRun
                        ? 'Run Sync (Preview Only)'
                        : 'Run Sync',
                  ),
                ),

                // Result display
                if (resultMessage != null) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    'Result:',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    width: double.infinity,
                    child: SingleChildScrollView(
                      child: SelectableText(
                        resultMessage!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // Direct implementation of user sync functionality for mobile platforms
  // This method only handles the data operations - UI updates are done in the calling method
  Future<Map<String, dynamic>> _syncUsersDirectly(bool dryRun) async {
    int usersProcessed = 0;
    int successCount = 0;
    int failCount = 0;

    // Initialize SalesforceUserSyncService
    final salesforceService = SalesforceUserSyncService();
    final initialized = await salesforceService.initialize();

    if (!initialized) {
      throw Exception("Failed to initialize Salesforce connection");
    }

    if (kDebugMode) {
      print('Salesforce service initialized successfully');
    }

    // Find users with Salesforce IDs that need syncing
    final usersToSync =
        await salesforceService.findUsersNeedingSalesforceSync();
    usersProcessed = usersToSync.length;

    if (kDebugMode) {
      print('Found $usersProcessed users that need syncing');
    }

    if (usersToSync.isEmpty) {
      return {
        'usersProcessed': 0,
        'successCount': 0,
        'failCount': 0,
        'message': 'No users found that need syncing',
      };
    }

    // If this is a dry run, just return the count
    if (dryRun) {
      return {
        'usersProcessed': usersProcessed,
        'successCount': 0,
        'failCount': 0,
        'message':
            'Dry run completed. Found $usersProcessed users that would be synced.',
      };
    }

    // Otherwise, perform the actual sync
    for (final user in usersToSync) {
      try {
        final firebaseUserId = user['firebaseUserId'];
        final salesforceId = user['salesforceId'];

        if (firebaseUserId == null || salesforceId == null) {
          failCount++;
          continue;
        }

        final success = await salesforceService.syncSalesforceUserToFirebase(
          firebaseUserId,
          salesforceId,
        );

        if (success) {
          successCount++;
        } else {
          failCount++;
        }
      } catch (e) {
        failCount++;
        if (kDebugMode) {
          print('Error syncing user: $e');
        }
      }
    }

    return {
      'usersProcessed': usersProcessed,
      'successCount': successCount,
      'failCount': failCount,
      'message': 'Sync completed.',
    };
  }
}
