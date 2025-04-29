import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/theme.dart';
import '../../../features/opportunity/presentation/providers/opportunity_providers.dart';
import '../../../features/opportunity/data/models/salesforce_opportunity.dart'
    as sf_opp_model;
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';

class ClientsPage extends ConsumerStatefulWidget {
  const ClientsPage({super.key});

  @override
  ConsumerState<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends ConsumerState<ClientsPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final opportunitiesAsync = ref.watch(resellerOpportunitiesProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: _buildSearchBar(context),
            ),

            Expanded(
              child: opportunitiesAsync.when(
                data: (opportunities) {
                  final filteredOpportunities = ref.watch(
                    filteredOpportunitiesProvider(_searchQuery),
                  );

                  if (filteredOpportunities.isEmpty) {
                    return _buildEmptyState(context);
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.only(top: 6),
                    itemCount: filteredOpportunities.length,
                    separatorBuilder:
                        (context, index) =>
                            _buildListSeparator(context, isDark),
                    itemBuilder: (context, index) {
                      final sf_opp_model.SalesforceOpportunity opportunity =
                          filteredOpportunities[index];
                      return _buildOpportunityCard(
                        context,
                        opportunity,
                        key: ValueKey(opportunity.id),
                      );
                    },
                  );
                },
                loading: () => _buildLoadingIndicator(context, isDark),
                error:
                    (error, stackTrace) =>
                        _buildErrorState(context, error, isDark),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildFloatingActionButton(context, isDark),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor =
        isDark
            ? AppTheme.darkInput.withAlpha(204)
            : AppTheme.secondary.withAlpha(204);
    final textColor = isDark ? AppTheme.darkForeground : AppTheme.foreground;
    final hintColor =
        isDark ? AppTheme.darkMutedForeground : AppTheme.mutedForeground;

    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: CupertinoTextField(
        controller: _searchController,
        placeholder: 'Buscar cliente',
        placeholderStyle: TextStyle(color: hintColor, fontSize: 14),
        prefix: Padding(
          padding: const EdgeInsets.only(left: 10),
          child: Icon(CupertinoIcons.search, color: hintColor, size: 16),
        ),
        suffix:
            _searchQuery.isNotEmpty
                ? GestureDetector(
                  onTap: () => _searchController.clear(),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Icon(
                      CupertinoIcons.clear_circled_solid,
                      color: hintColor,
                      size: 16,
                    ),
                  ),
                )
                : null,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        style: TextStyle(fontSize: 14, color: textColor),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? AppTheme.darkMutedForeground : AppTheme.mutedForeground;

    const String message = 'Sem Clientes Ativos';

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(CupertinoIcons.person_2, size: 48, color: textColor),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isEmpty
                ? 'Adicione um novo cliente usando o botão +'
                : 'Tente refinar sua busca.',
            style: TextStyle(fontSize: 15, color: textColor),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator(BuildContext context, bool isDark) {
    return Center(
      child: CircularProgressIndicator(
        color: isDark ? AppTheme.darkPrimary : AppTheme.primary,
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, Object error, bool isDark) {
    return Center(
      child: Text(
        'Erro ao carregar clientes: $error',
        style: TextStyle(
          color: isDark ? AppTheme.darkDestructive : AppTheme.destructive,
        ),
      ),
    );
  }

  Widget _buildListSeparator(BuildContext context, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(left: 72),
      height: 0.5,
      color:
          isDark
              ? AppTheme.darkBorder.withAlpha(128)
              : AppTheme.border.withAlpha(128),
    );
  }

  Widget _buildFloatingActionButton(BuildContext context, bool isDark) {
    return FloatingActionButton(
      backgroundColor: isDark ? AppTheme.darkPrimary : AppTheme.primary,
      shape: const CircleBorder(),
      elevation: 2.0,
      child: Icon(
        CupertinoIcons.add,
        color:
            isDark
                ? AppTheme.darkPrimaryForeground
                : AppTheme.primaryForeground,
      ),
      onPressed: () {
        context.push('/services');
      },
    );
  }

  Widget _buildOpportunityCard(
    BuildContext context,
    sf_opp_model.SalesforceOpportunity opportunity, {
    Key? key,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.darkForeground : AppTheme.foreground;
    final chevronColor =
        isDark ? AppTheme.darkMutedForeground : AppTheme.mutedForeground;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          context.push('/opportunity-details', extra: opportunity);
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      opportunity.accountName ?? opportunity.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: textColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(CupertinoIcons.chevron_right, color: chevronColor, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
