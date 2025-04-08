import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../../core/theme/text_styles.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/ui_styles.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/models/service_submission.dart';
import '../../../../core/models/service_types.dart';
import '../../../../features/services/data/repositories/service_submission_repository.dart'
    as repo;
import '../../../../features/services/presentation/providers/service_submission_provider.dart';

class SubmissionDetailsDialog extends ConsumerStatefulWidget {
  final ServiceSubmission submission;

  const SubmissionDetailsDialog({super.key, required this.submission});

  @override
  ConsumerState<SubmissionDetailsDialog> createState() =>
      _SubmissionDetailsDialogState();
}

class _SubmissionDetailsDialogState
    extends ConsumerState<SubmissionDetailsDialog> {
  late String currentStatus;
  bool isUpdatingStatus = false;
  int selectedImageIndex = 0;

  @override
  void initState() {
    super.initState();
    currentStatus = widget.submission.status;
  }

  Future<void> _updateStatus(String newStatus) async {
    if (newStatus == currentStatus) return;

    setState(() {
      isUpdatingStatus = true;
    });

    try {
      final repository = ref.read(repo.serviceSubmissionRepositoryProvider);
      await repository.updateSubmissionStatus(widget.submission.id!, newStatus);

      setState(() {
        currentStatus = newStatus;
        isUpdatingStatus = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status updated to ${newStatus.capitalize()}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        isUpdatingStatus = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: AppStyles.standardBlur,
          child: Container(
            decoration: AppStyles.glassCard(context),
            constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildClientInfo(),
                        const SizedBox(height: 24),
                        _buildServiceInfo(),
                        const SizedBox(height: 24),
                        _buildDocuments(),
                        const SizedBox(height: 32),
                        _buildStatusUpdate(),
                      ],
                    ),
                  ),
                ),
                _buildFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.blackAlpha10,
        border: Border(
          bottom: BorderSide(color: AppColors.whiteAlpha20, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Category icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.primary.withAlpha(38),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppTheme.primary.withAlpha(77),
                width: 1,
              ),
            ),
            child: Icon(
              _getCategoryIcon(widget.submission.serviceCategory),
              size: 20,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(width: 16),

          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Service Submission Details',
                  style: AppTextStyles.h4.copyWith(color: Colors.white),
                ),
                Text(
                  'ID: ${widget.submission.id}',
                  style: AppTextStyles.body2.copyWith(
                    color: AppColors.whiteAlpha70,
                  ),
                ),
              ],
            ),
          ),

          // Close button
          IconButton(
            icon: Icon(
              CupertinoIcons.xmark,
              color: AppColors.whiteAlpha70,
              size: 20,
            ),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildClientInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Client Information',
          style: AppTextStyles.h3.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        _buildInfoGrid([
          InfoItem(
            label: 'Client Name',
            value: widget.submission.responsibleName,
            icon: CupertinoIcons.person,
          ),
          InfoItem(
            label: 'NIF',
            value: widget.submission.nif,
            icon: CupertinoIcons.number,
          ),
          InfoItem(
            label: 'Email',
            value: widget.submission.email,
            icon: CupertinoIcons.mail,
          ),
          InfoItem(
            label: 'Phone',
            value: widget.submission.phone,
            icon: CupertinoIcons.phone,
          ),
          if (widget.submission.clientType == ClientType.commercial &&
              widget.submission.companyName != null)
            InfoItem(
              label: 'Company',
              value: widget.submission.companyName!,
              icon: CupertinoIcons.building_2_fill,
            ),
          InfoItem(
            label: 'Client Type',
            value: widget.submission.clientType.displayName,
            icon:
                widget.submission.clientType == ClientType.commercial
                    ? CupertinoIcons.building_2_fill
                    : CupertinoIcons.house_fill,
          ),
        ]),
      ],
    );
  }

  Widget _buildServiceInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Service Information',
          style: AppTextStyles.h3.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        _buildInfoGrid([
          InfoItem(
            label: 'Service Category',
            value: widget.submission.serviceCategory.displayName,
            icon: _getCategoryIcon(widget.submission.serviceCategory),
          ),
          if (widget.submission.energyType != null)
            InfoItem(
              label: 'Energy Type',
              value: widget.submission.energyType!.displayName,
              icon: CupertinoIcons.bolt_fill,
            ),
          InfoItem(
            label: 'Provider',
            value: widget.submission.provider.displayName,
            icon: CupertinoIcons.building_2_fill,
          ),
          InfoItem(
            label: 'Submission Date',
            value:
                '${widget.submission.submissionTimestamp.toDate().day}/${widget.submission.submissionTimestamp.toDate().month}/${widget.submission.submissionTimestamp.toDate().year}',
            icon: CupertinoIcons.calendar,
          ),
          InfoItem(
            label: 'Status',
            value: currentStatus.capitalize(),
            icon: _getStatusIcon(currentStatus),
          ),
          InfoItem(
            label: 'Reseller',
            value: widget.submission.resellerName,
            icon: CupertinoIcons.person_badge_plus_fill,
          ),
        ]),
      ],
    );
  }

  Widget _buildInfoGrid(List<InfoItem> items) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 3,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.whiteAlpha10,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.whiteAlpha20, width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withAlpha(38),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(item.icon, size: 16, color: AppTheme.primary),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.label,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.whiteAlpha70,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.value,
                      style: AppTextStyles.body2.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDocuments() {
    // First check documentUrls, if available use them
    final documents = widget.submission.documentUrls;

    print("DocumentUrls: ${documents}");

    if (documents != null && documents.isNotEmpty) {
      // Use existing document URLs if available
      print("Using document URLs: ${documents.first}");
      return _buildDocumentDisplay(documents);
    }

    // Check for invoice photo
    final hasInvoicePhoto = widget.submission.invoicePhoto != null;

    if (!hasInvoicePhoto) {
      // No documents and no invoice photo - show empty state
      return _buildEmptyDocumentsState();
    }

    // Show loading state while we get the download URL
    return FutureBuilder<String?>(
      future: _getInvoicePhotoUrl(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingDocumentsState();
        }

        if (snapshot.hasError || !snapshot.hasData) {
          print("Error loading invoice photo URL: ${snapshot.error}");
          return _buildErrorDocumentsState(snapshot.error);
        }

        final photoUrl = snapshot.data!;
        print("Got invoice photo URL: $photoUrl");
        return _buildDocumentDisplay([photoUrl]);
      },
    );
  }

  // Get download URL from Firebase Storage
  Future<String?> _getInvoicePhotoUrl() async {
    try {
      if (widget.submission.invoicePhoto == null) return null;

      final storagePath = widget.submission.invoicePhoto!.storagePath;
      print("Storage path: $storagePath");

      // Standard approach - use the repository method which uses Firebase Storage's getDownloadURL()
      final repository = ref.read(repo.serviceSubmissionRepositoryProvider);
      final url = await repository.getDownloadUrlForPath(storagePath);
      print("Download URL: $url");
      return url;
    } catch (e) {
      print("Error getting download URL: $e");
      return null;
    }
  }

  // Shows empty documents state
  Widget _buildEmptyDocumentsState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Documents',
          style: AppTextStyles.h3.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.whiteAlpha10,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.whiteAlpha20, width: 1),
          ),
          child: Center(
            child: Text(
              'No documents uploaded',
              style: AppTextStyles.body2.copyWith(
                color: AppColors.whiteAlpha70,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Shows loading state
  Widget _buildLoadingDocumentsState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Documents',
          style: AppTextStyles.h3.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.whiteAlpha10,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.whiteAlpha20, width: 1),
          ),
          height: 200,
          child: Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
            ),
          ),
        ),
      ],
    );
  }

  // Shows error state
  Widget _buildErrorDocumentsState(dynamic error) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Documents',
          style: AppTextStyles.h3.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.whiteAlpha10,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.whiteAlpha20, width: 1),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  CupertinoIcons.exclamationmark_triangle_fill,
                  color: Colors.red,
                  size: 32,
                ),
                const SizedBox(height: 8),
                Text(
                  'Error loading document: $error',
                  style: TextStyle(color: Colors.red, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Displays the documents with the given URLs
  Widget _buildDocumentDisplay(List<String> displayUrls) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Documents',
          style: AppTextStyles.h3.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.whiteAlpha10,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.whiteAlpha20, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Main image display
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.whiteAlpha20, width: 1),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _buildNetworkImage(
                    displayUrls[selectedImageIndex],
                    fit: BoxFit.contain,
                    showDetailedError: true,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Thumbnails
              if (displayUrls.length > 1)
                SizedBox(
                  height: 80,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: displayUrls.length,
                    itemBuilder: (context, index) {
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedImageIndex = index;
                          });
                        },
                        child: Container(
                          width: 80,
                          height: 80,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color:
                                  selectedImageIndex == index
                                      ? AppTheme.primary
                                      : AppColors.whiteAlpha20,
                              width: selectedImageIndex == index ? 2 : 1,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(7),
                            child: _buildNetworkImage(
                              displayUrls[index],
                              fit: BoxFit.cover,
                              showDetailedError: false,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

              // View full image button
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () {
                  _showFullScreenImage(displayUrls[selectedImageIndex]);
                },
                icon: const Icon(CupertinoIcons.fullscreen),
                label: const Text('View Full Size'),
                style: TextButton.styleFrom(foregroundColor: AppTheme.primary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showFullScreenImage(String imageUrl) {
    showDialog(
      context: context,
      builder:
          (context) => Dialog.fullscreen(
            backgroundColor: Colors.black87,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Image
                Center(
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: _buildNetworkImage(
                      imageUrl,
                      fit: BoxFit.contain,
                      showDetailedError: true,
                    ),
                  ),
                ),

                // Close button
                Positioned(
                  top: 16,
                  right: 16,
                  child: IconButton(
                    icon: const Icon(
                      CupertinoIcons.xmark_circle_fill,
                      color: Colors.white,
                      size: 32,
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              ],
            ),
          ),
    );
  }

  // Helper method to build network image with improved error handling
  Widget _buildNetworkImage(
    String url, {
    BoxFit fit = BoxFit.cover,
    bool showDetailedError = false,
  }) {
    // Simple approach using standard Image.network
    return Image.network(
      url,
      fit: fit,
      // Explicitly disable caching to avoid stale images (helpful during development)
      cacheHeight: null,
      cacheWidth: null,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
            value:
                loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        print("Image error for URL ($url): $error");
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                CupertinoIcons.exclamationmark_triangle_fill,
                color: Colors.red,
              ),
              if (showDetailedError) ...[
                const SizedBox(height: 8),
                Text(
                  'Error loading image: $error',
                  style: TextStyle(color: Colors.red, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusUpdate() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Update Status',
          style: AppTextStyles.h3.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _buildStatusButton(
              label: 'Pending',
              status: 'pending',
              color: Colors.amber,
            ),
            const SizedBox(width: 12),
            _buildStatusButton(
              label: 'Approve',
              status: 'approved',
              color: Colors.green,
            ),
            const SizedBox(width: 12),
            _buildStatusButton(
              label: 'Reject',
              status: 'rejected',
              color: Colors.red,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusButton({
    required String label,
    required String status,
    required Color color,
  }) {
    final isSelected = currentStatus == status;

    return Expanded(
      child: ElevatedButton(
        onPressed: isUpdatingStatus ? null : () => _updateStatus(status),
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected ? color : color.withAlpha(38),
          foregroundColor: isSelected ? Colors.white : color,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: color.withAlpha(isSelected ? 255 : 77),
              width: isSelected ? 2 : 1,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isUpdatingStatus && currentStatus == status)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isSelected ? Colors.white : color,
                  ),
                ),
              )
            else
              Icon(_getStatusIcon(status), size: 16),
            const SizedBox(width: 8),
            Text(label),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.blackAlpha10,
        border: Border(
          top: BorderSide(color: AppColors.whiteAlpha20, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(
              'Close',
              style: AppTextStyles.button.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(ServiceCategory category) {
    switch (category) {
      case ServiceCategory.energy:
        return CupertinoIcons.bolt_fill;
      case ServiceCategory.insurance:
        return CupertinoIcons.shield_fill;
      case ServiceCategory.telecommunications:
        return CupertinoIcons.phone_fill;
      default:
        return CupertinoIcons.doc_fill;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending_review':
        return CupertinoIcons.clock_fill;
      case 'approved':
        return CupertinoIcons.checkmark_circle_fill;
      case 'rejected':
        return CupertinoIcons.xmark_circle_fill;
      case 'sync_failed':
        return CupertinoIcons.exclamationmark_triangle_fill;
      case 'synced':
        return CupertinoIcons.arrow_2_circlepath_circle_fill;
      // This default will never be reached if all enum values are covered
      // but we need it to satisfy the compiler
      default:
        return CupertinoIcons.question_circle_fill;
    }
  }
}

class InfoItem {
  final String label;
  final String value;
  final IconData icon;

  InfoItem({required this.label, required this.value, required this.icon});
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
