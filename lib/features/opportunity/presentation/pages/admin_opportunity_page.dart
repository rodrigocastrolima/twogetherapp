import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:firebase_auth/firebase_auth.dart'; // <-- Add FirebaseAuth import
import 'package:flutter/cupertino.dart'; // Import Cupertino widgets
import 'package:go_router/go_router.dart'; // <-- Import GoRouter
import 'package:flutter/foundation.dart'; // For kDebugMode, kIsWeb

// Project-specific imports (relative paths from this file)
import '../../../../core/models/service_submission.dart';
import '../../../../core/models/service_types.dart';
import '../../../../core/theme/ui_styles.dart'; // Use AppStyles for specific decorations/layouts

// Feature-specific imports (relative paths from this file)
import '../../data/models/salesforce_opportunity.dart'; // CORRECTED (was domain/entities/opportunity.dart)
import '../providers/opportunity_providers.dart';
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

  @override
  void initState() {
    super.initState();

    // Initialize TabController with 2 tabs (removed rejected tab)
    _tabController = TabController(length: 2, vsync: this);

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

  // Place this at the class level, not inside any method
  void _showSalesforceFilterSheet() {
    final theme = Theme.of(context);
    final salesforceOpportunitiesAsync = ref.read(salesforceOpportunitiesProvider);
    final opportunities = salesforceOpportunitiesAsync.asData?.value ?? [];
    final uniqueResellers = opportunities.map((o) => o.resellerName).whereType<String>().toSet().toList()..sort();
    final uniqueFases = opportunities.map((o) => o.fase).whereType<String>().toSet().toList()..sort();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      barrierColor: Colors.black.withAlpha(25),
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
                      separatorBuilder: (_, __) => Divider(height: 1, color: theme.dividerColor.withAlpha(38)),
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
                      separatorBuilder: (_, __) => Divider(height: 1, color: theme.dividerColor.withAlpha(38)),
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
      // Callback can be empty since we removed _isFilterOpen
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose(); // Dispose TabController
    super.dispose();
  }

  Widget _buildCustomTabBar(BuildContext context, ThemeData theme) {
    final tabs = [
      {
        'icon': CupertinoIcons.exclamationmark_circle_fill,
        'label': 'Novas',
        'color': Colors.blue,
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
                color: selected ? color.withAlpha(15) : Colors.transparent,
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
    final theme = Theme.of(context);

    // --- Determine if the Salesforce Refresh button should be visible --- //
    // Listen to tab changes to rebuild the AppBar actions
    // Using a simple ValueNotifier + listener approach for simplicity here
    final isSalesforceTabSelected = ValueNotifier<bool>(
      _tabController.index == 1, // Updated to check for second tab
    );
    _tabController.addListener(() {
      isSalesforceTabSelected.value = _tabController.index == 1; // Updated to check for second tab
    });
    // --- End Salesforce Refresh Button Visibility Logic --- //

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
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
                        if (_tabController.index == 1) ...[
                          const SizedBox(width: 16),
                          SizedBox(
                            height: 40,
                            child: OutlinedButton.icon(
                              icon: Icon(Icons.filter_list, size: 18, color: theme.colorScheme.onSurface),
                              label: Text('Filtros', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface)),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: theme.colorScheme.surface,
                                side: BorderSide(color: theme.dividerColor.withAlpha(46), width: 1),
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
                          // --- Tab 2: Active Opportunities (Salesforce) ---
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
                  (_selectedResellers!.contains(submission.resellerName));
              final serviceTypeMatch =
                  _selectedServiceTypes == null ||
                  _selectedServiceTypes!.isEmpty ||
                  _selectedServiceTypes!.contains(submission.serviceCategory);
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
                  submission.responsibleName.toLowerCase().contains(
                    _searchQuery.toLowerCase(),
                  ) ||
                  submission.nif.toLowerCase().contains(
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
              opportunity.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              (opportunity.nifC ?? '').toLowerCase().contains(_searchQuery.toLowerCase());

          // Reseller match
          final resellerMatch = _selectedResellers == null ||
              _selectedResellers!.isEmpty ||
              (_selectedResellers!.contains(opportunity.resellerName));

          // Fase match
          final faseMatch = _selectedFases == null ||
              _selectedFases!.isEmpty ||
              (_selectedFases!.contains(opportunity.fase));

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
          subtitle: 'Revendedor: ${submission.resellerName}',
          trailing: Text(
            DateFormat('dd/MM/yyyy').format(submission.submissionDate),
            style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant.withAlpha(153),
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
          subtitle: 'Revendedor: ${submission.resellerName}',
          trailing: Text(
            DateFormat('dd/MM/yyyy').format(submission.submissionDate),
            style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant.withAlpha(204),
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
          subtitle: 'Revendedor: ${opportunity.resellerName} | Fase: ${opportunity.fase}',
          trailing: Text(
            opportunity.createdDate != null
                ? _formatSalesforceDate(opportunity.createdDate!)
                : 'N/A',
                    style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withAlpha(153),
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
          subtitle: 'Revendedor: ${opportunity.resellerName} | Fase: ${opportunity.fase}',
          trailing: Text(
            opportunity.createdDate != null
                ? _formatSalesforceDate(opportunity.createdDate!)
                : 'N/A',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withAlpha(204),
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
              color: theme.colorScheme.onSurfaceVariant.withAlpha(153),
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
            color: theme.colorScheme.onSurfaceVariant.withAlpha(153),
          ),
          const SizedBox(height: 16),
          Text(
            isSubmissionsTab
                ? 'Nenhuma nova submissão encontrada.'
                : 'É necessário conectar-se ao Salesforce para visualizar as oportunidades ativas.',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withAlpha(204),
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

  // --- Helper to format Salesforce date string ---
  String _formatSalesforceDate(String dateString) {
    try {
      // Assuming dateString is like "2023-10-26T10:00:00.000Z"
      final dateTime = DateTime.parse(dateString);
      return DateFormat('dd/MM/yyyy').format(dateTime.toLocal());
    } catch (e) {
      if (kDebugMode) {
        print("Error formatting Salesforce date: $dateString, Error: $e");
      }
      return dateString; // Return original if parsing fails
    }
  }
}
