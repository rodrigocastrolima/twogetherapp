import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:collection/collection.dart'; // For distinct reseller names
import '../../../../core/models/service_submission.dart'; // Adjusted path
import '../../../../core/models/service_types.dart'; // Ensure this line exists and is correct
import './opportunity_detail_page.dart'; // Import the new detail page
import '../widgets/opportunity_filter_sheet.dart'; // <-- Import the filter sheet
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // Import AppLocalizations
import '../../../../core/theme/colors.dart'; // Use AppColors for specific cases
import '../../../../core/theme/ui_styles.dart'; // Use AppStyles for specific decorations/layouts
import 'package:firebase_storage/firebase_storage.dart'; // Import Firebase Storage

// Provider to stream pending opportunity submissions
final pendingOpportunitiesProvider = StreamProvider<List<ServiceSubmission>>((
  ref,
) {
  // Consider adding error handling for the stream itself if needed
  return FirebaseFirestore.instance
      .collection('serviceSubmissions')
      .where('status', isEqualTo: 'pending_review')
      .orderBy('submissionTimestamp', descending: true)
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.docs
                .map((doc) => ServiceSubmission.fromFirestore(doc))
                .toList(),
      );
});

// New Stateful Widget to handle filters
class OpportunityVerificationPage extends ConsumerStatefulWidget {
  const OpportunityVerificationPage({super.key});

  @override
  ConsumerState<OpportunityVerificationPage> createState() =>
      _OpportunityVerificationPageState();
}

class _OpportunityVerificationPageState
    extends ConsumerState<OpportunityVerificationPage> {
  String _searchQuery = '';
  String? _selectedReseller;
  ServiceCategory? _selectedServiceType;
  EnergyType? _selectedEnergyType; // <-- ADD state for EnergyType
  final TextEditingController _searchController = TextEditingController();

  // --- ADD Callback for applying filters from the sheet ---
  void _applyFilters(
    String? reseller,
    ServiceCategory? serviceType,
    EnergyType? energyType,
  ) {
    setState(() {
      _selectedReseller = reseller;
      _selectedServiceType = serviceType;
      _selectedEnergyType = energyType;
    });
  }
  // -------------------------------------------------------

  // --- ADD Method to show the filter sheet ---
  void _showFilterSheet(BuildContext context, List<String> availableResellers) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allow sheet to take variable height
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (BuildContext modalContext) {
        return OpportunityFilterSheet(
          initialReseller: _selectedReseller,
          initialServiceType: _selectedServiceType,
          initialEnergyType: _selectedEnergyType,
          availableResellers: availableResellers,
          onApplyFilters: _applyFilters, // Pass the callback
        );
      },
    );
  }
  // ------------------------------------------

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Helper to format date consistently
  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy HH:mm').format(date.toLocal());
  }

  // Helper to calculate if any filters are active
  bool _areFiltersActive() {
    return _selectedReseller != null ||
        _selectedServiceType != null ||
        _selectedEnergyType != null;
  }

  @override
  Widget build(BuildContext context) {
    final pendingOpportunitiesAsync = ref.watch(pendingOpportunitiesProvider);
    final l10n = AppLocalizations.of(context)!; // Get localizations
    final theme = Theme.of(context); // Get theme
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface, // Use surface instead of background
      body: Padding(
        // Consistent padding
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        child: pendingOpportunitiesAsync.when(
          data: (allSubmissions) {
            // --- Filtering Logic --- Updated
            final uniqueResellers =
                allSubmissions
                    .map((s) => s.resellerName)
                    .nonNulls // Use .nonNulls instead of whereNotNull
                    .toSet() // Get unique names
                    .toList()
                  ..sort(); // Sort alphabetically

            final filteredSubmissions =
                allSubmissions.where((submission) {
                  final resellerMatch =
                      _selectedReseller == null ||
                      submission.resellerName == _selectedReseller;

                  // Match service category (compare names)
                  final serviceTypeMatch =
                      _selectedServiceType == null ||
                      submission.serviceCategory.name ==
                          _selectedServiceType!.name;

                  // --- ADD Energy Type Filter Condition ---
                  final energyTypeMatch =
                      _selectedEnergyType == null ||
                      submission.energyType?.name == _selectedEnergyType!.name;
                  // ---------------------------------------

                  final searchMatch =
                      _searchQuery.isEmpty ||
                      (submission.companyName ?? '').toLowerCase().contains(
                        _searchQuery.toLowerCase(),
                      ) ||
                      (submission.responsibleName).toLowerCase().contains(
                        _searchQuery.toLowerCase(),
                      ) ||
                      (submission.nif ?? '').toLowerCase().contains(
                        _searchQuery.toLowerCase(),
                      );

                  return resellerMatch &&
                      serviceTypeMatch &&
                      energyTypeMatch &&
                      searchMatch;
                }).toList();
            // --- End Filtering Logic ---

            return LayoutBuilder(
              builder: (context, constraints) {
                // Define breakpoint for web/desktop layout
                final bool isWebView =
                    constraints.maxWidth > 800; // Adjusted breakpoint

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- Header Section --- Updated
                    _buildHeader(
                      context,
                      l10n,
                      theme,
                      isWebView,
                      uniqueResellers,
                    ),
                    const SizedBox(height: 24), // Spacing below header
                    // --- Content Section --- (List builders will be updated next)
                    Expanded(
                      child:
                          filteredSubmissions.isEmpty
                              ? _buildEmptyState(context, l10n, theme)
                              : (isWebView
                                  ? _buildWebList(
                                    context,
                                    filteredSubmissions,
                                    theme,
                                  )
                                  : _buildMobileList(
                                    context,
                                    filteredSubmissions,
                                    theme,
                                  )),
                    ),
                  ],
                );
              },
            );
          },
          loading: () => _buildLoadingState(context, theme),
          error: (error, stack) => _buildErrorState(context, error, theme),
        ),
      ),
    );
  }

  // --- Header Builder --- Updated
  Widget _buildHeader(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
    bool isWebView,
    List<String> uniqueResellers,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          // l10n.opportunityVerificationTitle, // TODO: Add localization key
          'Opportunity Verification',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color:
                theme
                    .colorScheme
                    .onSurface, // Use onSurface instead of onBackground
          ),
        ),
        // --- Updated: Common Row for Search and Filters ---
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start, // Keep alignment
          children: [
            // Search Field (remains similar)
            Expanded(
              flex: isWebView ? 3 : 5, // Adjust flex based on view
              child: SizedBox(
                height: 42,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    // hintText: l10n.commonSearchHint, // TODO: Add localization key
                    hintText: 'Search by Name, NIF...',
                    prefixIcon: Icon(
                      Icons.search,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    hintStyle: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withOpacity(
                        0.7,
                      ),
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.surface.withOpacity(0.5),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon:
                        _searchQuery.isNotEmpty
                            ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                              splashRadius: 20,
                              visualDensity: VisualDensity.compact,
                            )
                            : null,
                  ),
                  style: theme.textTheme.bodyMedium,
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                  },
                ),
              ),
            ),
            const SizedBox(width: 16),
            // --- NEW: Filter Button ---
            SizedBox(
              height: 42,
              child: Badge(
                // Add Badge
                isLabelVisible:
                    _areFiltersActive(), // Show badge if filters are active
                backgroundColor: theme.colorScheme.primary,
                child: OutlinedButton.icon(
                  icon: Icon(Icons.filter_list, size: 18),
                  label: Text('Filters'), // TODO: l10n
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.onSurfaceVariant,
                    side: BorderSide(color: theme.dividerColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ), // Adjust padding
                  ),
                  onPressed: () {
                    // Call the method to show the bottom sheet
                    _showFilterSheet(context, uniqueResellers);
                  },
                ),
              ),
            ),
          ],
        ),
        // --- REMOVE OLD DROPDOWNS ---
        /*
        if (isWebView) ...[ // Keep conditional structure if needed for other web-only elements
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search Field (was here)
              // Reseller Dropdown (was here)
              // Service Type Dropdown (was here)
              // Energy Type Dropdown (was here)
            ],
          ),
        ] else ...[
           // --- Add Filter Button for Mobile View too ---
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              height: 40, // Slightly smaller for mobile
              child: Badge(
                isLabelVisible: _areFiltersActive(),
                backgroundColor: theme.colorScheme.primary,
                child: OutlinedButton.icon(
                  icon: Icon(Icons.filter_list, size: 18),
                  label: Text('Filters'), // TODO: l10n
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.onSurfaceVariant,
                    side: BorderSide(color: theme.dividerColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onPressed: () {
                    _showFilterSheet(context, uniqueResellers);
                  },
                ),
              ),
            ),
          ),
        ],
        */
      ],
    );
  }

  // --- Web List Builder --- Updated
  Widget _buildWebList(
    BuildContext context,
    List<ServiceSubmission> submissions,
    ThemeData theme,
  ) {
    return ListView.separated(
      itemCount: submissions.length + 1, // +1 for header row
      separatorBuilder:
          (_, __) => Divider(
            height: 1,
            thickness: 0.5,
            color: theme.dividerColor.withOpacity(0.1),
          ),
      itemBuilder: (context, index) {
        // Header Row
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 12.0,
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    // l10n.opportunityCompanyOrName, // TODO: Add localization key
                    'Company / Name',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    // l10n.opportunityNif, // TODO: Add localization key
                    'NIF',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    // l10n.opportunityReseller, // TODO: Add localization key
                    'Reseller',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    // l10n.opportunitySubmittedDate, // TODO: Add localization key
                    'Submitted',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(width: 48), // Space for PopupMenuButton
              ],
            ),
          );
        }

        // Data Rows
        final submission = submissions[index - 1];
        return Material(
          color:
              index % 2 != 0
                  ? Colors.transparent
                  : theme.colorScheme.onSurface.withOpacity(0.03),
          child: InkWell(
            onTap:
                () => _navigateToDetail(context, submission), // Navigate on tap
            child: Padding(
              padding: const EdgeInsets.only(
                left: 16.0,
                right: 4.0,
                top: 14.0,
                bottom: 14.0,
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      submission.companyName ??
                          submission.responsibleName, // Use expression directly
                      style: theme.textTheme.bodyMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      submission.nif ?? '-', // Keep ?? '-' for nif
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      submission
                          .resellerName, // Remove ?? '-', resellerName is non-nullable
                      style: theme.textTheme.bodyMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      _formatDate(submission.submissionDate),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    child: PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      tooltip: 'Actions', // TODO: l10n
                      onSelected: (String result) {
                        switch (result) {
                          case 'view':
                            _navigateToDetail(context, submission);
                            break;
                          case 'delete':
                            // --- Check if ID exists before showing dialog ---
                            if (submission.id != null) {
                              _showDeleteConfirmationDialog(
                                context,
                                submission.id!, // Pass non-nullable ID
                                // Revert to simpler name logic
                                submission.companyName ??
                                    submission.responsibleName,
                                theme,
                              );
                            } else {
                              // Optional: Show error if ID is null (shouldn't happen often)
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Error: Submission ID is missing.',
                                  ),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                            }
                            break;
                        }
                      },
                      itemBuilder:
                          (BuildContext context) => <PopupMenuEntry<String>>[
                            const PopupMenuItem<String>(
                              value: 'view',
                              child: ListTile(
                                leading: Icon(Icons.visibility_outlined),
                                title: Text('View Details'), // TODO: l10n
                              ),
                            ),
                            const PopupMenuDivider(),
                            PopupMenuItem<String>(
                              value: 'delete',
                              // Disable if ID is null
                              enabled: submission.id != null,
                              child: ListTile(
                                leading: Icon(
                                  Icons.delete_outline,
                                  color:
                                      submission.id != null
                                          ? theme.colorScheme.error
                                          : theme.disabledColor,
                                ),
                                title: Text(
                                  'Delete Submission', // TODO: l10n
                                  style: TextStyle(
                                    color:
                                        submission.id != null
                                            ? theme.colorScheme.error
                                            : theme.disabledColor,
                                  ),
                                ),
                              ),
                            ),
                          ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // --- Mobile List Builder --- Updated
  Widget _buildMobileList(
    BuildContext context,
    List<ServiceSubmission> submissions,
    ThemeData theme,
  ) {
    return ListView.builder(
      itemCount: submissions.length,
      padding: const EdgeInsets.only(bottom: 16), // Padding at the bottom
      itemBuilder: (context, index) {
        final submission = submissions[index];
        return Card(
          // Use Card for better mobile appearance
          elevation: 1.0, // Subtle elevation
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: theme.dividerColor.withOpacity(0.1),
              width: 0.5,
            ),
          ),
          color: theme.colorScheme.surface, // Use surface color
          clipBehavior: Clip.antiAlias, // Ensure InkWell splash stays inside
          child: InkWell(
            onTap:
                () => _navigateToDetail(
                  context,
                  submission,
                ), // Still allow tap on body
            child: Padding(
              padding: const EdgeInsets.only(
                left: 16.0,
                right: 8.0,
                top: 16.0,
                bottom: 16.0,
              ),
              child: Row(
                // Use Row for icon alignment
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          submission.companyName ??
                              submission
                                  .responsibleName, // Use expression directly
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        _buildMobileInfoRow(
                          context,
                          'NIF',
                          submission.nif ?? '-', // Keep ?? '-' for nif
                          theme,
                        ),
                        const SizedBox(height: 4),
                        _buildMobileInfoRow(
                          context,
                          'Reseller',
                          submission
                              .resellerName, // Remove ?? '-', resellerName is non-nullable
                          theme,
                        ),
                        const SizedBox(height: 4),
                        _buildMobileInfoRow(
                          context,
                          'Submitted',
                          _formatDate(submission.submissionDate),
                          theme,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              'Status:',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              // Status Badge
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.secondaryContainer
                                    .withOpacity(0.7),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                submission.status
                                    .replaceAll('_', ' ')
                                    .toUpperCase(),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSecondaryContainer,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 0), // Reduced space before icon
                  IconButton(
                    icon: const Icon(Icons.more_vert),
                    color: theme.colorScheme.onSurfaceVariant,
                    tooltip: 'Actions', // TODO: l10n
                    splashRadius: 20,
                    // Disable button if ID is null
                    onPressed:
                        submission.id == null
                            ? null
                            : () {
                              // Removed intermediate variable and if/else logic
                              _showDeleteConfirmationDialog(
                                context,
                                submission.id!, // Pass non-nullable ID
                                // Revert to simpler name logic
                                submission.companyName ??
                                    submission.responsibleName,
                                theme,
                              );
                            },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Helper for mobile info rows
  Widget _buildMobileInfoRow(
    BuildContext context,
    String label,
    String value,
    ThemeData theme,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 70, // Fixed width for label
          child: Text(
            '$label:',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // --- State Builders ---
  Widget _buildLoadingState(BuildContext context, ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.commonLoading,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, Object error, ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 60, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              // '${AppLocalizations.of(context)!.errorLoadingOpportunities}: $error', // TODO: Add localization key
              'Error loading opportunities: $error',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_off_outlined,
            size: 60,
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
          ),
          const SizedBox(height: 16),
          Text(
            // l10n.noPendingOpportunities, // TODO: Add localization key
            'No pending opportunities found.',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 8),
          if (_searchQuery.isNotEmpty ||
              _selectedReseller != null ||
              _selectedServiceType != null ||
              _selectedEnergyType != null) // <-- ADD EnergyType check
            Text(
              // l10n.tryAdjustingFilters, // TODO: Add localization key
              'Try adjusting the search or filters.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }

  // --- Navigation ---
  void _navigateToDetail(BuildContext context, ServiceSubmission submission) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OpportunityDetailFormView(submission: submission),
      ),
    );
  }

  // --- START: Deletion Logic --- Updated
  Future<void> _deleteSubmission(String submissionId) async {
    // Show loading indicator maybe?
    final docRef = FirebaseFirestore.instance
        .collection('serviceSubmissions')
        .doc(submissionId);

    String? storagePathToDelete;
    String feedbackMessage =
        'Submission deleted successfully.'; // Default success
    Color feedbackColor = Colors.green;

    try {
      // 1. Get the document data BEFORE deleting to find the file path
      final docSnap = await docRef.get();

      if (docSnap.exists) {
        final data = docSnap.data() as Map<String, dynamic>?;
        // Check for invoicePhoto and its storagePath
        if (data != null && data.containsKey('invoicePhoto')) {
          final invoicePhotoData =
              data['invoicePhoto'] as Map<String, dynamic>?;
          if (invoicePhotoData != null &&
              invoicePhotoData.containsKey('storagePath')) {
            storagePathToDelete = invoicePhotoData['storagePath'] as String?;
          }
        }
      } else {
        // Document doesn't exist, maybe already deleted?
        feedbackMessage = 'Submission not found.';
        feedbackColor = Colors.orange;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(feedbackMessage),
              backgroundColor: feedbackColor,
            ),
          );
        }
        return; // Exit early
      }

      // 2. Attempt to delete the file from Storage if path exists
      if (storagePathToDelete != null && storagePathToDelete.isNotEmpty) {
        try {
          final storageRef = FirebaseStorage.instance.ref(storagePathToDelete);
          await storageRef.delete();
          print('Successfully deleted file from Storage: $storagePathToDelete');
        } on FirebaseException catch (e) {
          // Handle Storage deletion errors (e.g., file not found, permissions)
          print('Error deleting file from Storage: $e');
          if (e.code == 'object-not-found') {
            // File already gone, proceed to delete Firestore doc anyway
            print('Storage file not found, proceeding with Firestore delete.');
          } else {
            // Other storage error, maybe don't delete Firestore doc?
            feedbackMessage = 'Error deleting associated file: ${e.message}';
            feedbackColor = Colors.red;
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(feedbackMessage),
                  backgroundColor: feedbackColor,
                ),
              );
            }
            return; // Exit without deleting Firestore doc for critical storage errors
          }
        }
      }

      // 3. Delete the Firestore document
      await docRef.delete();
    } catch (e) {
      print('Error during deletion process: $e');
      feedbackMessage = 'Error deleting submission: ${e.toString()}';
      feedbackColor = Colors.red;
    } finally {
      // Show final feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(feedbackMessage),
            backgroundColor: feedbackColor,
          ),
        );
      }
    }
  }

  Future<void> _showDeleteConfirmationDialog(
    BuildContext context,
    String submissionId,
    String submissionName,
    ThemeData theme,
  ) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // User must tap button!
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Text('Confirm Deletion'), // TODO: l10n
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(
                  'Are you sure you want to delete the submission for "$submissionName"?',
                ), // TODO: l10n
                const Text('This action cannot be undone.'), // TODO: l10n
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'), // TODO: l10n
              onPressed: () {
                Navigator.of(dialogContext).pop(); // Dismiss the dialog
              },
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.error, // Use error color
              ),
              child: const Text('Delete'), // TODO: l10n
              onPressed: () {
                Navigator.of(dialogContext).pop(); // Dismiss the dialog
                _deleteSubmission(submissionId); // Call the delete function
              },
            ),
          ],
        );
      },
    );
  }

  // --- END: Deletion Logic ---
}
