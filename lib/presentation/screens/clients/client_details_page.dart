import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../../core/theme/theme.dart';
import '../../../core/models/service_types.dart';
import '../../../presentation/layout/main_layout.dart';
import 'proposal_details_page.dart';
import 'document_submission_page.dart';
import '../services/services_page.dart';

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
    // Initialize CPE data based on client type
    if (widget.clientData['service'] == 'Energy') {
      cpeData = {
        'CPE001 - ${widget.clientData['address'] ?? 'Rua Principal 123, Porto'}':
            {
              'status': widget.clientData['status'],
              'steps': {
                'invoice': {
                  'completed': true,
                  'message': 'Fatura submetida com sucesso',
                },
                'contract': {'completed': true, 'message': 'Contrato recebido'},
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
        'CPE002 - Av. da Liberdade 45, Lisboa': {
          'status': 'Em Processo',
          'steps': {
            'invoice': {
              'completed': true,
              'message': 'Fatura submetida com sucesso',
            },
            'contract': {'completed': false, 'message': 'Aguardando contrato'},
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
    } else {
      cpeData = {};
    }

    if (cpeData.isNotEmpty) {
      selectedCPE = cpeData.keys.first;
    }
  }

  void _handleNewService() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => ServicesPage(
              preFilledData: {
                'companyName': widget.clientData['name'],
                'responsibleName': widget.clientData['responsibleName'] ?? '',
                'nif': widget.clientData['nif'],
                'email': widget.clientData['email'],
                'phone': widget.clientData['phone'],
                'address': widget.clientData['address'],
                'clientType':
                    widget.clientData['type'] == 'residential'
                        ? ClientType.residential
                        : ClientType.commercial,
              },
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      showNavigation: false,
      child: Column(
        children: [
          // Client Info Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.15),
                      width: 0.5,
                    ),
                  ),
                  child: Icon(
                    widget.clientData['type'] == 'residential'
                        ? Icons.person_outline
                        : Icons.business_outlined,
                    size: 20,
                    color: AppTheme.foreground.withOpacity(0.7),
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
                          color: AppTheme.foreground.withOpacity(0.7),
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
                    ).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _getStatusColor(
                        widget.clientData['status'],
                      ).withOpacity(0.3),
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
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.15),
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              CupertinoIcons.plus_circle,
                              color: AppTheme.primary,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Novo Serviço',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.foreground,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildClientInfoCard(),
                  const SizedBox(height: 16),
                  if (widget.clientData['service'] == 'Energy') ...[
                    _buildCPESelector(),
                    const SizedBox(height: 16),
                    if (selectedCPE != null) _buildProcessTimeline(),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClientInfoCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.15),
                width: 0.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Informações do Cliente',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.foreground.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 24),
                _buildInfoRow(
                  'Email',
                  widget.clientData['email'] ?? 'client@example.com',
                ),
                _buildInfoRow(
                  'Telefone',
                  widget.clientData['phone'] ?? '+351 123 456 789',
                ),
                _buildInfoRow('NIF', widget.clientData['nif'] ?? '123456789'),
                _buildInfoRow(
                  'Morada',
                  widget.clientData['address'] ??
                      'Rua Principal 123, 4000-123 Porto',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.foreground.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.foreground.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCPESelector() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.15),
                width: 0.5,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    selectedCPE ?? 'Selecione um CPE',
                    style: TextStyle(
                      color:
                          selectedCPE != null
                              ? AppTheme.foreground.withOpacity(0.9)
                              : AppTheme.foreground.withOpacity(0.5),
                      fontSize: 14,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.expand_more,
                    color: AppTheme.foreground.withOpacity(0.7),
                  ),
                  color: Colors.white,
                  elevation: 8,
                  position: PopupMenuPosition.under,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  itemBuilder:
                      (context) => [
                        for (final cpe in cpeData.keys)
                          PopupMenuItem(
                            value: cpe,
                            child: Text(
                              cpe,
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 14,
                              ),
                            ),
                          ),
                      ],
                  onSelected: (value) {
                    setState(() => selectedCPE = value);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProcessTimeline() {
    final currentCPE = cpeData[selectedCPE];
    if (currentCPE == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.15),
                width: 0.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Processo',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.foreground.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 24),
                _buildTimelineStep(
                  step: 1,
                  title: 'Fatura',
                  isCompleted: currentCPE['steps']['invoice']['completed'],
                  message: currentCPE['steps']['invoice']['message'],
                  showButton: false,
                ),
                _buildTimelineStep(
                  step: 2,
                  title: 'Proposta e Contrato',
                  isCompleted: currentCPE['steps']['contract']['completed'],
                  message: currentCPE['steps']['contract']['message'],
                  showButton: currentCPE['steps']['contract']['completed'],
                  buttonLabel: 'Ver Detalhes',
                  onButtonPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => ProposalDetailsPage(
                              proposalData: {
                                'commission': '2.500,00',
                                'expiryDate': '15/04/2024',
                                'status': 'pending',
                              },
                            ),
                      ),
                    );
                  },
                ),
                _buildTimelineStep(
                  step: 3,
                  title: 'Documentação',
                  isCompleted: currentCPE['steps']['documents']['completed'],
                  message: currentCPE['steps']['documents']['message'],
                  showButton: !currentCPE['steps']['documents']['completed'],
                  buttonLabel: 'Submeter Documentos',
                  onButtonPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const DocumentSubmissionPage(),
                      ),
                    );
                  },
                ),
                _buildTimelineStep(
                  step: 4,
                  title: 'Aprovação Final',
                  isCompleted: currentCPE['steps']['approval']['completed'],
                  message: currentCPE['steps']['approval']['message'],
                  showButton: false,
                  isLast: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineStep({
    required int step,
    required String title,
    required bool isCompleted,
    required String message,
    bool showButton = false,
    String? buttonLabel,
    VoidCallback? onButtonPressed,
    bool isLast = false,
  }) {
    return IntrinsicHeight(
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        isCompleted
                            ? const Color(0xFF40C057)
                            : Colors.white.withOpacity(0.08),
                    border: Border.all(
                      color:
                          isCompleted
                              ? const Color(0xFF40C057).withOpacity(0.3)
                              : Colors.white.withOpacity(0.15),
                      width: 0.5,
                    ),
                  ),
                  child: Center(
                    child:
                        isCompleted
                            ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 16,
                            )
                            : Text(
                              step.toString(),
                              style: TextStyle(
                                color: AppTheme.foreground.withOpacity(0.7),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color:
                          isCompleted
                              ? const Color(0xFF40C057).withOpacity(0.3)
                              : Colors.white.withOpacity(0.15),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.foreground.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.foreground.withOpacity(0.7),
                  ),
                ),
                if (showButton && buttonLabel != null) ...[
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: onButtonPressed,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: AppTheme.primary.withOpacity(0.3),
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        buttonLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                  ),
                ],
                if (!isLast) const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Ação Necessária':
        return const Color(0xFFFF6B6B);
      case 'Pendente':
        return const Color(0xFFFFBE0B);
      case 'Concluído':
        return const Color(0xFF40C057);
      default:
        return AppTheme.foreground;
    }
  }
}
