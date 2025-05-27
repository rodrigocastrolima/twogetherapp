import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:collection/collection.dart'; // For distinct reseller names AND Set equality
import 'package:firebase_storage/firebase_storage.dart'; // Import Firebase Storage
import 'package:firebase_auth/firebase_auth.dart'; // <-- Add FirebaseAuth import
import 'package:flutter/cupertino.dart'; // Import Cupertino widgets
import 'package:go_router/go_router.dart'; // <-- Import GoRouter
import 'package:flutter/foundation.dart'; // For kDebugMode, kIsWeb
import 'dart:convert'; // For base64Encode, if used directly for downloads
import 'dart:html' as html; // For web downloads, if kIsWeb specific code uses it

// Package imports (ensure these are in pubspec.yaml)
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

// Project-specific imports (relative paths from this file)
import '../../../../core/models/service_submission.dart';
import '../../../../core/models/service_types.dart';
import '../../../../core/theme/colors.dart'; // Use AppColors for specific cases
import '../../../../core/theme/ui_styles.dart'; // Use AppStyles for specific decorations/layouts
import '../../../../core/services/salesforce_auth_service.dart';
// import '../../../presentation/widgets/logo.dart'; // REMOVED
// import '../../../presentation/widgets/app_loading_indicator.dart'; // REMOVED

// Feature-specific imports (relative paths from this file)
import '../../data/models/salesforce_opportunity.dart'; // CORRECTED (was domain/entities/opportunity.dart)
import '../../data/repositories/opportunity_service.dart' as opportunity_repository_definition;
import '../../data/services/opportunity_service.dart';
import '../providers/opportunity_providers.dart';
import '../widgets/opportunity_filter_sheet.dart';
import 'admin_opportunity_submission_page.dart';
import '../../../../presentation/widgets/simple_list_item.dart';

// Constants for status - ensure these are used if they represent backend values
const String statusPendente = 'Pendente';
const String statusEmVerificacao = 'Em Verificação';
const String statusAprovado = 'Aprovado';
const String statusRejeitado = 'Rejeitado';

// Default filter (can be localized if needed, but for now, hardcode)
const String defaultFilter = 'Todos';

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

// Custom pill indicator for TabBar
class PillTabIndicator extends Decoration {
  final Color color;
  final double radius;
  final double borderWidth;
  final double horizontalPadding;
  final double verticalPadding;

  const PillTabIndicator({
    required this.color,
    this.radius = 16,
    this.borderWidth = 2,
    this.horizontalPadding = 4,
    this.verticalPadding = 2,
  });

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) {
    return _PillTabPainter(this, onChanged);
  }
}

class _PillTabPainter extends BoxPainter {
  final PillTabIndicator decoration;

  _PillTabPainter(this.decoration, VoidCallback? onChanged) : super(onChanged);

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final Rect rect = offset & configuration.size!;
    final Rect paddedRect = Rect.fromLTRB(
      rect.left + decoration.horizontalPadding,
      rect.top + decoration.verticalPadding,
      rect.right - decoration.horizontalPadding,
      rect.bottom - decoration.verticalPadding,
    );
    final Paint paint = Paint()
      ..color = Colors.transparent
      ..style = PaintingStyle.fill;
    final Paint borderPaint = Paint()
      ..color = decoration.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = decoration.borderWidth;
    final RRect rRect = RRect.fromRectAndRadius(
      paddedRect,
      Radius.circular(decoration.radius),
    );
    canvas.drawRRect(rRect, paint);
    canvas.drawRRect(rRect, borderPaint);
  }
}

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
  Set<String>? _selectedFases; // Add for fase filter
  final TextEditingController _searchController = TextEditingController();

  // --- Tab Controller ---
  late TabController _tabController;

  bool _isFilterOpen = false;

  @override
  void initState() {
    super.initState();

    // Initialize TabController with 3 tabs
    _tabController = TabController(length: 3, vsync: this);

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
    {Set<String>? fases}
  ) {
    setState(() {
      if (!const SetEquality().equals(_selectedResellers, resellers)) {
        _selectedResellers = resellers;
      }
      if (!const SetEquality().equals(_selectedFases, fases)) {
        _selectedFases = fases;
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
      // Use Cupertino dynamic color for background
      backgroundColor: CupertinoDynamicColor.resolve(
        CupertinoColors.systemGroupedBackground, // Adapts to light/dark mode
        context,
      ),
      // Remove the dimming effect entirely
      barrierColor: Colors.transparent, // Set barrier to transparent
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      // Removed explicit theme background color:
      // backgroundColor: Theme.of(context).colorScheme.surface,
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

  // Place this at the class level, not inside any method
  void _showSalesforceFilterSheet() {
    final theme = Theme.of(context);
    final salesforceOpportunitiesAsync = ref.read(salesforceOpportunitiesProvider);
    final opportunities = salesforceOpportunitiesAsync.asData?.value ?? [];
    final uniqueResellers = opportunities.map((o) => o.resellerName).whereType<String>().toSet().toList()..sort();
    final uniqueFases = opportunities.map((o) => o.fase).whereType<String>().toSet().toList()..sort();
    setState(() => _isFilterOpen = true);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      barrierColor: Colors.black.withOpacity(0.1),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext modalContext) {
        return Padding(
          padding: MediaQuery.of(context).viewInsets,
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                    child: Text('Filtrar Oportunidades', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text('REVENDEDOR', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
                  ),
                  SizedBox(
                    height: 220,
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: uniqueResellers.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: theme.dividerColor.withOpacity(0.15)),
                      itemBuilder: (context, i) {
                        final reseller = uniqueResellers[i];
                        return CheckboxListTile(
                          value: _selectedResellers?.contains(reseller) ?? false,
                          onChanged: (checked) {
                            setModalState(() {
                              final set = _selectedResellers ?? <String>{};
                              if (checked == true) {
                                set.add(reseller);
                              } else {
                                set.remove(reseller);
                              }
                              _selectedResellers = Set<String>.from(set);
                            });
                          },
                          title: Text(reseller, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface)),
                          controlAffinity: ListTileControlAffinity.leading,
                          dense: true,
                          activeColor: theme.colorScheme.primary,
                          checkColor: theme.colorScheme.onPrimary,
                          tileColor: Colors.transparent,
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Text('FASE', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
                  ),
                  SizedBox(
                    height: 220,
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: uniqueFases.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: theme.dividerColor.withOpacity(0.15)),
                      itemBuilder: (context, i) {
                        final fase = uniqueFases[i];
                        return CheckboxListTile(
                          value: _selectedFases?.contains(fase) ?? false,
                          onChanged: (checked) {
                            setModalState(() {
                              final set = _selectedFases ?? <String>{};
                              if (checked == true) {
                                set.add(fase);
                              } else {
                                set.remove(fase);
                              }
                              _selectedFases = Set<String>.from(set);
                            });
                          },
                          title: Text(fase, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface)),
                          controlAffinity: ListTileControlAffinity.leading,
                          dense: true,
                          activeColor: theme.colorScheme.primary,
                          checkColor: theme.colorScheme.onPrimary,
                          tileColor: Colors.transparent,
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            setModalState(() {
                              _selectedResellers = <String>{};
                              _selectedFases = <String>{};
                            });
                          },
                          child: const Text('Limpar'),
                        ),
                        const Spacer(),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: theme.colorScheme.onPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                          onPressed: () {
                            Navigator.of(context).pop();
                            setState(() => _isFilterOpen = false);
                          },
                          child: const Text('Aplicar'),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    ).whenComplete(() {
      if (mounted) setState(() => _isFilterOpen = false);
    });
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

  Widget _buildCustomTabBar(BuildContext context, ThemeData theme) {
    final tabs = [
      {
        'icon': CupertinoIcons.exclamationmark_circle_fill,
        'label': 'Novas',
        'color': Colors.blue,
      },
      {
        'icon': CupertinoIcons.xmark_seal_fill,
        'label': 'Rejeitadas',
        'color': Colors.red,
      },
      {
        'icon': CupertinoIcons.checkmark_seal_fill,
        'label': 'Ativas',
        'color': Colors.green,
      },
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(tabs.length, (i) {
        final selected = _tabController.index == i;
        final color = tabs[i]['color'] as Color;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => setState(() => _tabController.index = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? color.withOpacity(0.06) : Colors.transparent,
                border: Border.all(
                  color: selected ? color : Colors.transparent,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    tabs[i]['icon'] as IconData,
                    color: color,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    tabs[i]['label'] as String,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: color,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watch the Firestore provider here for filter availability
    final pendingOpportunitiesAsync = ref.watch(pendingOpportunitiesProvider);
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
      _tabController.index == 2, // Updated to check for third tab
    );
    _tabController.addListener(() {
      isSalesforceTabSelected.value = _tabController.index == 2; // Updated to check for third tab
    });
    // --- End Salesforce Refresh Button Visibility Logic --- //

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: null,
      body: SafeArea(
        bottom: false,
        top: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title/Header
                  Padding(
              padding: const EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 0),
                    child: Text(
                      'Oportunidades',
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                  letterSpacing: -0.5,
                      ),
                    ),
                  ),
            const SizedBox(height: 12),
                  // Tab Bar
                  Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: _buildCustomTabBar(context, theme),
                  ),
                  // Header (Search and Filters) - Appears above tabs
                  Padding(
              padding: const EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 0),
                    child: Row(
                      children: [
                        // Search bar always present
                        Expanded(
                          child: SizedBox(
                            height: 40,
                            child: TextField(
                              controller: _searchController,
                              style: theme.textTheme.bodyMedium,
                              decoration: AppStyles.searchInputDecoration(context, 'Pesquisar Oportunidades...'),
                              onChanged: (value) {
                                setState(() => _searchQuery = value);
                              },
                            ),
                          ),
                        ),
                        if (_tabController.index == 2) ...[
                          const SizedBox(width: 16),
                          SizedBox(
                            height: 40,
                            child: OutlinedButton.icon(
                              icon: Icon(Icons.filter_list, size: 18, color: theme.colorScheme.onSurface),
                              label: Text('Filtros', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface)),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: theme.colorScheme.surface,
                                side: BorderSide(color: theme.dividerColor.withOpacity(0.18), width: 1),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                minimumSize: const Size(0, 40),
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                alignment: Alignment.centerLeft,
                              ),
                              onPressed: _showSalesforceFilterSheet,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Tab Content Area
                  Expanded(
                    child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          // --- Tab 1: New Submissions (pending_review) ---
                          _buildNovasSubmissionsTab(context, theme),
                          // --- Tab 2: Rejected Submissions ---
                          _buildRejeitadasSubmissionsTab(context, theme),
                          // --- Tab 3: Active Opportunities (Salesforce) ---
                          _buildAtivasOpportunitiesTab(context, theme),
                        ],
                      ),
                    ),
                  ),
                ],
        ),
      ),
    );
  }

  // --- Builder for "Novas" Tab ---
  Widget _buildNovasSubmissionsTab(BuildContext context, ThemeData theme) {
    // Watch the necessary provider
    final pendingOpportunitiesAsync = ref.watch(pendingOpportunitiesProvider);

    return pendingOpportunitiesAsync.when(
      data: (allSubmissions) {
        // Filter only pending_review submissions
        final filteredSubmissions = allSubmissions
            .where((submission) => submission.status == 'pending_review')
            .where((submission) {
              // Apply search and filter logic
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
                ? _buildEmptyState(
                  context,
                  theme,
                  isSubmissionsTab: true,
                )
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
      error:
          (error, stack) =>
              _buildErrorState(context, error, theme),
    );
  }

  // --- Builder for "Rejeitadas" Tab ---
  Widget _buildRejeitadasSubmissionsTab(BuildContext context, ThemeData theme) {
    // Watch the necessary provider
    final pendingOpportunitiesAsync = ref.watch(pendingOpportunitiesProvider);

    return pendingOpportunitiesAsync.when(
      data: (allSubmissions) {
        // Filter only rejected submissions
        final filteredSubmissions = allSubmissions
            .where((submission) => submission.status == 'rejected')
            .where((submission) {
              // Apply search and filter logic
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
                ? _buildEmptyState(
                  context,
                  theme,
                  isSubmissionsTab: true,
                )
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
      error:
          (error, stack) =>
              _buildErrorState(context, error, theme),
    );
  }

  // --- Builder for "Ativas" Tab (Salesforce Opportunities) ---
  Widget _buildAtivasOpportunitiesTab(BuildContext context, ThemeData theme) {
    final salesforceOpportunitiesAsync = ref.watch(salesforceOpportunitiesProvider);
    return salesforceOpportunitiesAsync.when(
      data: (opportunities) {
        // Apply search and filter logic
        final filteredOpportunities = opportunities.where((opportunity) {
          // Search match
          final searchMatch = _searchQuery.isEmpty ||
              (opportunity.accountName ?? '').toLowerCase().contains(_searchQuery.toLowerCase()) ||
              (opportunity.name).toLowerCase().contains(_searchQuery.toLowerCase()) ||
              (opportunity.nifC ?? '').toLowerCase().contains(_searchQuery.toLowerCase());

          // Reseller match
          final resellerMatch = _selectedResellers == null ||
              _selectedResellers!.isEmpty ||
              (_selectedResellers?.contains(opportunity.resellerName ?? '') ?? false);

          // Fase match
          final faseMatch = _selectedFases == null ||
              _selectedFases!.isEmpty ||
              (_selectedFases?.contains(opportunity.fase ?? '') ?? false);

          return searchMatch && resellerMatch && faseMatch;
        }).toList();

        // Determine if using web or mobile layout based on constraints
        return LayoutBuilder(
          builder: (context, constraints) {
            final bool isWebView = constraints.maxWidth > 800;
            return filteredOpportunities.isEmpty
                ? _buildEmptyState(
                    context,
                    theme,
                    isSubmissionsTab: false,
                  )
                : (isWebView
                    ? _buildSalesforceWebList(context, filteredOpportunities, theme)
                    : _buildSalesforceMobileList(context, filteredOpportunities, theme));
          },
        );
      },
      loading: () => _buildLoadingState(context, theme),
      error: (error, stack) => _buildErrorState(context, error, theme),
    );
  }

  // --- Web List Builder (Firestore Submissions) ---
  Widget _buildSubmissionsWebList(
    BuildContext context,
    List<ServiceSubmission> submissions,
    ThemeData theme,
  ) {
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: submissions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 0),
      itemBuilder: (context, index) {
        final submission = submissions[index];
        // Icon logic (reuse from previous implementation)
        return SimpleListItem(
          title: submission.companyName ?? submission.responsibleName,
          subtitle: 'Revendedor: ${submission.resellerName ?? '-'}',
          trailing: Text(
            submission.submissionDate != null
                ? DateFormat('dd/MM/yyyy').format(submission.submissionDate!)
                : 'N/A',
            style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          onTap: () => _navigateToDetail(context, submission),
        );
      },
    );
  }

  // --- Mobile List Builder (Firestore Submissions) ---
  Widget _buildSubmissionsMobileList(
    BuildContext context,
    List<ServiceSubmission> submissions,
    ThemeData theme,
  ) {
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: submissions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 0),
      itemBuilder: (context, index) {
        final submission = submissions[index];
        return SimpleListItem(
          title: submission.companyName ?? submission.responsibleName,
          subtitle: 'Revendedor: ${submission.resellerName ?? '-'}',
          trailing: Text(
            submission.submissionDate != null
                ? DateFormat('dd/MM/yyyy').format(submission.submissionDate!)
                : 'N/A',
            style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          onTap: () => _navigateToDetail(context, submission),
        );
      },
    );
  }

  // --- Web List Builder (Salesforce Opportunities) --- NEW
  Widget _buildSalesforceWebList(
    BuildContext context,
    List<SalesforceOpportunity> opportunities,
    ThemeData theme,
  ) {
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: opportunities.length,
      separatorBuilder: (_, __) => const SizedBox(height: 0),
      itemBuilder: (context, index) {
        final opportunity = opportunities[index];
        return SimpleListItem(
          title: opportunity.name,
          subtitle: 'Revendedor: ${opportunity.resellerName ?? '-'} | Fase: ${opportunity.fase ?? '-'}',
          trailing: Text(
            opportunity.createdDate != null
                ? _formatSalesforceDate(opportunity.createdDate!)
                : 'N/A',
                    style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
            onTap: () {
              context.push(
                '/admin/salesforce-opportunity-detail/${opportunity.id}',
              );
          },
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
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: opportunities.length,
      separatorBuilder: (_, __) => const SizedBox(height: 0),
      itemBuilder: (context, index) {
        final opportunity = opportunities[index];
        return SimpleListItem(
          title: opportunity.name,
          subtitle: 'Revendedor: ${opportunity.resellerName ?? '-'} | Fase: ${opportunity.fase ?? '-'}',
          trailing: Text(
            opportunity.createdDate != null
                ? _formatSalesforceDate(opportunity.createdDate!)
                : 'N/A',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
            onTap: () {
              context.push(
                '/admin/salesforce-opportunity-detail/${opportunity.id}',
              );
          },
        );
      },
    );
  }

  // --- State Builders (Loading, Error, Empty) ---
  // (Keep existing implementations, update Empty State)
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
            'Carregando...',
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
    String message =
        isSalesforceError
            ? 'Erro ao carregar oportunidades Salesforce: $error'
            : 'Erro ao carregar submissões: $error';
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
    ThemeData theme, {
    required bool isSubmissionsTab,
  }) {
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
                ? 'Nenhuma submissão pendente encontrada.'
                : 'Nenhuma oportunidade existente encontrada.',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 8),
          if (isSubmissionsTab)
            Text(
              'Tente ajustar a pesquisa ou os filtros.',
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
    context.push('/review-this-submission', extra: submission);
  }

  // --- START: Deletion Logic --- Updated
  Future<void> _deleteFirestoreSubmission(String submissionId) async {
    final docRef = FirebaseFirestore.instance
        .collection('serviceSubmissions')
        .doc(submissionId);
    String feedbackMessage = 'Submissão eliminada com sucesso.';
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
        feedbackMessage = 'Submissão não encontrada.';
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
                  'Submissão eliminada, but failed to delete some files.';
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
      feedbackMessage = 'Erro ao eliminar submissão: ${e.toString()}';
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
    setState(() {});
    String feedbackMessage = 'Oportunidade Salesforce eliminada com sucesso.';
    Color feedbackColor = Colors.green;
    try {
      final sfAuthNotifier = ref.read(salesforceAuthProvider.notifier);
      final String? accessToken = await sfAuthNotifier.getValidAccessToken();
      final String? instanceUrl = sfAuthNotifier.currentInstanceUrl;
      if (accessToken == null || instanceUrl == null) {
        throw Exception("Autenticação Salesforce inválida.");
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
      feedbackMessage = 'Erro ao eliminar Oportunidade: ${e.toString()}';
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
    final String itemType =
        isSubmission ? 'submissão' : 'Oportunidade Salesforce';
    final String title = 'Confirmar Eliminação';
    final String content =
        'Tem a certeza que quer eliminar a $itemType para "$name"? Esta ação não pode ser desfeita.';
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
              child: const Text('Cancelar'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
              child: const Text('Eliminar'),
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

  // --- Helper to format Salesforce date string ---
  String _formatSalesforceDate(String dateString) {
    try {
      // Assuming dateString is like "2023-10-26T10:00:00.000Z"
      final dateTime = DateTime.parse(dateString);
      return DateFormat('dd/MM/yyyy').format(dateTime.toLocal());
    } catch (e) {
      print("Error formatting Salesforce date: $dateString, Error: $e");
      return dateString; // Return original if parsing fails
    }
  }
}
