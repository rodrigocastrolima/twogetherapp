import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/theme.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class ClientsPage extends StatefulWidget {
  const ClientsPage({super.key});

  @override
  State<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends State<ClientsPage> {
  final _searchController = TextEditingController();
  String _selectedView = 'action';
  String _searchQuery = '';

  // Status constants
  static const String STATUS_ACTION_REQUIRED = 'Ação Necessária';
  static const String STATUS_PENDING = 'Pendente';
  static const String STATUS_ACTIVE = 'Ativo';

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

  // Temporary client data
  final List<Map<String, dynamic>> _clients = [
    {
      'id': '1',
      'name': 'Ana Silva',
      'type': 'residential',
      'service': 'Energia',
      'status': STATUS_ACTION_REQUIRED,
      'stage': 'Contrato',
    },
    {
      'id': '2',
      'name': 'Marcos Oliveira',
      'type': 'residential',
      'service': 'Telecomunicações',
      'status': STATUS_PENDING,
      'stage': 'Proposta',
    },
    {
      'id': '3',
      'name': 'Tech Solutions LTDA',
      'type': 'commercial',
      'service': 'Energia',
      'status': STATUS_ACTIVE,
      'stage': 'Ativo',
    },
    {
      'id': '4',
      'name': 'Maria Santos',
      'type': 'residential',
      'service': 'Seguros',
      'status': STATUS_PENDING,
      'stage': 'Documento',
    },
    {
      'id': '5',
      'name': 'JS Consultoria',
      'type': 'commercial',
      'service': 'Telecomunicações',
      'status': STATUS_ACTION_REQUIRED,
      'stage': 'Contrato',
    },
  ];

  // Filtered list based on search and selected view
  List<Map<String, dynamic>> get filteredClients {
    return _clients.where((client) {
      // Filter by search
      if (_searchQuery.isNotEmpty &&
          !client['name'].toString().toLowerCase().contains(
            _searchQuery.toLowerCase(),
          )) {
        return false;
      }

      // Filter by selected view
      if (_selectedView == 'action') {
        return client['status'] == STATUS_ACTION_REQUIRED;
      } else if (_selectedView == 'pending') {
        return client['status'] == STATUS_PENDING;
      } else if (_selectedView == 'active') {
        return client['status'] == STATUS_ACTIVE;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: true,
        top: false,
        child: Column(
          children: [
            // Header area
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    'Clientes',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: _buildSearchBar()),
                ],
              ),
            ),

            // Tab selector - full width, themed
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildSegmentedControl(),
            ),

            // Add a bit more space
            const SizedBox(height: 12),

            // Divider
            Container(
              height: 0.5,
              color: CupertinoColors.systemGrey4.withAlpha(128),
            ),

            // Client list
            Expanded(
              child:
                  filteredClients.isEmpty
                      ? _buildEmptyState()
                      : ListView.separated(
                        padding: const EdgeInsets.only(top: 6),
                        itemCount: filteredClients.length,
                        separatorBuilder:
                            (context, index) => Container(
                              margin: const EdgeInsets.only(left: 72),
                              height: 0.5,
                              color: CupertinoColors.systemGrey5.withAlpha(128),
                            ),
                        itemBuilder: (context, index) {
                          final client = filteredClients[index];
                          return _buildClientCard(
                            client,
                            key: ValueKey(client['name']),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6.withAlpha(204),
        borderRadius: BorderRadius.circular(10),
      ),
      child: CupertinoTextField(
        controller: _searchController,
        placeholder: 'Buscar',
        placeholderStyle: const TextStyle(
          color: CupertinoColors.systemGrey,
          fontSize: 14,
        ),
        prefix: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Icon(
            CupertinoIcons.search,
            color: CupertinoColors.systemGrey,
            size: 16,
          ),
        ),
        suffix:
            _searchQuery.isNotEmpty
                ? GestureDetector(
                  onTap: () => _searchController.clear(),
                  child: const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(
                      CupertinoIcons.clear_circled_solid,
                      color: CupertinoColors.systemGrey,
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
        style: const TextStyle(fontSize: 14),
      ),
    );
  }

  Widget _buildSegmentedControl() {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: 44,
          child: Row(
            children: [
              Expanded(
                child: _buildCustomSegment(
                  'action',
                  l10n.clientsFilterAction,
                  _getActionCount(),
                ),
              ),
              Container(
                width: 1,
                height: 44,
                color: Colors.white.withAlpha(26),
              ),
              Expanded(
                child: _buildCustomSegment(
                  'pending',
                  l10n.clientsFilterPending,
                  _getPendingCount(),
                ),
              ),
              Container(
                width: 1,
                height: 44,
                color: Colors.white.withAlpha(26),
              ),
              Expanded(
                child: _buildCustomSegment(
                  'active',
                  l10n.clientsFilterCompleted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomSegment(String value, String label, [int? count]) {
    final isSelected = _selectedView == value;

    return GestureDetector(
      onTap: () => setState(() => _selectedView = value),
      child: Container(
        alignment: Alignment.center,
        color: isSelected ? AppTheme.primary.withAlpha(51) : Colors.transparent,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color:
                    isSelected ? AppTheme.primary : Colors.white.withAlpha(204),
              ),
            ),
            if (count != null && count > 0) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color:
                      isSelected
                          ? AppTheme.primary
                          : Colors.white.withAlpha(26),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color:
                        isSelected ? Colors.white : Colors.white.withAlpha(204),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final l10n = AppLocalizations.of(context)!;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.person_2,
            size: 48,
            color: CupertinoColors.systemGrey,
          ),
          const SizedBox(height: 12),
          Text(
            l10n.clientsEmptyStateTitle,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: CupertinoColors.systemGrey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.clientsEmptyStateMessage,
            style: const TextStyle(
              fontSize: 15,
              color: CupertinoColors.systemGrey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClientCard(Map<String, dynamic> client, {Key? key}) {
    return GestureDetector(
      key: key,
      onTap: () => context.push('/client-details', extra: client),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            _buildClientIcon(client),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    client['name'],
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: CupertinoColors.label,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        client['service'],
                        style: const TextStyle(
                          fontSize: 13,
                          color: CupertinoColors.systemGrey,
                        ),
                      ),
                      const SizedBox(width: 6),
                      _buildStatusIndicator(client['status']),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(
              CupertinoIcons.chevron_right,
              size: 14,
              color: CupertinoColors.systemGrey3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(String status) {
    final l10n = AppLocalizations.of(context)!;

    Color color;
    String localizedStatus;

    switch (status) {
      case STATUS_ACTION_REQUIRED:
        color = CupertinoColors.systemRed;
        localizedStatus = l10n.clientsStatusActionRequired;
        break;
      case STATUS_PENDING:
        color = CupertinoColors.systemOrange;
        localizedStatus = l10n.clientsStatusPending;
        break;
      case STATUS_ACTIVE:
        color = CupertinoColors.systemGreen;
        localizedStatus = l10n.clientsStatusActive;
        break;
      default:
        color = CupertinoColors.systemGrey;
        localizedStatus = status;
    }

    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          localizedStatus,
          style: TextStyle(
            fontSize: 13,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildClientIcon(Map<String, dynamic> client) {
    final bool isResidential = client['type'] == 'residential';

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color:
            isResidential
                ? CupertinoColors.systemGreen.withAlpha(26)
                : CupertinoColors.systemIndigo.withAlpha(26),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Icon(
          isResidential
              ? CupertinoIcons.person_fill
              : CupertinoIcons.building_2_fill,
          size: 20,
          color:
              isResidential
                  ? CupertinoColors.systemGreen
                  : CupertinoColors.systemIndigo,
        ),
      ),
    );
  }

  int _getActionCount() {
    return _clients.where((c) => c['status'] == STATUS_ACTION_REQUIRED).length;
  }

  int _getPendingCount() {
    return _clients.where((c) => c['status'] == STATUS_PENDING).length;
  }
}
