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
  bool isViewingReseller = false;
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
          isViewingReseller
              ? 'Submissions from $selectedResellerName'
              : 'Resellers & Submissions',
          style: AppTextStyles.h3.copyWith(color: Colors.white),
        ),
        centerTitle: true,
        leading:
            isViewingReseller
                ? IconButton(
                  icon: const Icon(CupertinoIcons.chevron_left),
                  onPressed: () {
                    setState(() {
                      isViewingReseller = false;
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
                  Expanded(
                    child:
                        isViewingReseller
                            ? _buildSubmissionsList()
                            : _buildResellersList(),
                  ),
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
                          isViewingReseller
                              ? 'Search submissions...'
                              : 'Search resellers...',
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

              // Only show status filter when viewing submissions
              if (isViewingReseller)
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

  Widget _buildResellersList() {
    // Create query to get all users who are resellers
    Query query = firestore
        .collection('users')
        .where('role', isEqualTo: 'reseller');

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
                    'Error loading resellers',
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
                  CupertinoIcons.person_3_fill,
                  size: 48,
                  color: AppColors.whiteAlpha50,
                ),
                const SizedBox(height: 16),
                Text(
                  'No resellers found',
                  style: AppTextStyles.body1.copyWith(
                    color: AppColors.whiteAlpha70,
                  ),
                ),
              ],
            ),
          );
        }

        // Filter resellers if search query is not empty
        var filteredDocs = snapshot.data!.docs;
        if (searchQuery.isNotEmpty) {
          filteredDocs =
              filteredDocs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final name = data['displayName'] as String? ?? '';
                final email = data['email'] as String? ?? '';
                return name.toLowerCase().contains(searchQuery.toLowerCase()) ||
                    email.toLowerCase().contains(searchQuery.toLowerCase());
              }).toList();

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
                    'No matching resellers found',
                    style: AppTextStyles.body1.copyWith(
                      color: AppColors.whiteAlpha70,
                    ),
                  ),
                ],
              ),
            );
          }
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) {
            final userData = filteredDocs[index].data() as Map<String, dynamic>;
            final userId = filteredDocs[index].id;
            final displayName = userData['displayName'] as String? ?? 'No Name';
            final email = userData['email'] as String? ?? 'No Email';
            final isActive = userData['isActive'] as bool? ?? false;

            return _buildResellerItem(
              userId: userId,
              displayName: displayName,
              email: email,
              isActive: isActive,
            );
          },
        );
      },
    );
  }

  Widget _buildResellerItem({
    required String userId,
    required String displayName,
    required String email,
    required bool isActive,
  }) {
    // Get count of submissions for this reseller
    return StreamBuilder<QuerySnapshot>(
      stream:
          firestore
              .collection('service_submissions')
              .where('resellerId', isEqualTo: userId)
              .snapshots(),
      builder: (context, snapshot) {
        int submissionCount = 0;
        if (snapshot.hasData) {
          submissionCount = snapshot.data!.docs.length;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: AppStyles.glassCardWithHighlight(
            isHighlighted: isActive,
            context: context,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    // View this reseller's submissions
                    setState(() {
                      isViewingReseller = true;
                      selectedResellerId = userId;
                      selectedResellerName = displayName;
                    });
                  },
                  borderRadius: BorderRadius.circular(16),
                  splashColor: AppColors.whiteAlpha10,
                  highlightColor: AppColors.whiteAlpha10,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        // Reseller icon
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
                              CupertinoIcons.person_badge_plus_fill,
                              size: 24,
                              color: AppTheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Reseller info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      displayName,
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
                                      color:
                                          isActive
                                              ? Colors.green.shade900.withAlpha(
                                                204,
                                              )
                                              : Colors.red.shade900.withAlpha(
                                                204,
                                              ),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color:
                                            isActive
                                                ? Colors.green.shade300
                                                : Colors.red.shade300,
                                        width: 0.5,
                                      ),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    child: Text(
                                      isActive ? 'Active' : 'Inactive',
                                      style: AppTextStyles.caption.copyWith(
                                        color:
                                            isActive
                                                ? Colors.green.shade300
                                                : Colors.red.shade300,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                email,
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
                                      color:
                                          submissionCount > 0
                                              ? AppTheme.primary.withAlpha(77)
                                              : Colors.grey.withAlpha(77),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    child: Text(
                                      '$submissionCount Submissions',
                                      style: AppTextStyles.caption.copyWith(
                                        color:
                                            submissionCount > 0
                                                ? AppTheme.primary
                                                : Colors.grey,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Arrow icon
                        Icon(
                          CupertinoIcons.chevron_right,
                          color: AppColors.whiteAlpha70,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSubmissionsList() {
    if (selectedResellerId == null) {
      return const Center(child: Text('No reseller selected'));
    }

    // Create query based on filters
    Query query = firestore
        .collection('service_submissions')
        .where('resellerId', isEqualTo: selectedResellerId);

    if (filterStatus != 'all') {
      query = query.where('status', isEqualTo: filterStatus);
    }

    query = query.orderBy('submissionDate', descending: true);

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
                  'No submissions found',
                  style: AppTextStyles.body1.copyWith(
                    color: AppColors.whiteAlpha70,
                  ),
                ),
              ],
            ),
          );
        }

        // Filter submissions if search query is not empty
        var filteredDocs = snapshot.data!.docs;
        if (searchQuery.isNotEmpty) {
          filteredDocs =
              filteredDocs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final name = data['responsibleName'] as String? ?? '';
                final email = data['email'] as String? ?? '';
                final nif = data['nif'] as String? ?? '';
                final phone = data['phone'] as String? ?? '';

                return name.toLowerCase().contains(searchQuery.toLowerCase()) ||
                    email.toLowerCase().contains(searchQuery.toLowerCase()) ||
                    nif.toLowerCase().contains(searchQuery.toLowerCase()) ||
                    phone.toLowerCase().contains(searchQuery.toLowerCase());
              }).toList();

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
                    'No matching submissions found',
                    style: AppTextStyles.body1.copyWith(
                      color: AppColors.whiteAlpha70,
                    ),
                  ),
                ],
              ),
            );
          }
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) {
            final submissionDoc = filteredDocs[index];
            final submission = ServiceSubmission.fromFirestore(submissionDoc);

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
        '${submission.submissionDate.day}/${submission.submissionDate.month}/${submission.submissionDate.year}';

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
                            submission.documentUrls.length.toString(),
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
