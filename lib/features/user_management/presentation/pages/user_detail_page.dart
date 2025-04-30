import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui';
import 'package:intl/intl.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/theme/theme.dart';
import '../../../../features/auth/domain/models/app_user.dart';
import '../../../../features/auth/domain/repositories/auth_repository.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../features/opportunity/data/models/salesforce_opportunity.dart';
import '../../../../features/salesforce/presentation/providers/salesforce_providers.dart';
// Import commented out due to missing file:
// import '../../../../features/admin/presentation/widgets/submission_details_dialog.dart';

class UserDetailPage extends ConsumerStatefulWidget {
  final AppUser user;

  const UserDetailPage({Key? key, required this.user}) : super(key: key);

  @override
  ConsumerState<UserDetailPage> createState() => _UserDetailPageState();
}

class _UserDetailPageState extends ConsumerState<UserDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isEditing = false;
  bool _isLoading = false;
  String? _errorMessage;

  // Controllers for editable fields
  late TextEditingController _displayNameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _departmentController;

  // Additional data
  Map<String, dynamic> _additionalData = {};
  bool _isEnabled = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _displayNameController = TextEditingController(
      text: widget.user.displayName ?? '',
    );
    _emailController = TextEditingController(text: widget.user.email);
    _phoneController = TextEditingController(
      text: widget.user.additionalData['phoneNumber'] ?? '',
    );
    _departmentController = TextEditingController(
      text: widget.user.additionalData['department'] ?? '',
    );
    _additionalData = Map<String, dynamic>.from(widget.user.additionalData);
    _isEnabled = widget.user.additionalData['isEnabled'] ?? true;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _displayNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _departmentController.dispose();
    super.dispose();
  }

  // Save user profile changes
  Future<void> _saveUserProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final firestore = FirebaseFirestore.instance;

      // Update user data in Firestore
      await firestore.collection('users').doc(widget.user.uid).update({
        'displayName': _displayNameController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
        'department': _departmentController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Email requires Firebase Auth update - typically done through Cloud Functions
      if (_emailController.text.trim() != widget.user.email) {
        // In a real app, you'd call a Cloud Function to update the email
        // For now, just update the Firestore record
        await firestore.collection('users').doc(widget.user.uid).update({
          'email': _emailController.text.trim(),
        });
      }

      // Refresh additional data
      final updatedDoc =
          await firestore.collection('users').doc(widget.user.uid).get();
      setState(() {
        _additionalData = updatedDoc.data() ?? {};
        _isEditing = false;
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error updating profile: ${e.toString()}';
      });
    }
  }

  // Toggle user enabled/disabled status
  Future<void> _toggleUserStatus() async {
    final newStatus = !_isEnabled;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authRepo = ref.read(authRepositoryProvider);
      await authRepo.setUserEnabled(widget.user.uid, newStatus);

      setState(() {
        _isEnabled = newStatus;
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'User ${newStatus ? "enabled" : "disabled"} successfully',
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error updating user status: ${e.toString()}';
      });
    }
  }

  // Reset user password
  Future<void> _resetPassword() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authRepo = ref.read(authRepositoryProvider);
      await authRepo.sendPasswordResetEmail(widget.user.email);

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password reset email sent')),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error sending password reset: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Get screen size to determine layout
    final Size screenSize = MediaQuery.of(context).size;
    final bool isSmallScreen = screenSize.width < 700;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.adminUserManagement),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
              tooltip: l10n.commonEdit,
            )
          else
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _isLoading ? null : _saveUserProfile,
              tooltip: l10n.commonSave,
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: l10n.profilePersonalInfo),
            Tab(text: 'Opportunities'),
          ],
        ),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                controller: _tabController,
                children: [
                  // Profile Tab
                  _buildProfileTab(context, isSmallScreen, l10n),

                  // Opportunities (Submissions) Tab - Now Salesforce Opportunities
                  _buildOpportunitiesTab(context),
                ],
              ),
    );
  }

  Widget _buildProfileTab(
    BuildContext context,
    bool isSmallScreen,
    AppLocalizations l10n,
  ) {
    return Padding(
      padding: EdgeInsets.all(isSmallScreen ? 16.0 : 24.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Error message if any
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // User header with avatar and name
            Card(
              margin: EdgeInsets.zero,
              color: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    CircleAvatar(
                      backgroundColor:
                          widget.user.role == UserRole.admin
                              ? Theme.of(context).colorScheme.secondary
                              : Theme.of(context).colorScheme.primary,
                      radius: 48,
                      child: Text(
                        _displayNameController.text.isNotEmpty
                            ? _displayNameController.text[0].toUpperCase()
                            : _emailController.text.isNotEmpty
                            ? _emailController.text[0].toUpperCase()
                            : l10n.userInitialsDefault,
                        style: Theme.of(
                          context,
                        ).textTheme.headlineMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _isEditing
                        ? TextField(
                          controller: _displayNameController,
                          decoration: InputDecoration(
                            labelText: 'Display Name',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        )
                        : Text(
                          _displayNameController.text.isNotEmpty
                              ? _displayNameController.text
                              : l10n.unknownUser,
                          style: Theme.of(
                            context,
                          ).textTheme.headlineSmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: (widget.user.role == UserRole.admin
                                    ? Theme.of(context).colorScheme.secondary
                                    : Theme.of(context).colorScheme.primary)
                                .withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            widget.user.role == UserRole.admin
                                ? 'Admin'
                                : 'Reseller',
                            style: Theme.of(
                              context,
                            ).textTheme.labelLarge?.copyWith(
                              color:
                                  widget.user.role == UserRole.admin
                                      ? Theme.of(context).colorScheme.secondary
                                      : Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (!_isEnabled) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.error.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              l10n.inactive,
                              style: Theme.of(
                                context,
                              ).textTheme.labelLarge?.copyWith(
                                color: Theme.of(context).colorScheme.error,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // User information
            Text(
              l10n.profilePersonalInfo,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Theme.of(context).colorScheme.onBackground,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Card(
              margin: EdgeInsets.zero,
              color: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _isEditing
                        ? _buildEditableInfoItem(
                          context,
                          icon: Icons.email_outlined,
                          label: 'Email',
                          controller: _emailController,
                        )
                        : _buildInfoItem(
                          context,
                          icon: Icons.email_outlined,
                          label: 'Email',
                          value: _emailController.text,
                        ),
                    const Divider(),
                    _isEditing
                        ? _buildEditableInfoItem(
                          context,
                          icon: Icons.phone_outlined,
                          label: l10n.loginUsername,
                          controller: _phoneController,
                        )
                        : _buildInfoItem(
                          context,
                          icon: Icons.phone_outlined,
                          label: l10n.loginUsername,
                          value:
                              _phoneController.text.isNotEmpty
                                  ? _phoneController.text
                                  : 'N/A',
                        ),
                    const Divider(),
                    _isEditing
                        ? _buildEditableInfoItem(
                          context,
                          icon: Icons.business_outlined,
                          label: 'Department',
                          controller: _departmentController,
                        )
                        : _buildInfoItem(
                          context,
                          icon: Icons.business_outlined,
                          label: 'Department',
                          value:
                              _departmentController.text.isNotEmpty
                                  ? _departmentController.text
                                  : 'N/A',
                        ),
                    const Divider(),
                    _buildInfoItem(
                      context,
                      icon: Icons.calendar_today,
                      label: l10n.commonDate,
                      value: _formatDate(_additionalData['createdAt']),
                    ),
                    const Divider(),
                    _buildInfoItem(
                      context,
                      icon: Icons.login,
                      label: 'Last Login',
                      value: _formatDate(_additionalData['lastLoginAt']),
                    ),
                    const Divider(),
                    _buildInfoItem(
                      context,
                      icon: Icons.sync,
                      label: 'Salesforce ID',
                      value: _additionalData['salesforceId'] ?? 'Not linked',
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Business information for resellers
            if (widget.user.role == UserRole.reseller) ...[
              Text(
                'Business Information',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onBackground,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Card(
                margin: EdgeInsets.zero,
                color: Theme.of(context).colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      _buildInfoItem(
                        context,
                        icon: Icons.business,
                        label: 'Company Name',
                        value: _additionalData['companyName'] ?? 'N/A',
                      ),
                      const Divider(),
                      _buildInfoItem(
                        context,
                        icon: Icons.location_on_outlined,
                        label: 'Company Address',
                        value: _additionalData['companyAddress'] ?? 'N/A',
                      ),
                      const Divider(),
                      _buildInfoItem(
                        context,
                        icon: Icons.numbers,
                        label: 'Tax ID',
                        value: _additionalData['taxId'] ?? 'N/A',
                      ),
                      const Divider(),
                      _buildInfoItem(
                        context,
                        icon: Icons.assignment_ind_outlined,
                        label: 'Company Registration',
                        value: _additionalData['companyRegistration'] ?? 'N/A',
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Performance metrics for resellers
              Text(
                'Performance Metrics',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onBackground,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Card(
                margin: EdgeInsets.zero,
                color: Theme.of(context).colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      _buildInfoItem(
                        context,
                        icon: Icons.groups_outlined,
                        label: 'Total Clients',
                        value:
                            _additionalData['totalClients']?.toString() ?? '0',
                      ),
                      const Divider(),
                      _buildInfoItem(
                        context,
                        icon: Icons.check_circle_outline,
                        label: 'Successful Submissions',
                        value:
                            _additionalData['successfulSubmissions']
                                ?.toString() ??
                            '0',
                      ),
                      const Divider(),
                      _buildInfoItem(
                        context,
                        icon: Icons.pending_actions_outlined,
                        label: 'Pending Submissions',
                        value:
                            _additionalData['pendingSubmissions']?.toString() ??
                            '0',
                      ),
                      const Divider(),
                      _buildInfoItem(
                        context,
                        icon: Icons.paid_outlined,
                        label: 'Total Revenue',
                        value: _formatCurrency(_additionalData['totalRevenue']),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Actions
            Text(
              l10n.clientsFilterAction,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Theme.of(context).colorScheme.onBackground,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Card(
              margin: EdgeInsets.zero,
              color: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(
                      Icons.password,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: Text(
                      l10n.profileChangePassword,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: _resetPassword,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(
                      _isEnabled ? Icons.block : Icons.check_circle,
                      color:
                          _isEnabled
                              ? Theme.of(context).colorScheme.error
                              : Theme.of(context).colorScheme.secondary,
                    ),
                    title: Text(
                      _isEnabled ? l10n.inactive : l10n.active,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: _toggleUserStatus,
                  ),
                  // Add reseller-specific actions
                  if (widget.user.role == UserRole.reseller) ...[
                    const Divider(height: 1),
                    ListTile(
                      leading: Icon(
                        Icons.message_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title: Text(
                        'View Messages',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        // TODO: Navigate to reseller messages
                        if (kDebugMode) {
                          print(
                            'View messages for reseller: ${widget.user.uid}',
                          );
                        }
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: Icon(
                        Icons.people_outline,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title: Text(
                        'View Clients',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        // TODO: Navigate to reseller clients
                        if (kDebugMode) {
                          print(
                            'View clients for reseller: ${widget.user.uid}',
                          );
                        }
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOpportunitiesTab(BuildContext context) {
    // Get the Salesforce ID from the user's additional data
    final String? salesforceId = _additionalData['salesforceId'] as String?;

    // Check if the Salesforce ID is available
    if (salesforceId == null || salesforceId.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.nosign, // Corrected icon: Changed from link_slash
              size: 64,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Salesforce Not Linked', // TODO: l10n
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'This user does not have a Salesforce ID linked.', // TODO: l10n
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Use FutureProvider.family or watch directly for simplicity here
    // We need a way to pass salesforceId to a provider or use FutureBuilder
    // Using FutureBuilder for direct implementation:
    final salesforceRepo = ref.read(salesforceRepositoryProvider);

    return FutureBuilder<List<SalesforceOpportunity>>(
      // Call the repository method to get opportunities for this reseller
      future: salesforceRepo.getResellerOpportunities(salesforceId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          // Display a more user-friendly error message
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    CupertinoIcons.exclamationmark_triangle,
                    size: 48,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error Loading Opportunities', // TODO: l10n
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    // Corrected multi-line string and interpolation
                    'Could not fetch opportunities from Salesforce. Please try again later.\nError: ${snapshot.error}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        final opportunities = snapshot.data ?? [];

        if (opportunities.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  CupertinoIcons.briefcase, // Icon for opportunities/work
                  size: 64,
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'No Opportunities Found', // TODO: l10n
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'No Salesforce opportunities found for this reseller.', // TODO: l10n
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        // Display the list of opportunities
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: opportunities.length,
          itemBuilder: (context, index) {
            final opportunity = opportunities[index];
            // Use the new widget to build the card for SalesforceOpportunity
            return _buildOpportunityCard(context, opportunity);
          },
        );
      },
    );
  }

  Widget _buildOpportunityCard(
    BuildContext context,
    SalesforceOpportunity opportunity,
  ) {
    // Determine color based on Phase (Fase__c) - adapt _getStatusColor
    final statusColor = _getPhaseColor(opportunity.Fase__c);
    // Format the creation date
    final creationDate = _formatSalesforceDate(opportunity.CreatedDate);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          // Navigate to the Salesforce Opportunity Detail Page
          final salesforceOpportunityId = opportunity.id;
          // Ensure the route matches your GoRouter configuration
          context.push(
            '/admin/salesforce/opportunities/$salesforceOpportunityId',
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Category/Type icon - adapt _getCategoryIcon if needed, or use generic
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        // Using briefcase as a generic icon for opportunity
                        CupertinoIcons.briefcase_fill,
                        size: 20,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Basic info: Opportunity Name and Account Name
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          opportunity.name, // Opportunity Name
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          opportunity.accountName ??
                              'No Account Name', // Account Name
                          style: Theme.of(context).textTheme.bodyMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Status chip based on Phase (Fase__c)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      // Display the Phase, replacing underscores and uppercasing
                      (opportunity.Fase__c ?? 'UNKNOWN')
                          .replaceAll('_', ' ')
                          .toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              const Divider(),

              // Footer: Creation Date and Short ID
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Created: $creationDate', // Display formatted creation date
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    // Display short Salesforce ID
                    'ID: ${opportunity.id.substring(0, 6)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          Icon(
            icon,
            size: 24,
            color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEditableInfoItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required TextEditingController controller,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          Icon(
            icon,
            size: 24,
            color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: label,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'N/A';

    DateTime date;
    if (timestamp is DateTime) {
      date = timestamp;
    } else if (timestamp is Map && timestamp['seconds'] != null) {
      // Handle Firestore Timestamp
      date = DateTime.fromMillisecondsSinceEpoch(
        (timestamp['seconds'] * 1000) + (timestamp['nanoseconds'] ~/ 1000000),
      );
    } else {
      return 'N/A';
    }

    return DateFormat('MMM dd, yyyy - HH:mm').format(date);
  }

  // New function to format Salesforce Date strings (usually YYYY-MM-DD)
  String _formatSalesforceDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      final dateTime = DateTime.parse(dateString);
      // Format as DD/MM/YYYY or another desired format
      return DateFormat('dd/MM/yyyy').format(dateTime);
    } catch (e) {
      return dateString; // Return original if parsing fails
    }
  }

  // Updated to handle Salesforce Opportunity Phases (Fase__c)
  Color _getPhaseColor(String? phase) {
    // Define colors based on expected Salesforce Phase values
    // Adjust these cases based on your actual Salesforce Phase values
    switch (phase?.toLowerCase()) {
      case 'closed_won':
        return Colors.green;
      case 'proposal_sent':
      case 'negotiation':
        return Colors.blue; // Example: Blue for progress
      case 'qualification':
      case 'needs_analysis':
        return Colors.orange; // Example: Orange for early stages
      case 'closed_lost':
        return Colors.red;
      case 'pending_approval': // Example phase
        return Colors.purple;
      default:
        return Colors.grey; // Default for unknown or null phases
    }
  }

  String _formatCurrency(dynamic amount) {
    if (amount == null) {
      return '\$0.00';
    }

    double numericAmount;
    if (amount is int) {
      numericAmount = amount.toDouble();
    } else if (amount is double) {
      numericAmount = amount;
    } else if (amount is String) {
      numericAmount = double.tryParse(amount) ?? 0.0;
    } else {
      return '\$0.00';
    }

    final formatter = NumberFormat.currency(symbol: '\$');
    return formatter.format(numericAmount);
  }
}
