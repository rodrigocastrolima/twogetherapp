import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:collection/collection.dart'; // For distinct reseller names AND Set equality
import '../../../../core/models/service_submission.dart'; // Adjusted path
import '../../../../core/models/service_types.dart'; // Ensure this line exists and is correct
import 'admin_opportunity_review_page.dart'; // Import the new detail page
import '../widgets/opportunity_filter_sheet.dart'; // <-- Import the filter sheet
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // Import AppLocalizations
import '../../../../core/theme/colors.dart'; // Use AppColors for specific cases
import '../../../../core/theme/ui_styles.dart'; // Use AppStyles for specific decorations/layouts
import 'package:firebase_storage/firebase_storage.dart'; // Import Firebase Storage
import 'package:firebase_auth/firebase_auth.dart'; // <-- Add FirebaseAuth import
import 'package:flutter/cupertino.dart'; // Import Cupertino widgets
import 'package:go_router/go_router.dart'; // <-- Import GoRouter
// Import the new model and providers
import '../../data/models/salesforce_opportunity.dart'; // <-- Correct import
import '../providers/opportunity_providers.dart'; // <-- Correct import
import '../../../../core/services/salesforce_auth_service.dart'; // <-- Correct import
import '../../data/services/opportunity_service.dart'; // <-- Correct import
import 'package:flutter/foundation.dart'; // For kDebugMode

// Provider to stream pending AND rejected opportunity submissions
final pendingOpportunitiesProvider = StreamProvider.autoDispose<
  List<ServiceSubmission>
>((ref) {
  // TODO: Add check here? If user is not admin, return empty stream?
  // Although Firestore rules *should* handle this.

  // Consider adding error handling for the stream itself if needed
  final stream = FirebaseFirestore.instance
      .collection('serviceSubmissions')
      // Fetch documents where status is either 'pending_review' OR 'rejected'
      .where('status', whereIn: ['pending_review', 'rejected'])
      // Keep ordering by timestamp
      .orderBy('submissionTimestamp', descending: true)
      .snapshots()
      .map((snapshot) {
        // +++ Add logging INSIDE the map +++
        if (kDebugMode) {
          print(
            '[Provider Map] Received snapshot with ${snapshot.docs.length} docs matching query.',
          );
        }
        // ++++++++++++++++++++++++++++++++++++
        return snapshot.docs
            .map((doc) => ServiceSubmission.fromFirestore(doc))
            .toList();
      })
      .handleError((error) {
        // +++ Add specific error handling for the stream +++
        if (kDebugMode) {
          print('[Provider Stream Error] Error fetching submissions: $error');
        }
        // Optionally rethrow or return an empty list depending on desired behavior
        throw error; // Rethrowing to let the .when clause handle it
        // ++++++++++++++++++++++++++++++++++++++++++++++++
      });

  // Optional: Cancel the stream when the provider is disposed
  // ref.onDispose(() => stream.listen(null).cancel()); // This is implicitly handled by StreamProvider

  return stream;
});

// New Stateful Widget to handle filters AND Tabs
class OpportunityVerificationPage extends ConsumerStatefulWidget {
  const OpportunityVerificationPage({super.key});

  @override
  ConsumerState<OpportunityVerificationPage> createState() =>
      _OpportunityVerificationPageState();
}

// Add SingleTickerProviderStateMixin for TabController
class _OpportunityVerificationPageState
    extends ConsumerState<OpportunityVerificationPage>
    with SingleTickerProviderStateMixin {
  String _searchQuery = '';
  Set<String>? _selectedResellers;
  Set<ServiceCategory>? _selectedServiceTypes;
  Set<EnergyType>? _selectedEnergyTypes;
  final TextEditingController _searchController = TextEditingController();

  // --- Tab Controller ---
  late TabController _tabController;

  @override
  void initState() {
    super.initState();

    // Initialize TabController
    _tabController = TabController(length: 2, vsync: this); // 2 Tabs

    // Force ID token refresh
    FirebaseAuth.instance.currentUser
        ?.getIdToken(true)
        .then((token) {
          debugPrint(
            "[OpportunityVerificationPage Init] Forced ID token refresh initiated.",
          );
          // After token refresh is initiated, fetch submissions
          // The SDK should automatically use the latest token for subsequent requests
        })
        .catchError((e) {
          debugPrint(
            "[OpportunityVerificationPage Init] Error forcing token refresh: $e",
          );
          // Fetch submissions even if token refresh fails, might use cached token
        });

    // Existing initState logic
  }

  // --- Updated Callback for applying filters from the sheet ---
  void _applyFilters(
    Set<String>? resellers,
    Set<ServiceCategory>? serviceTypes,
    Set<EnergyType>? energyTypes,
  ) {
    setState(() {
      if (!const SetEquality().equals(_selectedResellers, resellers)) {
        _selectedResellers = resellers;
      }
      if (!const SetEquality().equals(_selectedServiceTypes, serviceTypes)) {
        _selectedServiceTypes = serviceTypes;
      }
      if (!const SetEquality().equals(_selectedEnergyTypes, energyTypes)) {
        _selectedEnergyTypes = energyTypes;
      }
    });
  }
  // ---------------------------------------------------------

  // Updated Method to show the filter sheet
  void _showFilterSheet(BuildContext context, List<String> availableResellers) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (BuildContext modalContext) {
        return OpportunityFilterSheet(
          initialResellers: _selectedResellers,
          initialServiceTypes: _selectedServiceTypes,
          initialEnergyTypes: _selectedEnergyTypes,
          availableResellers: availableResellers,
          onApplyFilters: _applyFilters,
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose(); // Dispose TabController
    super.dispose();
  }

  // Helper to format date consistently
  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy HH:mm').format(date.toLocal());
  }

  // --- Updated Helper to calculate if any filters are active ---
  bool _areFiltersActive() {
    return (_selectedResellers != null && _selectedResellers!.isNotEmpty) ||
        (_selectedServiceTypes != null && _selectedServiceTypes!.isNotEmpty) ||
        (_selectedEnergyTypes != null && _selectedEnergyTypes!.isNotEmpty);
  }
  // ----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // Watch the Firestore provider here for filter availability
    final pendingOpportunitiesAsync = ref.watch(pendingOpportunitiesProvider);
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Extract unique resellers from pending submissions for the filter sheet
    final List<String> uniqueResellers = pendingOpportunitiesAsync.maybeWhen(
      data:
          (submissions) =>
              submissions.map((s) => s.resellerName).nonNulls.toSet().toList()
                ..sort(),
      orElse: () => [], // Return empty list if loading or error
    );

    // --- Determine if the Salesforce Refresh button should be visible --- //
    // Listen to tab changes to rebuild the AppBar actions
    // Using a simple ValueNotifier + listener approach for simplicity here
    final isSalesforceTabSelected = ValueNotifier<bool>(
      _tabController.index == 1,
    );
    _tabController.addListener(() {
      isSalesforceTabSelected.value = _tabController.index == 1;
    });
    // --- End Salesforce Refresh Button Visibility Logic --- //

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Opportunity Verification', // TODO: l10n
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'New Submissions'), // TODO: l10n
            Tab(text: 'Existing Opportunities'), // TODO: l10n
          ],
        ),
        // --- ADD AppBar Actions for Refresh Button --- //
        actions: [
          ValueListenableBuilder<bool>(
            valueListenable: isSalesforceTabSelected,
            builder: (context, isSelected, child) {
              // Only show the refresh button if the Salesforce tab is selected
              if (isSelected) {
                return IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh Salesforce List', // TODO: l10n
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Refreshing Salesforce opportunities...'),
                        duration: Duration(seconds: 1),
                      ), // TODO: l10n
                    );
                    ref.refresh(
                      salesforceOpportunitiesProvider,
                    ); // Refresh the provider
                  },
                );
              } else {
                return const SizedBox.shrink(); // Return empty space if not selected
              }
            },
          ),
          const SizedBox(width: 8), // Spacing before header buttons
        ],
        // --- END AppBar Actions --- //
      ),
      body: SafeArea(
        bottom: false,
        top: false, // SafeArea is handled by Scaffold/AppBar
        child: Column(
          // Add Column to hold Header and TabBarView
          children: [
            // Header (Search and Filters) - Appears above tabs
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0, // Adjust padding
                vertical: 12.0,
              ),
              child: _buildHeader(context, l10n, theme, uniqueResellers),
            ),
            // Tab Content Area
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // --- Tab 1: New Submissions (Firestore) ---
                  _buildNewSubmissionsTab(context, theme),
                  // --- Tab 2: Existing Opportunities (Salesforce) ---
                  _buildSalesforceList(context, theme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Header Builder (Remains mostly the same, pass uniqueResellers) ---
  Widget _buildHeader(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
    List<String> uniqueResellers, // Pass uniqueResellers here
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search Field
        Expanded(
          flex: 3,
          child: SizedBox(
            height: 42,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search Submissions...', // TODO: l10n
                prefixIcon: Icon(
                  Icons.search,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                hintStyle: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
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
        // Filter Button
        SizedBox(
          height: 42,
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
              onPressed:
                  uniqueResellers.isEmpty
                      ? null
                      : () {
                        _showFilterSheet(context, uniqueResellers);
                      },
            ),
          ),
        ),
      ],
    );
  }

  // --- Placeholder Builder for Tab 1 ---
  // We will move the actual content here in the next step
  Widget _buildNewSubmissionsTab(BuildContext context, ThemeData theme) {
    // Watch the necessary provider
    final pendingOpportunitiesAsync = ref.watch(pendingOpportunitiesProvider);
    final l10n = AppLocalizations.of(context)!;

    return pendingOpportunitiesAsync.when(
      data: (allSubmissions) {
        // Filtering logic applied here
        final filteredSubmissions =
            allSubmissions.where((submission) {
              // ... (Copy filtering logic from original build method) ...
              final resellerMatch =
                  _selectedResellers == null ||
                  _selectedResellers!.isEmpty ||
                  (_selectedResellers?.contains(submission.resellerName) ??
                      false);
              final serviceTypeMatch =
                  _selectedServiceTypes == null ||
                  _selectedServiceTypes!.isEmpty ||
                  (_selectedServiceTypes?.contains(
                        submission.serviceCategory,
                      ) ??
                      false);
              bool energyTypeMatch = true;
              if (_selectedServiceTypes == null ||
                  _selectedServiceTypes!.isEmpty ||
                  _selectedServiceTypes!.contains(ServiceCategory.energy)) {
                if (_selectedEnergyTypes != null &&
                    _selectedEnergyTypes!.isNotEmpty) {
                  energyTypeMatch =
                      submission.energyType != null &&
                      _selectedEnergyTypes!.contains(submission.energyType);
                }
              }
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

        // Determine if using web or mobile layout based on constraints
        return LayoutBuilder(
          builder: (context, constraints) {
            final bool isWebView = constraints.maxWidth > 800;
            return filteredSubmissions.isEmpty
                ? _buildEmptyState(context, l10n, theme, isSubmissionsTab: true)
                : (isWebView
                    ? _buildSubmissionsWebList(
                      context,
                      filteredSubmissions,
                      theme,
                    )
                    : _buildSubmissionsMobileList(
                      context,
                      filteredSubmissions,
                      theme,
                    ));
          },
        );
      },
      loading: () => _buildLoadingState(context, theme),
      error: (error, stack) => _buildErrorState(context, error, theme),
    );
  }

  // --- Web List Builder (Firestore Submissions) --- Renamed
  Widget _buildSubmissionsWebList(
    BuildContext context,
    List<ServiceSubmission> submissions,
    ThemeData theme,
  ) {
    // ... Keep existing implementation from _buildWebList ...
    // Make sure onTap uses _navigateToDetail(context, submission)
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 8.0).copyWith(bottom: 0),
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
          // ... Header Row implementation ...
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
                    'Company / Name',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'NIF',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Reseller',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Submitted',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'Status',
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
        // ... Data Row implementation ...
        Color statusColor =
            submission.status == 'rejected'
                ? theme.colorScheme.error
                : theme.colorScheme.secondary;
        return Material(
          color:
              index % 2 != 0
                  ? Colors.transparent
                  : theme.colorScheme.onSurface.withOpacity(0.03),
          child: InkWell(
            onTap: () => _navigateToDetail(context, submission),
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
                      submission.companyName ?? submission.responsibleName,
                      style: theme.textTheme.bodyMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      submission.nif ?? '-',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      submission.resellerName,
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
                  Expanded(
                    flex: 1,
                    child: Text(
                      submission.status
                          .replaceAll('_', ' ')
                          .split(' ')
                          .map(
                            (word) =>
                                '${word[0].toUpperCase()}${word.substring(1)}',
                          )
                          .join(' '),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    child: PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      tooltip: 'Actions',
                      onSelected: (String result) {
                        switch (result) {
                          case 'view':
                            _navigateToDetail(context, submission);
                            break;
                          case 'delete':
                            if (submission.id != null) {
                              _showDeleteConfirmationDialog(
                                context,
                                submission.id!,
                                submission.companyName ??
                                    submission.responsibleName,
                                theme,
                                isSubmission: true,
                              );
                            } else {
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
                                title: Text('View Details'),
                              ),
                            ),
                            const PopupMenuDivider(),
                            PopupMenuItem<String>(
                              value: 'delete',
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
                                  'Delete Submission',
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

  // --- Mobile List Builder (Firestore Submissions) --- Renamed
  Widget _buildSubmissionsMobileList(
    BuildContext context,
    List<ServiceSubmission> submissions,
    ThemeData theme,
  ) {
    // ... Implementation from previous _buildMobileList ...
    return ListView.builder(
      itemCount: submissions.length,
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      itemBuilder: (context, index) {
        // ... Item builder implementation ...
        final submission = submissions[index];
        Color statusColor;
        Color statusBgColor;
        if (submission.status == 'rejected') {
          statusColor = theme.colorScheme.error;
          statusBgColor = theme.colorScheme.errorContainer.withOpacity(0.7);
        } else {
          statusColor = theme.colorScheme.secondary;
          statusBgColor = theme.colorScheme.secondaryContainer.withOpacity(0.7);
        }
        return Card(
          elevation: 1.0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: theme.dividerColor.withOpacity(0.1),
              width: 0.5,
            ),
          ),
          color: theme.colorScheme.surface,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _navigateToDetail(context, submission),
            child: Padding(
              padding: const EdgeInsets.only(
                left: 16.0,
                right: 8.0,
                top: 16.0,
                bottom: 16.0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          submission.companyName ?? submission.responsibleName,
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
                          submission.nif ?? '-',
                          theme,
                        ),
                        const SizedBox(height: 4),
                        _buildMobileInfoRow(
                          context,
                          'Reseller',
                          submission.resellerName,
                          theme,
                        ),
                        const SizedBox(height: 4),
                        _buildMobileInfoRow(
                          context,
                          'Submitted',
                          _formatDate(submission.submissionDate),
                          theme,
                        ),
                        const SizedBox(height: 8),
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: statusBgColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                submission.status
                                    .replaceAll('_', ' ')
                                    .split(' ')
                                    .map(
                                      (word) =>
                                          '${word[0].toUpperCase()}${word.substring(1)}',
                                    )
                                    .join(' '),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: statusColor,
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
                  const SizedBox(width: 0),
                  IconButton(
                    icon: const Icon(Icons.more_vert),
                    color: theme.colorScheme.onSurfaceVariant,
                    tooltip: 'Actions',
                    splashRadius: 20,
                    onPressed:
                        submission.id == null
                            ? null
                            : () {
                              _showDeleteConfirmationDialog(
                                context,
                                submission.id!,
                                submission.companyName ??
                                    submission.responsibleName,
                                theme,
                                isSubmission: true,
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

  // --- Builder for Tab 2: Salesforce Opportunities ---
  Widget _buildSalesforceList(BuildContext context, ThemeData theme) {
    // Watch the existing Salesforce opportunities provider
    final salesforceOpportunitiesAsync = ref.watch(
      salesforceOpportunitiesProvider,
    );
    final l10n = AppLocalizations.of(context)!;

    // Use the AsyncValue to handle loading, error, and data states
    return salesforceOpportunitiesAsync.when(
      data: (opportunities) {
        // TODO: Implement filtering logic similar to _buildNewSubmissionsTab
        final filteredOpportunities =
            opportunities.where((opp) {
              // Apply search and filter logic
              final searchMatch =
                  _searchQuery.isEmpty ||
                  (opp.accountName ?? '').toLowerCase().contains(
                    _searchQuery.toLowerCase(),
                  ) ||
                  (opp.name).toLowerCase().contains(
                    _searchQuery.toLowerCase(),
                  ); // name is non-nullable
              // Add other relevant fields for searching if needed
              // TODO: Add reseller/service type/etc. filtering if applicable to Salesforce data model
              // Consider if filters set for Tab 1 should apply here or if SF tab needs its own filters.
              // For now, only applying search query.
              return searchMatch; // && otherFilterMatches;
            }).toList();

        return LayoutBuilder(
          builder: (context, constraints) {
            final bool isWebView = constraints.maxWidth > 800;
            return filteredOpportunities.isEmpty
                ? _buildEmptyState(
                  context,
                  l10n,
                  theme,
                  isSubmissionsTab: false,
                )
                : (isWebView
                    ? _buildSalesforceWebList(
                      context,
                      filteredOpportunities,
                      theme,
                    ) // Use the existing web list builder
                    : _buildSalesforceMobileList(
                      context,
                      filteredOpportunities,
                      theme,
                    )); // Use the existing mobile list builder
          },
        );
      },
      // Pass isSalesforceError flag to potentially customize error message
      loading: () => _buildLoadingState(context, theme),
      error:
          (error, stack) =>
              _buildErrorState(context, error, theme, isSalesforceError: true),
    );

    // Temporary placeholder until provider and data model are ready - REMOVED
    // return _buildEmptyState(context, l10n, theme, isSubmissionsTab: false);
  }

  // --- Web List Builder (Salesforce Opportunities) --- NEW
  Widget _buildSalesforceWebList(
    BuildContext context,
    List<SalesforceOpportunity> opportunities,
    ThemeData theme,
  ) {
    // Adapt the structure from _buildSubmissionsWebList
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 8.0).copyWith(bottom: 0),
      itemCount: opportunities.length + 1, // +1 for header
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
                  flex: 4,
                  child: Text(
                    'Opportunity Name',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ), // TODO: l10n
                Expanded(
                  flex: 3,
                  child: Text(
                    'Account Name',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ), // TODO: l10n
                Expanded(
                  flex: 3,
                  child: Text(
                    'Reseller',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ), // TODO: l10n
                SizedBox(width: 48), // Space for actions
              ],
            ),
          );
        }

        // Data Rows
        final opportunity = opportunities[index - 1];
        return Material(
          color:
              index % 2 != 0
                  ? Colors.transparent
                  : theme.colorScheme.onSurface.withOpacity(0.03),
          child: InkWell(
            onTap: () {
              // Navigate to the NEW Admin Salesforce Detail Page
              context.push(
                '/admin/salesforce-opportunity-detail/${opportunity.id}',
              );
              /* TODO: Navigate to Salesforce Opportunity Detail Page (Future)
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Detail page for SF Opp ${opportunity.id} not implemented yet.',
                  ),
                ),
              );
              */
            },
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
                    flex: 4,
                    child: Text(
                      opportunity.name,
                      style: theme.textTheme.bodyMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      opportunity.accountName ?? '-',
                      style: theme.textTheme.bodyMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      opportunity.resellerName ?? '-',
                      style: theme.textTheme.bodyMedium,
                      overflow: TextOverflow.ellipsis,
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
                        if (result == 'delete') {
                          _showDeleteConfirmationDialog(
                            context,
                            opportunity.id, // Salesforce ID
                            opportunity.name,
                            theme,
                            isSubmission:
                                false, // Indicate it's NOT a submission
                          );
                        }
                      },
                      itemBuilder:
                          (BuildContext context) => <PopupMenuEntry<String>>[
                            // Only Delete for now
                            PopupMenuItem<String>(
                              value: 'delete',
                              child: ListTile(
                                leading: Icon(
                                  Icons.delete_outline,
                                  color: theme.colorScheme.error,
                                ),
                                title: Text(
                                  'Delete Opportunity',
                                  style: TextStyle(
                                    color: theme.colorScheme.error,
                                  ),
                                ), // TODO: l10n
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

  // --- Mobile List Builder (Salesforce Opportunities) --- NEW
  Widget _buildSalesforceMobileList(
    BuildContext context,
    List<SalesforceOpportunity> opportunities,
    ThemeData theme,
  ) {
    // Adapt structure from _buildSubmissionsMobileList
    return ListView.builder(
      itemCount: opportunities.length,
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      itemBuilder: (context, index) {
        final opportunity = opportunities[index];
        return Card(
          elevation: 1.0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: theme.dividerColor.withOpacity(0.1),
              width: 0.5,
            ),
          ),
          color: theme.colorScheme.surface,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              // Navigate to the NEW Admin Salesforce Detail Page
              context.push(
                '/admin/salesforce-opportunity-detail/${opportunity.id}',
              );
              /* TODO: Navigate to Salesforce Opportunity Detail Page (Future)
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Detail page for SF Opp ${opportunity.id} not implemented yet.',
                  ),
                ),
              );
              */
            },
            child: Padding(
              padding: const EdgeInsets.only(
                left: 16.0,
                right: 8.0,
                top: 16.0,
                bottom: 16.0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          opportunity.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        _buildMobileInfoRow(
                          context,
                          'Account',
                          opportunity.accountName ?? '-',
                          theme,
                        ), // TODO: l10n label
                        const SizedBox(height: 4),
                        _buildMobileInfoRow(
                          context,
                          'Reseller',
                          opportunity.resellerName ?? '-',
                          theme,
                        ), // TODO: l10n label
                      ],
                    ),
                  ),
                  const SizedBox(width: 0),
                  IconButton(
                    icon: const Icon(Icons.more_vert),
                    color: theme.colorScheme.onSurfaceVariant,
                    tooltip: 'Actions', // TODO: l10n
                    splashRadius: 20,
                    onPressed: () {
                      _showDeleteConfirmationDialog(
                        context,
                        opportunity.id, // Salesforce ID
                        opportunity.name,
                        theme,
                        isSubmission: false, // Indicate it's NOT a submission
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

  // Helper for mobile info rows (reusable)
  Widget _buildMobileInfoRow(
    BuildContext context,
    String label,
    String value,
    ThemeData theme,
  ) {
    // ... Implementation remains the same ...
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 70,
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

  // --- State Builders (Loading, Error, Empty) ---
  // (Keep existing implementations, update Empty State)
  Widget _buildLoadingState(BuildContext context, ThemeData theme) {
    // ... Implementation remains the same ...
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

  Widget _buildErrorState(
    BuildContext context,
    Object error,
    ThemeData theme, {
    bool isSalesforceError = false,
  }) {
    // ... Implementation remains the same ...
    String message =
        isSalesforceError
            ? 'Error loading Salesforce opportunities: $error'
            : 'Error loading submissions: $error';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 60, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              message,
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
    ThemeData theme, {
    required bool isSubmissionsTab,
  }) {
    // ... Implementation remains the same ...
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
            isSubmissionsTab
                ? 'No pending submissions found.'
                : 'No existing opportunities found.',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 8),
          if (isSubmissionsTab && _areFiltersActive())
            Text(
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
    // ... Implementation remains the same ...
    context.push('/admin/opportunity-detail', extra: submission);
  }

  // --- START: Deletion Logic --- Updated
  Future<void> _deleteFirestoreSubmission(String submissionId) async {
    // ... Implementation remains the same ...
    final docRef = FirebaseFirestore.instance
        .collection('serviceSubmissions')
        .doc(submissionId);
    String feedbackMessage = 'Submission deleted successfully.';
    Color feedbackColor = Colors.green;
    try {
      final docSnap = await docRef.get();
      List<String> pathsToDelete = [];
      if (docSnap.exists) {
        final data = docSnap.data() as Map<String, dynamic>?;
        if (data != null) {
          if (data.containsKey('documentUrls') &&
              data['documentUrls'] is List) {
            /* TODO: Parse paths if needed */
          }
          if (data.containsKey('invoicePhoto')) {
            final invoicePhotoData =
                data['invoicePhoto'] as Map<String, dynamic>?;
            final legacyPath = invoicePhotoData?['storagePath'] as String?;
            if (legacyPath != null &&
                legacyPath.isNotEmpty &&
                !pathsToDelete.contains(legacyPath)) {
              pathsToDelete.add(legacyPath);
            }
          }
        }
      } else {
        feedbackMessage = 'Submission not found.';
        feedbackColor = Colors.orange; /* Show snackbar */
        return;
      }
      if (pathsToDelete.isNotEmpty) {
        for (final path in pathsToDelete) {
          try {
            final storageRef = FirebaseStorage.instance.ref(path);
            await storageRef.delete();
            print('Successfully deleted file from Storage: $path');
          } on FirebaseException catch (e) {
            print('Error deleting file from Storage ($path): $e');
            if (e.code != 'object-not-found') {
              feedbackMessage =
                  'Submission deleted, but failed to delete some files.';
              feedbackColor = Colors.orange;
            }
          } catch (e) {
            print('Generic error deleting file from Storage ($path): $e');
          }
        }
      }
      await docRef.delete();
    } catch (e) {
      print('Error during Firestore submission deletion process: $e');
      feedbackMessage = 'Error deleting submission: ${e.toString()}';
      feedbackColor = Colors.red;
    } finally {
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

  Future<void> _deleteSalesforceOpportunity(String opportunityId) async {
    // ... Implementation remains the same ...
    setState(() {});
    String feedbackMessage = 'Salesforce Opportunity deleted successfully.';
    Color feedbackColor = Colors.green;
    try {
      final sfAuthNotifier = ref.read(salesforceAuthProvider.notifier);
      final String? accessToken = await sfAuthNotifier.getValidAccessToken();
      final String? instanceUrl = sfAuthNotifier.currentInstanceUrl;
      if (accessToken == null || instanceUrl == null) {
        throw Exception("Salesforce authentication invalid.");
      }
      final service = ref.read(salesforceOpportunityServiceProvider);
      await service.deleteSalesforceOpportunity(
        accessToken: accessToken,
        instanceUrl: instanceUrl,
        opportunityId: opportunityId,
      );
      ref.refresh(salesforceOpportunitiesProvider);
    } catch (e) {
      print('Error during Salesforce opportunity deletion process: $e');
      feedbackMessage = 'Error deleting Opportunity: ${e.toString()}';
      feedbackColor = Colors.red;
    } finally {
      setState(() {});
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
    String id,
    String name,
    ThemeData theme, {
    required bool isSubmission,
  }) async {
    // ... Implementation remains the same ...
    final String itemType =
        isSubmission ? 'submission' : 'Salesforce Opportunity';
    final String title = 'Confirm Deletion';
    final String content =
        'Are you sure you want to delete the $itemType for "$name"? This action cannot be undone.';
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Text(title),
          content: SingleChildScrollView(
            child: ListBody(children: <Widget>[Text(content)]),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
              child: const Text('Delete'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                if (isSubmission) {
                  _deleteFirestoreSubmission(id);
                } else {
                  _deleteSalesforceOpportunity(id);
                }
              },
            ),
          ],
        );
      },
    );
  }

  // --- END: Deletion Logic ---
}
