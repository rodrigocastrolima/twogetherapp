import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:collection/collection.dart'; // For distinct reseller names
import '../../../../core/models/service_submission.dart'; // Adjusted path
import './opportunity_detail_page.dart'; // Import the new detail page
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // Import AppLocalizations
import '../../../../core/theme/colors.dart'; // Use AppColors for specific cases
import '../../../../core/theme/ui_styles.dart'; // Use AppStyles for specific decorations/layouts

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
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Helper to format date consistently
  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy HH:mm').format(date.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final pendingOpportunitiesAsync = ref.watch(pendingOpportunitiesProvider);
    final l10n = AppLocalizations.of(context)!; // Get localizations
    final theme = Theme.of(context); // Get theme
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: colorScheme.background, // Use theme background
      body: Padding(
        // Consistent padding
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        child: pendingOpportunitiesAsync.when(
          data: (allSubmissions) {
            // --- Filtering Logic ---
            final uniqueResellers =
                allSubmissions
                    .map((s) => s.resellerName)
                    .whereNotNull() // Ensure resellerName is not null
                    .toSet() // Get unique names
                    .toList()
                  ..sort(); // Sort alphabetically

            final filteredSubmissions =
                allSubmissions.where((submission) {
                  final resellerMatch =
                      _selectedReseller == null ||
                      submission.resellerName == _selectedReseller;
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
                  return resellerMatch && searchMatch;
                }).toList();
            // --- End Filtering Logic ---

            return LayoutBuilder(
              builder: (context, constraints) {
                // Define breakpoint for web/desktop layout
                final bool isWebView = constraints.maxWidth > 700;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- Header Section ---
                    _buildHeader(
                      context,
                      l10n,
                      theme,
                      isWebView,
                      uniqueResellers,
                    ),
                    const SizedBox(height: 24), // Spacing below header
                    // --- Content Section ---
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

  // --- Header Builder ---
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
            color: theme.colorScheme.onBackground,
          ),
        ),
        if (isWebView) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              // Search Field
              Expanded(
                flex: 2, // Give search more space
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
              // Reseller Dropdown
              Expanded(
                flex: 1,
                child: SizedBox(
                  height: 42,
                  child: DropdownButtonFormField<String>(
                    value: _selectedReseller,
                    isExpanded: true,
                    decoration: InputDecoration(
                      // hintText: l10n.filterByResellerHint, // TODO: Add localization key
                      hintText: 'Filter by Reseller',
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
                      prefixIcon: Icon(
                        Icons.person_outline,
                        size: 20,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    hint: Text(
                      // l10n.filterByResellerHint, // TODO: Add localization key
                      'Filter by Reseller',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant.withOpacity(
                          0.7,
                        ),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    items: [
                      // Add "All" option
                      DropdownMenuItem<String>(
                        value: null, // Represents "All"
                        child: Text(
                          // l10n.filterAllResellers, // TODO: Add localization key
                          'All Resellers',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      // Add unique resellers
                      ...uniqueResellers.map((reseller) {
                        return DropdownMenuItem<String>(
                          value: reseller,
                          child: Text(
                            reseller,
                            style: theme.textTheme.bodyMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedReseller = value);
                    },
                    // Style dropdown icon if needed
                    icon: Icon(
                      Icons.arrow_drop_down,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // --- Web List Builder ---
  Widget _buildWebList(
    BuildContext context,
    List<ServiceSubmission> submissions,
    ThemeData theme,
  ) {
    final l10n = AppLocalizations.of(context)!;
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
                const SizedBox(width: 40), // Action icon space
              ],
            ),
          );
        }

        // Data Rows
        final submission = submissions[index - 1];
        return InkWell(
          onTap: () => _navigateToDetail(context, submission),
          child: Container(
            color:
                index % 2 != 0
                    ? Colors.transparent
                    : theme.colorScheme.onSurface.withOpacity(0.03),
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 14.0,
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
                    submission.resellerName ?? '-',
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
                  width: 40,
                  child: Icon(
                    Icons.chevron_right,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- Mobile List Builder ---
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
            onTap: () => _navigateToDetail(context, submission),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                // Use Row for icon alignment
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
                          submission.resellerName ?? '-',
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
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right,
                    color: theme.colorScheme.onSurfaceVariant,
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
          if (_searchQuery.isNotEmpty || _selectedReseller != null)
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
}
