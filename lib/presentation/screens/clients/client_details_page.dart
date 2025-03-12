import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/utils/constants.dart';
import 'proposal_details_page.dart';
import 'document_submission_page.dart';

class ClientDetailsPage extends StatefulWidget {
  final Map<String, dynamic> clientData;

  const ClientDetailsPage({super.key, required this.clientData});

  @override
  State<ClientDetailsPage> createState() => _ClientDetailsPageState();
}

class _ClientDetailsPageState extends State<ClientDetailsPage> {
  String? selectedCPE;

  // Temporary data structure - replace with your actual data model
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detalhes do Cliente')),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildClientInfoCard(),
            const SizedBox(height: AppConstants.spacing16),
            if (widget.clientData['service'] == 'Energy') ...[
              _buildCPESelector(),
              const SizedBox(height: AppConstants.spacing16),
              if (selectedCPE != null) _buildProcessTimeline(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildClientInfoCard() {
    return Card(
      margin: const EdgeInsets.all(AppConstants.spacing16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.black,
                  child: Icon(
                    widget.clientData['type'] == 'residential'
                        ? Icons.person_outline
                        : Icons.business_outlined,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: AppConstants.spacing16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.clientData['name'], style: AppTextStyles.h3),
                      Text(
                        widget.clientData['type'] == 'residential'
                            ? 'Cliente Residencial'
                            : 'Cliente Comercial',
                        style: AppTextStyles.body2.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.spacing12,
                    vertical: AppConstants.spacing4,
                  ),
                  decoration: BoxDecoration(
                    color:
                        widget.clientData['status'] == 'Em Processo'
                            ? Colors.blue[50]
                            : Colors.green[50],
                    borderRadius: BorderRadius.circular(
                      AppConstants.borderRadius12,
                    ),
                  ),
                  child: Text(
                    widget.clientData['status'],
                    style: AppTextStyles.caption.copyWith(
                      color:
                          widget.clientData['status'] == 'Em Processo'
                              ? Colors.blue
                              : Colors.green,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.spacing24),
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
            _buildInfoRow('Serviço', widget.clientData['service']),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.spacing8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.caption.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 2),
          Text(value, style: AppTextStyles.body2),
        ],
      ),
    );
  }

  Widget _buildCPESelector() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: AppConstants.spacing16),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _showCPESelector,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CPE',
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      selectedCPE ?? 'Selecione um CPE',
                      style: AppTextStyles.body1,
                    ),
                  ],
                ),
              ),
              Icon(Icons.expand_more, color: Colors.grey[600]),
            ],
          ),
        ),
      ),
    );
  }

  void _showCPESelector() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Selecionar CPE', style: AppTextStyles.h3),
            ),
            const Divider(height: 1),
            ListView.builder(
              shrinkWrap: true,
              physics: const ClampingScrollPhysics(),
              itemCount: cpeData.length,
              itemBuilder: (context, index) {
                final cpe = cpeData.keys.elementAt(index);
                return RadioListTile(
                  value: cpe,
                  groupValue: selectedCPE,
                  title: Text(cpe),
                  onChanged: (value) {
                    setState(() {
                      selectedCPE = value as String;
                    });
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildProcessTimeline() {
    final currentCPE = cpeData[selectedCPE];
    if (currentCPE == null) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.all(AppConstants.spacing16),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Processo', style: AppTextStyles.h3),
            const SizedBox(height: AppConstants.spacing24),
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
                    color: isCompleted ? Colors.green : Colors.grey[300],
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
                                color: Colors.grey[600],
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                  ),
                ),
                if (!isLast)
                  Expanded(child: Container(width: 2, color: Colors.grey[300])),
              ],
            ),
          ),
          const SizedBox(width: AppConstants.spacing16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.body1.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: AppConstants.spacing4),
                Text(
                  message,
                  style: AppTextStyles.body2.copyWith(color: Colors.grey[600]),
                ),
                if (showButton && buttonLabel != null) ...[
                  const SizedBox(height: AppConstants.spacing8),
                  TextButton(
                    onPressed: onButtonPressed,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      alignment: Alignment.centerLeft,
                    ),
                    child: Text(buttonLabel),
                  ),
                ],
                if (!isLast) const SizedBox(height: AppConstants.spacing24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
