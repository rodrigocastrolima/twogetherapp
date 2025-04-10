import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/ui_styles.dart';
import '../../../../core/models/service_submission.dart';
import '../../../../core/models/service_types.dart';
import '../../data/repositories/service_submission_repository.dart';
import '../providers/service_submission_provider.dart' as provider_lib;

class SubmissionDetailPage extends ConsumerStatefulWidget {
  final String submissionId;

  const SubmissionDetailPage({super.key, required this.submissionId});

  @override
  ConsumerState<SubmissionDetailPage> createState() =>
      _SubmissionDetailPageState();
}

class _SubmissionDetailPageState extends ConsumerState<SubmissionDetailPage> {
  bool isLoading = true;
  bool isUpdatingStatus = false;
  ServiceSubmission? submission;
  String? errorMessage;
  String? currentStatus;
  int selectedImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadSubmission();
  }

  Future<void> _loadSubmission() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // Load the submission by ID
      final repository = ref.read(serviceSubmissionRepositoryProvider);
      final loadedSubmission = await repository.getSubmissionById(
        widget.submissionId,
      );

      setState(() {
        submission = loadedSubmission;
        currentStatus = loadedSubmission?.status;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Error loading submission: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    if (submission == null || newStatus == currentStatus) return;

    setState(() {
      isUpdatingStatus = true;
    });

    try {
      final repository = ref.read(serviceSubmissionRepositoryProvider);
      await repository.updateSubmissionStatus(submission!.id!, newStatus);

      setState(() {
        currentStatus = newStatus;
        submission = submission!.copyWith(status: newStatus);
        isUpdatingStatus = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Status updated to $newStatus')));
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error updating status: $e';
        isUpdatingStatus = false;
      });
    }
  }

  void _showFullScreenImage(BuildContext context, String imageUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) => Scaffold(
              appBar: AppBar(
                backgroundColor: Colors.black,
                iconTheme: const IconThemeData(color: Colors.white),
              ),
              body: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  color: Colors.black,
                  constraints: const BoxConstraints.expand(),
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 3.0,
                    child: Center(
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.contain,
                        placeholder:
                            (context, url) => const Center(
                              child: CircularProgressIndicator(),
                            ),
                        errorWidget:
                            (context, url, error) => Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.error,
                                  color: Colors.red,
                                  size: 30,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Failed to load image: $error',
                                  style: const TextStyle(color: Colors.red),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: theme.colorScheme.error, size: 48),
            const SizedBox(height: 16),
            Text('Error', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Text(
                errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadSubmission,
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    if (submission == null) {
      return const Center(child: Text('Submission not found'));
    }

    // Main content with minimal wrapping
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Service Submission Details',
          style: theme.textTheme.titleLarge,
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadSubmission,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with basic info
              _buildHeader(),
              const SizedBox(height: 16),

              // Client information section
              _buildSectionTitle('Client Information'),
              _buildClientInfo(),
              const SizedBox(height: 16),

              // Service information section
              _buildSectionTitle('Service Information'),
              _buildServiceInfo(),
              const SizedBox(height: 16),

              // Documents section
              _buildSectionTitle('Documents'),
              _buildDocuments(),
              const SizedBox(height: 16),

              // Status update section for admins
              _buildSectionTitle('Status Management'),
              _buildStatusUpdate(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  bool _canUpdateStatus() {
    // Check if the current user is an admin (use your app's logic)
    final isAdmin = ref
        .read(provider_lib.isAdminUserProvider)
        .maybeWhen(data: (isAdmin) => isAdmin, orElse: () => false);
    return isAdmin;
  }

  Widget _buildHeader() {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: AppStyles.glassCard(context),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Category icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withAlpha(38),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.primary.withAlpha(77),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    _getCategoryIcon(submission!.serviceCategory),
                    size: 24,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(width: 16),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Submission ID: ${submission!.id}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.whiteAlpha70,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        submission!.responsibleName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        DateFormat(
                          'MMMM dd, yyyy - HH:mm',
                        ).format(submission!.submissionTimestamp.toDate()),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.whiteAlpha70,
                        ),
                      ),
                    ],
                  ),
                ),

                // Status chip
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(
                      currentStatus ?? submission!.status,
                    ).withAlpha(26),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    (currentStatus ?? submission!.status)
                        .replaceAll('_', ' ')
                        .toUpperCase(),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: _getStatusColor(
                        currentStatus ?? submission!.status,
                      ),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).textTheme.titleMedium?.color,
        ),
      ),
    );
  }

  Widget _buildClientInfo() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: AppStyles.glassCard(context),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildInfoRow(
              label: 'Client Name',
              value: submission!.responsibleName,
              icon: CupertinoIcons.person,
            ),
            const Divider(),
            _buildInfoRow(
              label: 'NIF',
              value: submission!.nif,
              icon: CupertinoIcons.number,
            ),
            const Divider(),
            _buildInfoRow(
              label: 'Email',
              value: submission!.email,
              icon: CupertinoIcons.mail,
            ),
            const Divider(),
            _buildInfoRow(
              label: 'Phone',
              value: submission!.phone,
              icon: CupertinoIcons.phone,
            ),
            if (submission!.clientType == ClientType.commercial &&
                submission!.companyName != null) ...[
              const Divider(),
              _buildInfoRow(
                label: 'Company',
                value: submission!.companyName!,
                icon: CupertinoIcons.building_2_fill,
              ),
            ],
            const Divider(),
            _buildInfoRow(
              label: 'Client Type',
              value: submission!.clientType.displayName,
              icon:
                  submission!.clientType == ClientType.commercial
                      ? CupertinoIcons.building_2_fill
                      : CupertinoIcons.house_fill,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required String label,
    required String value,
    required IconData icon,
    Color? iconColor,
    Color? textColor,
  }) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.primary.withAlpha(38),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: iconColor ?? AppTheme.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color:
                        textColor != null
                            ? textColor.withOpacity(0.7)
                            : AppColors.whiteAlpha70,
                  ),
                ),
                Text(
                  value,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceInfo() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: AppStyles.glassCard(context),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildInfoRow(
              label: 'Service Category',
              value: submission!.serviceCategory.displayName,
              icon: _getCategoryIcon(submission!.serviceCategory),
            ),
            if (submission!.serviceCategory == ServiceCategory.energy &&
                submission!.energyType != null) ...[
              const Divider(),
              _buildInfoRow(
                label: 'Energy Type',
                value: submission!.energyType!.displayName,
                icon: CupertinoIcons.bolt,
              ),
            ],
            const Divider(),
            _buildInfoRow(
              label: 'Provider',
              value: submission!.provider.displayName,
              icon: CupertinoIcons.building_2_fill,
            ),
            const Divider(),
            _buildInfoRow(
              label: 'Submitted By',
              value: submission!.resellerName,
              icon: CupertinoIcons.person_badge_plus,
            ),
            const Divider(),
            _buildInfoRow(
              label: 'Submission Date',
              value: DateFormat(
                'dd/MM/yyyy HH:mm',
              ).format(submission!.submissionTimestamp.toDate()),
              icon: CupertinoIcons.calendar,
            ),
            const Divider(),
            _buildInfoRow(
              label: 'Status',
              value: _capitalize(submission!.status),
              icon: _getStatusIcon(submission!.status),
              iconColor: _getStatusColor(submission!.status),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocuments() {
    // First check documentUrls, if available use them
    final documents = submission!.documentUrls;
    List<String>? displayUrls;

    if (documents != null && documents.isNotEmpty) {
      // Use existing document URLs if available
      displayUrls = documents;
    } else if (submission!.invoicePhoto != null) {
      // Create a URL from the storage path if available
      final storageUrl =
          "https://storage.googleapis.com/${submission!.invoicePhoto!.storagePath}";
      displayUrls = [storageUrl];
    }

    if (displayUrls?.isEmpty ?? true) {
      // No documents to display
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          decoration: AppStyles.glassCard(context),
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'No documents uploaded',
                style: TextStyle(
                  fontSize: 16,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: AppStyles.glassCard(context),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Main image display
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withAlpha(77)),
              ),
              child: GestureDetector(
                onTap:
                    () => _showFullScreenImage(
                      context,
                      displayUrls![selectedImageIndex],
                    ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _buildNetworkImage(
                    displayUrls?[selectedImageIndex] ?? '',
                    fit: BoxFit.contain,
                    showDetailedError: true,
                  ),
                ),
              ),
            ),

            // Thumbnails if there are multiple documents
            if ((displayUrls?.length ?? 0) > 1) ...[
              const SizedBox(height: 16),
              SizedBox(
                height: 60,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: displayUrls?.length ?? 0,
                  itemBuilder: (context, index) {
                    final isSelected = index == selectedImageIndex;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedImageIndex = index;
                        });
                      },
                      child: Container(
                        width: 60,
                        height: 60,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color:
                                isSelected
                                    ? AppTheme.primary
                                    : Colors.grey.withAlpha(77),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(7),
                          child: _buildNetworkImage(
                            displayUrls?[index] ?? '',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNetworkImage(
    String url, {
    BoxFit fit = BoxFit.cover,
    bool showDetailedError = false,
  }) {
    final theme = Theme.of(context);

    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      placeholder:
          (context, url) => Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
            ),
          ),
      errorWidget: (context, url, error) {
        if (showDetailedError) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error, color: theme.colorScheme.error),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'Error loading image: $error',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          );
        }
        return Center(child: Icon(Icons.error, color: theme.colorScheme.error));
      },
    );
  }

  Widget _buildStatusUpdate() {
    if (isUpdatingStatus) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: AppStyles.glassCard(context),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Update submission status',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.titleMedium?.color,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildStatusButton('pending_review', 'Pending Review'),
                _buildStatusButton('approved', 'Approve'),
                _buildStatusButton('rejected', 'Reject'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusButton(String status, String label) {
    final isSelected = status == currentStatus;

    Color buttonColor;
    Color textColor;

    switch (status) {
      case 'approved':
        buttonColor = isSelected ? Colors.green : Colors.green.withAlpha(50);
        textColor = isSelected ? Colors.white : Colors.green;
        break;
      case 'rejected':
        buttonColor = isSelected ? Colors.red : Colors.red.withAlpha(50);
        textColor = isSelected ? Colors.white : Colors.red;
        break;
      default:
        buttonColor = isSelected ? Colors.amber : Colors.amber.withAlpha(50);
        textColor = isSelected ? Colors.black : Colors.amber.shade800;
    }

    return ElevatedButton(
      onPressed: isSelected ? null : () => _updateStatus(status),
      style: ElevatedButton.styleFrom(
        backgroundColor: buttonColor,
        foregroundColor: textColor,
        disabledBackgroundColor: buttonColor,
        disabledForegroundColor: textColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(label),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'pending_review':
        return Colors.amber;
      case 'rejected':
        return Colors.red;
      case 'sync_failed':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getCategoryIcon(dynamic category) {
    // Handle both String and ServiceCategory enum
    final categoryStr =
        category is String ? category : category.toString().split('.').last;

    switch (categoryStr) {
      case 'energy':
        return CupertinoIcons.bolt_fill;
      case 'telecommunications':
        return CupertinoIcons.phone_fill;
      case 'insurance':
        return CupertinoIcons.shield_fill;
      default:
        return CupertinoIcons.doc_fill;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'approved':
        return CupertinoIcons.checkmark_circle_fill;
      case 'rejected':
        return CupertinoIcons.xmark_circle_fill;
      default:
        return CupertinoIcons.clock_fill;
    }
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }
}
