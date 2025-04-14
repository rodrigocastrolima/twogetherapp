import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/theme.dart';
import '../../../core/models/service_types.dart';
import '../services/services_page.dart';
import '../../../core/theme/ui_styles.dart';
import '../../../core/utils/constants.dart'; // Import constants

class ClientDetailsPage extends StatefulWidget {
  final Map<String, dynamic> clientData;

  const ClientDetailsPage({super.key, required this.clientData});

  @override
  State<ClientDetailsPage> createState() => _ClientDetailsPageState();
}

class _ClientDetailsPageState extends State<ClientDetailsPage> {
  String? selectedCPE;
  late final Map<String, Map<String, dynamic>> cpeData;

  @override
  void initState() {
    super.initState();
    // Initialize CPE data based on client type and client
    if (widget.clientData['service'] == 'Energy') {
      if (widget.clientData['name'] == 'Green Energy Corp') {
        // For Green Energy Corp - proposal accepted, documents needed
        cpeData = {
          'CPE001 - ${widget.clientData['address'] ?? 'Av. da Liberdade 45, Lisboa'}':
              {
                'status': widget.clientData['status'],
                'steps': {
                  'invoice': {
                    'completed': true,
                    'message': 'Fatura submetida com sucesso',
                  },
                  'contract': {
                    'completed': true,
                    'message': 'Proposta aceita em 12/03/2024',
                  },
                  'documents': {
                    'completed': false,
                    'needsAction': true,
                    'message': 'Documentação pendente. Ação necessária.',
                  },
                  'approval': {
                    'completed': false,
                    'message': 'Aguardando aprovação final',
                  },
                },
              },
        };
      } else {
        // For João Silva - waiting for proposal approval (unchanged)
        cpeData = {
          'CPE001 - ${widget.clientData['address'] ?? 'Rua Principal 123, Porto'}':
              {
                'status': widget.clientData['status'],
                'steps': {
                  'invoice': {
                    'completed': true,
                    'message': 'Fatura submetida com sucesso',
                  },
                  'contract': {
                    'completed': false,
                    'needsAction': true,
                    'message': 'Proposta recebida. Aguardando aprovação',
                  },
                  'documents': {
                    'completed': false,
                    'message': 'Indisponível até aprovação da proposta',
                  },
                  'approval': {
                    'completed': false,
                    'message': 'Aguardando aprovação final',
                  },
                },
              },
          'CPE002 - Av. da Liberdade 45, Lisboa': {
            'status': 'Em Processo',
            'steps': {
              'invoice': {
                'completed': true,
                'message': 'Fatura submetida com sucesso',
              },
              'contract': {
                'completed': false,
                'message': 'Aguardando contrato',
              },
              'documents': {
                'completed': false,
                'message': 'Aguardando submissão de documentos',
              },
              'approval': {
                'completed': false,
                'message': 'Aguardando aprovação final',
              },
            },
          },
        };
      }
    } else {
      cpeData = {};
    }

    if (cpeData.isNotEmpty) {
      selectedCPE = cpeData.keys.first;
    }
  }

  void _handleNewService() {
    // Create prefilled data map
    final preFilledData = {
      'companyName':
          widget.clientData['type'] != 'residential'
              ? widget.clientData['name']
              : null,
      'responsibleName':
          widget.clientData['responsibleName'] ??
          widget.clientData['name'], // Use client name if no responsible name
        'nif': widget.clientData['nif'],
        'email': widget.clientData['email'],
        'phone': widget.clientData['phone'],
        'address': widget.clientData['address'],
        'clientType':
            widget.clientData['type'] == 'residential'
                ? ClientType.residential
                : ClientType.commercial,
    };

    // Use GoRouter to navigate, pushing the new route
    context.push('/services', extra: preFilledData);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Wrap content in Scaffold and AppBar
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.chevron_left),
          onPressed: () => context.pop(),
        ),
        title: Text(widget.clientData['name'] ?? 'Detalhes do Cliente'),
        centerTitle: true,
      ),
      body: _buildClientDetailsContent(theme),
    );
  }

  Widget _buildClientDetailsContent(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(
        bottom: AppConstants.spacing16,
      ), // Add bottom padding
      child: Column(
      children: [
          const SizedBox(height: 16), // Add top padding
        // Client Info Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white.withAlpha(38),
                    width: 0.5,
                  ),
                ),
                child: Icon(
                  widget.clientData['type'] == 'residential'
                      ? Icons.person_outline
                      : Icons.business_outlined,
                  size: 20,
                  color: AppTheme.foreground.withAlpha(179),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.clientData['name'],
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.clientData['type'] == 'residential'
                          ? 'Cliente Residencial'
                          : 'Cliente Comercial',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.foreground.withAlpha(178),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                decoration: BoxDecoration(
                  color: _getStatusColor(
                    widget.clientData['status'],
                  ).withAlpha(15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _getStatusColor(
                      widget.clientData['status'],
                    ).withAlpha(30),
                    width: 0.5,
                  ),
                ),
                child: Text(
                  widget.clientData['status'],
                  style: TextStyle(
                    fontSize: 12,
                    color: _getStatusColor(widget.clientData['status']),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // New Service Button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _handleNewService,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(20),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withAlpha(38),
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withAlpha(15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            CupertinoIcons.plus_circle,
                            color: AppTheme.primary,
                            size: 16,
                          ),
                        ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Text(
                              'Adicionar Novo Serviço',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          Icon(
                            CupertinoIcons.chevron_right,
                            size: 16,
                            color: AppTheme.foreground.withAlpha(128),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

          const SizedBox(height: 24),

          // Client Details Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildSection(
            context,
              title: 'Detalhes do Cliente',
              children: [
                _buildDetailItem(
                  'NIF',
                  widget.clientData['nif'] ?? '-',
                  icon: Icons.badge_outlined,
                ),
                _buildDetailItem(
                  'Email',
                  widget.clientData['email'] ?? '-',
                  icon: Icons.email_outlined,
                ),
                _buildDetailItem(
                  'Telefone',
                  widget.clientData['phone'] ?? '-',
                  icon: Icons.phone_outlined,
                ),
                _buildDetailItem(
                  'Endereço',
                  widget.clientData['address'] ?? '-',
                  icon: Icons.location_on_outlined,
                ),
                if (widget.clientData['responsibleName'] != null &&
                    widget.clientData['responsibleName'].isNotEmpty)
                  _buildDetailItem(
                    'Responsável',
                    widget.clientData['responsibleName'],
                    icon: Icons.person_pin_outlined,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // CPE Selection Dropdown (if applicable)
          if (cpeData.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Contratos / Serviços (CPE)',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildDropdown(),
                ],
              ),
            ),

          // Progress Steps (if CPE is selected)
          if (selectedCPE != null && cpeData[selectedCPE!] != null)
            _buildProgressSteps(cpeData[selectedCPE!]!['steps']),
        ],
      ),
    );
  }

  // Helper to build detail items
  Widget _buildDetailItem(
    String label,
    String value, {
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.mutedForeground),
          const SizedBox(width: 12),
          Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
                    color: AppTheme.mutedForeground,
            ),
          ),
                const SizedBox(height: 2),
          Text(
            value,
                  style: const TextStyle(
              fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper to build section containers
  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
          padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
            color: Colors.white.withAlpha(15),
              borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withAlpha(30), width: 0.5),
            ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              ...children,
              ],
          ),
        ),
      ),
    );
  }

  // Helper to build CPE dropdown
  Widget _buildDropdown() {
    return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withAlpha(38), width: 0.5),
            ),
          child: DropdownButton<String>(
            value: selectedCPE,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            icon: Icon(
              CupertinoIcons.chevron_down,
              color: AppTheme.mutedForeground,
              size: 16,
                ),
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.foreground,
            ), // Ensure dropdown text color matches
            dropdownColor: AppTheme.popoverBackground, // Use popover background
            items:
                cpeData.keys.map((String cpe) {
                  return DropdownMenuItem<String>(
                    value: cpe,
                    child: Text(
                      cpe, // Display full CPE string (includes address)
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
            onChanged: (String? newValue) {
              if (newValue != null) {
                setState(() {
                  selectedCPE = newValue;
                });
              }
            },
          ),
        ),
      ),
    );
  }

  // Helper to build progress steps
  Widget _buildProgressSteps(Map<String, dynamic> stepsData) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Progresso do Serviço',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          _buildStepItem('Fatura', stepsData['invoice'], isFirst: true),
          _buildStepItem('Contrato', stepsData['contract']),
          _buildStepItem('Documentos', stepsData['documents']),
          _buildStepItem(
            'Aprovação Final',
            stepsData['approval'],
            isLast: true,
          ),
        ],
      ),
    );
  }

  // Helper to build individual step item
  Widget _buildStepItem(
    String title,
    Map<String, dynamic> stepInfo, {
    bool isFirst = false,
    bool isLast = false,
  }) {
    final bool completed = stepInfo['completed'] ?? false;
    final bool needsAction = stepInfo['needsAction'] ?? false;
    final String message = stepInfo['message'] ?? '';
    final Color activeColor = needsAction ? AppTheme.warning : AppTheme.success;
    final Color color = completed ? activeColor : AppTheme.muted;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Vertical line and icon column
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
              children: [
              // Top line (unless first)
              if (!isFirst) Container(width: 1, height: 10, color: color),
              // Icon
                Container(
                padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                  border: Border.all(color: color, width: 1),
                  color: completed ? color.withAlpha(51) : Colors.transparent,
                  ),
                child: Icon(
                  completed ? Icons.check : Icons.circle_outlined,
                  size: 12,
                  color: completed ? color : AppTheme.mutedForeground,
                ),
              ),
              // Bottom line (unless last)
              if (!isLast) Expanded(child: Container(width: 1, color: color)),
              ],
          ),
          const SizedBox(width: 16),
          // Text content column
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: completed ? color : AppTheme.foreground,
                    fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                Text(
                  message,
                        style: TextStyle(
                          fontSize: 12,
                      color: completed ? color : AppTheme.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper to get status color
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'ativo':
      case 'contrato ativo':
        return AppTheme.success;
      case 'pendente':
      case 'em processo':
      case 'aguardando aprovação':
        return AppTheme.warning;
      case 'rejeitado':
      case 'cancelado':
        return AppTheme.destructive;
      default:
        return AppTheme.mutedForeground;
    }
  }
}
