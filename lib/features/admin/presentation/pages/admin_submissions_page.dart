import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/ui_styles.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/models/service_submission.dart';
import '../../../../core/models/service_types.dart';
import '../widgets/submission_details_dialog.dart';

class AdminSubmissionsPage extends ConsumerStatefulWidget {
  const AdminSubmissionsPage({super.key});

  @override
  ConsumerState<AdminSubmissionsPage> createState() =>
      _AdminSubmissionsPageState();
}

class _AdminSubmissionsPageState extends ConsumerState<AdminSubmissionsPage> {
  final searchController = TextEditingController();
  String filterStatus = 'all';
  String searchQuery = '';
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  bool isViewingReseller = true;
  String? selectedResellerId;
  String? selectedResellerName;

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          selectedResellerId != null
              ? 'Submissions from $selectedResellerName'
              : 'Service Submissions',
          style: AppTextStyles.h3.copyWith(color: Colors.white),
        ),
        centerTitle: true,
        leading:
            selectedResellerId != null
                ? IconButton(
                  icon: const Icon(CupertinoIcons.chevron_left),
                  onPressed: () {
                    setState(() {
                      selectedResellerId = null;
                      selectedResellerName = null;
                    });
                  },
                )
                : null,
      ),
      body: SafeArea(
        child: Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
          clipBehavior: Clip.antiAlias,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: BackdropFilter(
            filter: AppStyles.standardBlur,
            child: Container(
              decoration: AppStyles.glassCard(context),
              child: Column(
                children: [
                  _buildFilters(),
                  Expanded(child: _buildSubmissionsList()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 48,
                  decoration: AppStyles.inputContainer(context),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: searchController,
                    onChanged: (value) {
                      setState(() {
                        searchQuery = value.trim();
                      });
                    },
                    style: AppTextStyles.body2.copyWith(color: Colors.white),
                    decoration: InputDecoration(
                      hintText:
                          selectedResellerId != null
                              ? 'Search reseller submissions...'
                              : 'Search all submissions...',
                      hintStyle: AppTextStyles.body2.copyWith(
                        color: AppColors.whiteAlpha50,
                      ),
                      border: InputBorder.none,
                      prefixIcon: Icon(
                        CupertinoIcons.search,
                        color: AppColors.whiteAlpha70,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Always show status filter for submissions
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: AppStyles.inputContainer(context),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: filterStatus,
                    dropdownColor: AppColors.blackAlpha70,
                    style: AppTextStyles.body2.copyWith(color: Colors.white),
                    icon: Icon(
                      CupertinoIcons.chevron_down,
                      size: 16,
                      color: AppColors.whiteAlpha70,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    items: [
                      DropdownMenuItem(
                        value: 'all',
                        child: Text(
                          'All Status',
                          style: AppTextStyles.body2.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'pending',
                        child: Text(
                          'Pending',
                          style: AppTextStyles.body2.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'approved',
                        child: Text(
                          'Approved',
                          style: AppTextStyles.body2.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'rejected',
                        child: Text(
                          'Rejected',
                          style: AppTextStyles.body2.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          filterStatus = value;
                        });
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubmissionsList() {
    // Create query based on filters
    Query query = firestore.collection('serviceSubmissions');

    // Filter by resellerId if selected
    if (selectedResellerId != null) {
      query = query.where('resellerId', isEqualTo: selectedResellerId);
    }

    // Filter by status if not 'all'
    if (filterStatus != 'all') {
      query = query.where('status', isEqualTo: filterStatus);
    }

    // Order by submission timestamp (most recent first)
    query = query.orderBy('submissionTimestamp', descending: true);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    CupertinoIcons.exclamationmark_triangle_fill,
                    size: 48,
                    color: Colors.amber,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading submissions',
                    style: AppTextStyles.body1.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body2.copyWith(
                      color: AppColors.whiteAlpha70,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  CupertinoIcons.doc_text,
                  size: 48,
                  color: AppColors.whiteAlpha50,
                ),
                const SizedBox(height: 16),
                Text(
                  selectedResellerId != null
                      ? 'No submissions found for this reseller'
                      : 'No service submissions found',
                  style: AppTextStyles.body1.copyWith(
                    color: AppColors.whiteAlpha70,
                  ),
                ),
              ],
            ),
          );
        }

        // Apply search filter if query is not empty
        var filteredDocs = snapshot.data!.docs;
        if (searchQuery.isNotEmpty) {
          filteredDocs =
              filteredDocs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;

                // Search in various fields
                final resellerName = data['resellerName'] as String? ?? '';
                final clientName = data['responsibleName'] as String? ?? '';
                final clientEmail = data['email'] as String? ?? '';
                final clientPhone = data['phone'] as String? ?? '';
                final nif = data['nif'] as String? ?? '';

                return resellerName.toLowerCase().contains(
                      searchQuery.toLowerCase(),
                    ) ||
                    clientName.toLowerCase().contains(
                      searchQuery.toLowerCase(),
                    ) ||
                    clientEmail.toLowerCase().contains(
                      searchQuery.toLowerCase(),
                    ) ||
                    clientPhone.contains(searchQuery) ||
                    nif.contains(searchQuery);
              }).toList();
        }

        if (filteredDocs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  CupertinoIcons.search,
                  size: 48,
                  color: AppColors.whiteAlpha50,
                ),
                const SizedBox(height: 16),
                Text(
                  'No submissions match your search',
                  style: AppTextStyles.body1.copyWith(
                    color: AppColors.whiteAlpha70,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) {
            final submissionDoc = filteredDocs[index];
            final submissionData = submissionDoc.data() as Map<String, dynamic>;

            // Parse data into a ServiceSubmission object
            final submission = ServiceSubmission.fromFirestore(
              submissionDoc as DocumentSnapshot<Map<String, dynamic>>,
            );

            return _buildSubmissionItem(submission);
          },
        );
      },
    );
  }

  Widget _buildSubmissionItem(ServiceSubmission submission) {
    // Get status color
    Color statusColor;
    switch (submission.status) {
      case 'approved':
        statusColor = Colors.green.shade300;
        break;
      case 'rejected':
        statusColor = Colors.red.shade300;
        break;
      default:
        statusColor = Colors.amber;
    }

    // Format date
    final formattedDate =
        '${submission.submissionTimestamp.toDate().day}/${submission.submissionTimestamp.toDate().month}/${submission.submissionTimestamp.toDate().year}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AppStyles.glassCard(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                // Show submission details
                showDialog(
                  context: context,
                  builder:
                      (context) =>
                          SubmissionDetailsDialog(submission: submission),
                );
              },
              borderRadius: BorderRadius.circular(16),
              splashColor: AppColors.whiteAlpha10,
              highlightColor: AppColors.whiteAlpha10,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Category icon
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withAlpha(38),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.primary.withAlpha(77),
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          _getCategoryIcon(submission.serviceCategory),
                          size: 24,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Submission info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  submission.responsibleName,
                                  style: AppTextStyles.body1.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  color: statusColor.withAlpha(50),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: statusColor,
                                    width: 0.5,
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                child: Text(
                                  "${submission.status[0].toUpperCase()}${submission.status.substring(1)}",
                                  style: AppTextStyles.caption.copyWith(
                                    color: statusColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'NIF: ${submission.nif} • ${submission.email}',
                            style: AppTextStyles.body2.copyWith(
                              color: AppColors.whiteAlpha70,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withAlpha(38),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                child: Text(
                                  submission.serviceCategory.displayName,
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey.withAlpha(38),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                child: Text(
                                  formattedDate,
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.whiteAlpha70,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Document count indicator
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.whiteAlpha10,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            (submission.documentUrls?.length ?? 0).toString(),
                            style: AppTextStyles.body2.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Docs',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.whiteAlpha70,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
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
    }
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
