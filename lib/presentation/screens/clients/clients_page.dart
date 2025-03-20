import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../../core/theme/theme.dart';
import 'client_details_page.dart';

class ClientsPage extends StatefulWidget {
  const ClientsPage({super.key});

  @override
  State<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends State<ClientsPage> {
  String _selectedView = 'action';
  final TextEditingController _searchController = TextEditingController();
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

  // Temporary data for demonstration
  final List<Map<String, dynamic>> _clients = [
    {
      'name': 'João Silva',
      'type': 'residential',
      'service': 'Energy',
      'status': 'Ação Necessária',
      'stage': 'Contrato',
    },
    {
      'name': 'Tech Solutions Lda',
      'type': 'commercial',
      'service': 'Insurance',
      'status': 'Pendente',
      'stage': 'Documentação',
    },
    {
      'name': 'Maria Santos',
      'type': 'residential',
      'service': 'Telecommunications',
      'status': 'Ativo',
      'stage': 'Instalação',
    },
    {
      'name': 'Green Energy Corp',
      'type': 'commercial',
      'service': 'Energy',
      'status': 'Ação Necessária',
      'stage': 'Validação',
    },
  ];

  List<Map<String, dynamic>> get filteredClients {
    return _clients.where((client) {
      // Filter by search query
      if (_searchQuery.isNotEmpty &&
          !client['name'].toLowerCase().contains(_searchQuery)) {
        return false;
      }

      // Filter by view
      if (_selectedView == 'action' && client['status'] != 'Ação Necessária')
        return false;
      if (_selectedView == 'pending' && client['status'] != 'Pendente')
        return false;
      if (_selectedView == 'active' && client['status'] != 'Ativo')
        return false;

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
                  Expanded(
                    child: _buildSearchBar(),
                  ),
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
              color: CupertinoColors.systemGrey4.withOpacity(0.5),
            ),
            
            // Client list
            Expanded(
              child: filteredClients.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                      padding: const EdgeInsets.only(top: 6),
                      itemCount: filteredClients.length,
                      separatorBuilder: (context, index) => Container(
                        margin: const EdgeInsets.only(left: 72),
                        height: 0.5,
                        color: CupertinoColors.systemGrey5.withOpacity(0.5),
                      ),
                      itemBuilder: (context, index) => _buildClientCard(filteredClients[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _getViewTitle() {
    switch (_selectedView) {
      case 'action':
        return 'Ação Necessária';
      case 'pending':
        return 'Em Análise';
      case 'active':
        return 'Concluídos';
      default:
        return 'Clientes';
    }
  }

  Widget _buildSearchBar() {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6.withOpacity(0.8),
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
        suffix: _searchQuery.isNotEmpty
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
        style: const TextStyle(
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildSegmentedControl() {
    return Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                          child: Container(
          height: 44,
          child: Row(
            children: [
              Expanded(
                child: _buildCustomSegment(
                  'action',
                  'Ação',
                  _getActionCount(),
                ),
              ),
              Container(
                width: 1,
                height: 44,
                color: Colors.white.withOpacity(0.1),
              ),
              Expanded(
                child: _buildCustomSegment(
                  'pending',
                  'Pendente',
                  _getPendingCount(),
                ),
              ),
              Container(
                width: 1,
                height: 44,
                color: Colors.white.withOpacity(0.1),
              ),
              Expanded(
                child: _buildCustomSegment(
                  'active',
                  'Concluídos',
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
        color: isSelected ? AppTheme.primary.withOpacity(0.2) : Colors.transparent,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? AppTheme.primary : Colors.white.withOpacity(0.8),
              ),
            ),
            if (count != null && count > 0) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected 
                    ? AppTheme.primary 
                    : Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected 
                      ? Colors.white 
                      : Colors.white.withOpacity(0.8),
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
          const Text(
            'Nenhum cliente encontrado',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: CupertinoColors.systemGrey,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tente modificar sua pesquisa',
            style: TextStyle(
              fontSize: 15,
              color: CupertinoColors.systemGrey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClientCard(Map<String, dynamic> client) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () => Navigator.push(
        context,
        CupertinoPageRoute(
          builder: (context) => ClientDetailsPage(clientData: client),
        ),
      ),
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
    Color color;
    switch (status) {
      case 'Ação Necessária':
        color = CupertinoColors.systemRed;
        break;
      case 'Pendente':
        color = CupertinoColors.systemOrange;
        break;
      case 'Ativo':
        color = CupertinoColors.systemGreen;
        break;
      default:
        color = CupertinoColors.systemGrey;
    }

    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          status,
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
        color: isResidential 
            ? CupertinoColors.systemGreen.withOpacity(0.1)
            : CupertinoColors.systemIndigo.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Icon(
          isResidential
              ? CupertinoIcons.person_fill
              : CupertinoIcons.building_2_fill,
          size: 20,
          color: isResidential
              ? CupertinoColors.systemGreen
              : CupertinoColors.systemIndigo,
        ),
      ),
    );
  }

  int _getActionCount() {
    return _clients.where((c) => c['status'] == 'Ação Necessária').length;
  }

  int _getPendingCount() {
    return _clients.where((c) => c['status'] == 'Pendente').length;
  }
}
