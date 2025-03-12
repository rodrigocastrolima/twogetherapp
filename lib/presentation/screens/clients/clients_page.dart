import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../../core/theme/theme.dart';
import '../../../core/theme/text_styles.dart';
import '../../../presentation/screens/clients/client_details_page.dart';
import 'dart:math';

class ClientsPage extends StatefulWidget {
  const ClientsPage({super.key});

  @override
  State<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends State<ClientsPage> {
  String? _selectedServiceType;

  // Temporary data for demonstration
  final List<Map<String, dynamic>> _clients = [
    {
      'name': 'João Silva',
      'type': 'residential',
      'service': 'Energy',
      'status': 'Em Processo',
    },
    {
      'name': 'Tech Solutions Lda',
      'type': 'commercial',
      'service': 'Insurance',
      'status': 'Em Processo',
    },
    {
      'name': 'Maria Santos',
      'type': 'residential',
      'service': 'Telecommunications',
      'status': 'Concluído',
    },
    {
      'name': 'Green Energy Corp',
      'type': 'commercial',
      'service': 'Energy',
      'status': 'Em Processo',
    },
  ];

  List<Map<String, dynamic>> get filteredClients {
    if (_selectedServiceType == null) return _clients;
    return _clients
        .where((client) => client['service'] == _selectedServiceType)
        .toList();
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppTheme.charcoal,
        fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
      ),
      backgroundColor: Colors.transparent,
      selectedColor: AppTheme.charcoal,
      side: BorderSide(
        color: selected ? AppTheme.charcoal : AppTheme.silver.withAlpha(128),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.clientsPageTitle ?? 'Clientes'),
        scrolledUnderElevation: 0,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            color: Theme.of(context).colorScheme.surface,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip(
                    label: l10n.clientsPageAllServices,
                    selected: _selectedServiceType == null,
                    onTap: () => setState(() => _selectedServiceType = null),
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    label: l10n.servicesEnergy,
                    selected: _selectedServiceType == 'Energy',
                    onTap:
                        () => setState(
                          () =>
                              _selectedServiceType =
                                  _selectedServiceType == 'Energy'
                                      ? null
                                      : 'Energy',
                        ),
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    label: l10n.servicesInsurance,
                    selected: _selectedServiceType == 'Insurance',
                    onTap:
                        () => setState(
                          () =>
                              _selectedServiceType =
                                  _selectedServiceType == 'Insurance'
                                      ? null
                                      : 'Insurance',
                        ),
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    label: l10n.servicesTelco,
                    selected: _selectedServiceType == 'Telecommunications',
                    onTap:
                        () => setState(
                          () =>
                              _selectedServiceType =
                                  _selectedServiceType == 'Telecommunications'
                                      ? null
                                      : 'Telecommunications',
                        ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filteredClients.length,
              itemBuilder: (context, index) {
                final client = filteredClients[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      final Map<String, dynamic> clientDetails = {
                        ...client,
                        'email':
                            '${client['name'].toString().toLowerCase().replaceAll(' ', '.')}@example.com',
                        'phone':
                            '+351 ${List.generate(9, (index) => (index == 0 ? '9' : Random().nextInt(10)).toString()).join()}',
                        'nif':
                            List.generate(
                              9,
                              (index) => Random().nextInt(10),
                            ).join(),
                        'address':
                            client['type'] == 'residential'
                                ? 'Rua Principal ${Random().nextInt(100)}, ${Random().nextInt(1000)}-${Random().nextInt(1000)} Porto'
                                : 'Av. da Liberdade ${Random().nextInt(200)}, ${Random().nextInt(1000)}-${Random().nextInt(1000)} Lisboa',
                      };

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) =>
                                  ClientDetailsPage(clientData: clientDetails),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              client['type'] == 'residential'
                                  ? Icons.person_outline
                                  : Icons.business_outlined,
                              size: 28,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  client['name'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  client['service'],
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        client['status'] == 'Em Processo'
                                            ? Colors.blue.shade50
                                            : Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    client['status'],
                                    style: TextStyle(
                                      fontSize: 12,
                                      color:
                                          client['status'] == 'Em Processo'
                                              ? Colors.blue.shade700
                                              : Colors.green.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right, color: Colors.grey[400]),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
