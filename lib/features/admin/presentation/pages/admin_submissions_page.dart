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
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

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
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          selectedResellerId != null
              ? l10n.submissionsFromReseller(selectedResellerName ?? '')
              : l10n.serviceSubmissions,
          style: theme.textTheme.titleLarge,
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
      body: Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        child: BackdropFilter(
          filter: AppStyles.standardBlur,
          child: Container(
            decoration: AppStyles.glassCard(context),
            child: Column(
              children: [
                _buildFilters(l10n),
                Expanded(child: _buildSubmissionsList(l10n)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilters(AppLocalizations l10n) {
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
                    style: AppTextStyles.body2.copyWith(
                      color: AppTheme.foreground,
                    ),
                    decoration: InputDecoration(
                      hintText:
                          selectedResellerId != null
                              ? l10n.searchResellerSubmissions
                              : l10n.searchAllSubmissions,
                      hintStyle: AppTextStyles.body2.copyWith(
                        color: AppTheme.mutedForeground,
                      ),
                      border: InputBorder.none,
                      prefixIcon: Icon(
                        CupertinoIcons.search,
                        color: AppTheme.mutedForeground,
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
                    dropdownColor: Theme.of(
                      context,
                    ).colorScheme.surface.withOpacity(0.9),
                    style: AppTextStyles.body2.copyWith(
                      color: AppTheme.foreground,
                    ),
                    icon: Icon(
                      CupertinoIcons.chevron_down,
                      size: 16,
                      color: AppTheme.mutedForeground,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    items: [
                      DropdownMenuItem(
                        value: 'all',
                        child: Text(
                          l10n.allStatus,
                          style: AppTextStyles.body2.copyWith(
                            color: AppTheme.foreground,
                          ),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'pending',
                        child: Text(
                          l10n.statusPending,
                          style: AppTextStyles.body2.copyWith(
                            color: AppTheme.foreground,
                          ),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'approved',
                        child: Text(
                          l10n.statusApproved,
                          style: AppTextStyles.body2.copyWith(
                            color: AppTheme.foreground,
                          ),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'rejected',
                        child: Text(
                          l10n.statusRejected,
                          style: AppTextStyles.body2.copyWith(
                            color: AppTheme.foreground,
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

  Widget _buildSubmissionsList(AppLocalizations l10n) {
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
                    l10n.errorLoadingSubmissions,
                    style: AppTextStyles.body1.copyWith(
                      color: AppTheme.foreground,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body2.copyWith(
                      color: AppTheme.mutedForeground,
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
                  color: AppTheme.mutedForeground,
                ),
                const SizedBox(height: 16),
                Text(
                  selectedResellerId != null
                      ? l10n.noSubmissionsForReseller
                      : l10n.noServiceSubmissionsFound,
                  style: AppTextStyles.body1.copyWith(
                    color: AppTheme.mutedForeground,
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
                  color: AppTheme.mutedForeground,
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.noSubmissionsMatchSearch,
                  style: AppTextStyles.body1.copyWith(
                    color: AppTheme.mutedForeground,
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

            return _buildSubmissionItem(context, submission, l10n);
          },
        );
      },
    );
  }

  Widget _buildSubmissionItem(
    BuildContext context,
    ServiceSubmission submission,
    AppLocalizations l10n,
  ) {
    final statusColor = _getStatusColor(submission.status);
    final formattedDate = DateFormat(
      'dd/MM/yyyy',
    ).format(submission.submissionTimestamp.toDate());

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
                // Navigate to submission detail page
                context.push('/admin/submissions/${submission.id}');
              },
              borderRadius: BorderRadius.circular(16),
              splashColor: Theme.of(context).splashColor,
              highlightColor: Theme.of(context).highlightColor,
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
                                    color: AppTheme.foreground,
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
                                  _getLocalizedStatus(submission.status, l10n),
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
                            l10n.nifAndEmail(submission.nif, submission.email),
                            style: AppTextStyles.body2.copyWith(
                              color: AppTheme.mutedForeground,
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
                                  submission.serviceCategory.getLocalizedName(
                                    context,
                                  ),
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
                                    color: AppTheme.mutedForeground,
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
                            color: Theme.of(
                              context,
                            ).colorScheme.secondary.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            (submission.documentUrls?.length ?? 0).toString(),
                            style: AppTextStyles.body2.copyWith(
                              color: AppTheme.foreground,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.documents,
                          style: AppTextStyles.caption.copyWith(
                            color: AppTheme.mutedForeground,
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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.green.shade300;
      case 'rejected':
        return Colors.red.shade300;
      default:
        return Colors.amber;
    }
  }

  String _getLocalizedStatus(String status, AppLocalizations l10n) {
    switch (status) {
      case 'approved':
        return l10n.statusApproved;
      case 'rejected':
        return l10n.statusRejected;
      case 'pending':
        return l10n.statusPending;
      default:
        return status.capitalize();
    }
  }

  String _getLocalizedCategory(
    ServiceCategory category,
    AppLocalizations l10n,
  ) {
    switch (category) {
      case ServiceCategory.energy:
        return l10n.categoryEnergy;
      case ServiceCategory.insurance:
        return l10n.categoryInsurance;
      case ServiceCategory.telecommunications:
        return l10n.categoryTelecommunications;
    }
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
