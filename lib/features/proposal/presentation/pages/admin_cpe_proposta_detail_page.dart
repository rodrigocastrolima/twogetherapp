import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../presentation/widgets/logo.dart';
import '../../../../presentation/widgets/app_loading_indicator.dart';
import '../../../../presentation/widgets/secure_file_viewer.dart';
import '../../../../presentation/widgets/success_dialog.dart';
import '../../../../presentation/widgets/app_input_field.dart';
import '../../../../core/services/salesforce_auth_service.dart';
import '../../../../core/services/file_icon_service.dart';
import '../../data/models/cpe_proposta_detail.dart'; // To be created
import '../providers/cpe_proposta_providers.dart'; // To be created
import '../providers/proposal_providers.dart'; // <-- ADDED IMPORT for proposal service

class AdminCpePropostaDetailPage extends ConsumerStatefulWidget {
  final String cpePropostaId;
  const AdminCpePropostaDetailPage({required this.cpePropostaId, super.key});

  @override
  ConsumerState<AdminCpePropostaDetailPage> createState() => _AdminCpePropostaDetailPageState();
}

class _AdminCpePropostaDetailPageState extends ConsumerState<AdminCpePropostaDetailPage> {
  bool _isEditing = false;
  bool _isSaving = false;
  final Map<String, TextEditingController> _controllers = {};
  final List<PlatformFile> _filesToAdd = []; // <-- ADDED file picking state
  final List<dynamic> _filesToDelete = []; // <-- ADDED file deletion state

  // --- Dropdown state variables ---
  String? _selectedSolucao;
  String? _selectedStatus;
  String? _selectedVisitaTecnica;
  DateTime? _selectedPagamentoFacturaDate;

  // --- Picklist options ---
  final List<String> _solucaoOptions = const [
    '--Nenhum --',
    'LEC',
    'PAP',
    'PP',
    'Energia',
    'Gás',
  ];

  final List<String> _statusOptions = const [
    '--Nenhum --',
    'Activo',
    'Não activo',
  ];

  final List<String> _visitaTecnicaOptions = const [
    '--Nenhum --',
    'Em agendamento',
    'Concluída - OK',
    'Concluída - not OK',
  ];

  @override
  void dispose() {
    // Dispose all controllers
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _initializeControllers(CpePropostaDetail detail) {
    // Only initialize if not already initialized
    if (_controllers.isNotEmpty) return;
    
    // CPE fields (editable)
    _controllers['consumoAnualEsperadoKwhC'] = TextEditingController(text: detail.cpe?.consumoAnualEsperadoKwhC?.toString() ?? '');
    _controllers['fidelizacaoAnosC'] = TextEditingController(text: detail.cpe?.fidelizacaoAnosC?.toString() ?? '');
    
    // CPE_Proposta fields (editable)
    _controllers['consumoOuPotenciaPicoC'] = TextEditingController(text: detail.consumoOuPotenciaPicoC?.toString() ?? '');
    _controllers['fidelizacaoAnosCpeProposta'] = TextEditingController(text: detail.fidelizacaoAnosC?.toString() ?? '');
    _controllers['margemComercialC'] = TextEditingController(text: detail.margemComercialC?.toString() ?? '');
    _controllers['responsavelNegocioRetailC'] = TextEditingController(text: detail.responsavelNegocioRetailC ?? '');
    _controllers['responsavelNegocioExclusivoC'] = TextEditingController(text: detail.responsavelNegocioExclusivoC ?? '');
    _controllers['gestorDeRevendaC'] = TextEditingController(text: detail.gestorDeRevendaC ?? '');
    _controllers['comissaoRetailC'] = TextEditingController(text: detail.comissaoRetailC?.toString() ?? '');
    _controllers['notaInformativaC'] = TextEditingController(text: detail.notaInformativaC ?? '');
    _controllers['facturaRetailC'] = TextEditingController(text: detail.facturaRetailC ?? '');

    // Initialize dropdown values
    _selectedSolucao = _solucaoOptions.contains(detail.cpe?.solucaoC) ? detail.cpe?.solucaoC : _solucaoOptions.first;
    _selectedStatus = _statusOptions.contains(detail.statusC) ? detail.statusC : _statusOptions.first;
    _selectedVisitaTecnica = _visitaTecnicaOptions.contains(detail.visitaTecnicaC) ? detail.visitaTecnicaC : _visitaTecnicaOptions.first;
    
    // Initialize date value
    if (detail.pagamentoDaFacturaRetailC != null) {
      try {
        _selectedPagamentoFacturaDate = DateTime.parse(detail.pagamentoDaFacturaRetailC!);
      } catch (e) {
        _selectedPagamentoFacturaDate = null;
      }
    }
  }

  // --- File Picker Logic (copied from admin_salesforce_proposal_detail_page.dart) ---
  Future<void> _pickFiles() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: true,
        type: FileType.any,
      );

      if (!mounted) return;

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _filesToAdd.addAll(result.files.where((file) => file.bytes != null));
        });
        if (result.files.any((file) => file.bytes == null)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Some files could not be read.')),
            );
          }
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File picking cancelled.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking files: $e')),
        );
      }
    }
  }

  Future<void> _saveChanges() async {
    if (_isSaving) return;
    
    setState(() {
      _isSaving = true;
    });

    try {
      // Get Salesforce credentials
      final auth = ref.read(salesforceAuthProvider.notifier);
      if (auth.currentAccessToken == null || auth.currentInstanceUrl == null) {
        throw Exception('Credenciais do Salesforce não encontradas');
      }

      // Get access token and instance URL
      final String? accessToken = await auth.getValidAccessToken();
      final String? instanceUrl = auth.currentInstanceUrl;

      if (accessToken == null || instanceUrl == null) {
        throw Exception('Não foi possível obter as credenciais do Salesforce');
      }

      // Process file operations
      final proposalService = ref.read(salesforceProposalServiceProvider);
      final filesToDelete = List<dynamic>.from(_filesToDelete);
      final filesToAdd = List<PlatformFile>.from(_filesToAdd);

      // Clear state lists
      _filesToDelete.clear();
      _filesToAdd.clear();

      // Process file deletions
      if (filesToDelete.isNotEmpty) {
        await Future.wait(
          filesToDelete.map((file) async {
            try {
              await proposalService.deleteFile(
                accessToken: accessToken,
                instanceUrl: instanceUrl,
                contentDocumentId: file.id,
              );
            } catch (e) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Falha ao eliminar ficheiro: ${file.title}'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          }),
        );
      }

      // Process file uploads
      if (filesToAdd.isNotEmpty) {
        await Future.wait(
          filesToAdd.map((file) async {
            if (file.bytes == null) return;
            try {
              final contentDocId = await proposalService.uploadFile(
                accessToken: accessToken,
                instanceUrl: instanceUrl,
                parentId: widget.cpePropostaId,
                fileName: file.name,
                fileBytes: file.bytes!,
              );
              if (contentDocId == null && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Falha ao carregar ficheiro: ${file.name}'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            } catch (e) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Erro ao carregar ficheiro: ${file.name}'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          }),
        );
      }

      // Prepare CPE fields to update
      final cpeFieldsToUpdate = <String, dynamic>{};
      final consumoAnual = double.tryParse(_controllers['consumoAnualEsperadoKwhC']!.text);
      if (consumoAnual != null) cpeFieldsToUpdate['Consumo_anual_esperado_KWh__c'] = consumoAnual;
      
      final fidelizacao = int.tryParse(_controllers['fidelizacaoAnosC']!.text);
      if (fidelizacao != null) cpeFieldsToUpdate['Fideliza_o_Anos__c'] = fidelizacao;
      
      // Handle Solução dropdown (convert --Nenhum -- to null)
      final solucaoValue = (_selectedSolucao == '--Nenhum --') ? null : _selectedSolucao;
      cpeFieldsToUpdate['Solu_o__c'] = solucaoValue;

      // Prepare CPE_Proposta fields to update
      final cpePropostaFieldsToUpdate = <String, dynamic>{};
      
      // Handle Status dropdown (convert --Nenhum -- to null)
      final statusValue = (_selectedStatus == '--Nenhum --') ? null : _selectedStatus;
      cpePropostaFieldsToUpdate['Status__c'] = statusValue;
      
      final consumoPotencia = double.tryParse(_controllers['consumoOuPotenciaPicoC']!.text);
      if (consumoPotencia != null) cpePropostaFieldsToUpdate['Consumo_ou_Pot_ncia_Pico__c'] = consumoPotencia;
      
      final fidelizacaoProposta = int.tryParse(_controllers['fidelizacaoAnosCpeProposta']!.text);
      if (fidelizacaoProposta != null) cpePropostaFieldsToUpdate['Fideliza_o_Anos__c'] = fidelizacaoProposta;
      
      final margemComercial = double.tryParse(_controllers['margemComercialC']!.text);
      if (margemComercial != null) cpePropostaFieldsToUpdate['Margem_Comercial__c'] = margemComercial;
      
      if (_controllers['responsavelNegocioRetailC']!.text.isNotEmpty) {
        cpePropostaFieldsToUpdate['Respons_vel_de_Neg_cio_Retail__c'] = _controllers['responsavelNegocioRetailC']!.text;
      }
      
      if (_controllers['responsavelNegocioExclusivoC']!.text.isNotEmpty) {
        cpePropostaFieldsToUpdate['Respons_vel_de_Neg_cio_Exclusivo__c'] = _controllers['responsavelNegocioExclusivoC']!.text;
      }
      
      if (_controllers['gestorDeRevendaC']!.text.isNotEmpty) {
        cpePropostaFieldsToUpdate['Gestor_de_Revenda__c'] = _controllers['gestorDeRevendaC']!.text;
      }
      
      final comissaoRetail = double.tryParse(_controllers['comissaoRetailC']!.text);
      if (comissaoRetail != null) cpePropostaFieldsToUpdate['Comiss_o_Retail__c'] = comissaoRetail;
      
      if (_controllers['notaInformativaC']!.text.isNotEmpty) {
        cpePropostaFieldsToUpdate['Nota_Informativa__c'] = _controllers['notaInformativaC']!.text;
      }
      
      // Handle Pagamento da Factura Retail date field
      if (_selectedPagamentoFacturaDate != null) {
        // Format date as YYYY-MM-DD for Salesforce
        final formattedDate = _selectedPagamentoFacturaDate!.toIso8601String().split('T')[0];
        cpePropostaFieldsToUpdate['Pagamento_da_Factura_Retail__c'] = formattedDate;
      } else {
        cpePropostaFieldsToUpdate['Pagamento_da_Factura_Retail__c'] = null;
      }
      
      if (_controllers['facturaRetailC']!.text.isNotEmpty) {
        cpePropostaFieldsToUpdate['Factura_Retail__c'] = _controllers['facturaRetailC']!.text;
      }
      
      // Handle Visita Técnica dropdown (convert --Nenhum -- to null)
      final visitaTecnicaValue = (_selectedVisitaTecnica == '--Nenhum --') ? null : _selectedVisitaTecnica;
      cpePropostaFieldsToUpdate['Visita_T_cnica__c'] = visitaTecnicaValue;

      // Call the cloud function to update CPE-Proposta
      if (cpeFieldsToUpdate.isNotEmpty || cpePropostaFieldsToUpdate.isNotEmpty) {
        final callable = FirebaseFunctions.instance.httpsCallable('updateCpePropostaDetails');
        await callable.call({
          'cpePropostaId': widget.cpePropostaId,
          'accessToken': accessToken,
          'instanceUrl': instanceUrl,
          'cpeFieldsToUpdate': cpeFieldsToUpdate.isNotEmpty ? cpeFieldsToUpdate : null,
          'cpePropostaFieldsToUpdate': cpePropostaFieldsToUpdate.isNotEmpty ? cpePropostaFieldsToUpdate : null,
        });
      }

      // Refresh the data
      final _ = ref.refresh(cpePropostaDetailProvider(widget.cpePropostaId));
      
      // Exit edit mode and show success dialog
      if (mounted) {
        await showSuccessDialog(
          context: context,
          message: 'Alterações guardadas com sucesso!',
          onDismissed: () {
            setState(() {
              _isEditing = false;
            });
          },
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao guardar alterações: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final detailsAsync = ref.watch(cpePropostaDetailProvider(widget.cpePropostaId));

    return detailsAsync.when(
      loading: () => const AppLoadingIndicator(),
      error: (error, stack) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Erro ao carregar detalhes da CPE-Proposta:\n$error',
              style: TextStyle(color: theme.colorScheme.error),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
      data: (detail) {
        // Initialize controllers with data
        _initializeControllers(detail);
        
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: Icon(CupertinoIcons.chevron_left, color: theme.colorScheme.onSurface),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            title: LogoWidget(height: 60, darkMode: theme.brightness == Brightness.dark),
            centerTitle: true,
            elevation: 0,
            backgroundColor: Colors.transparent,
            scrolledUnderElevation: 0.0,
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 32, left: 24, right: 24, bottom: 16),
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        Center(
                          child: Text(
                            detail.name ?? 'Detalhes da CPE-Proposta',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                              fontSize: 28,
                            ),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Positioned(
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(8), // Extra padding for hover/click area
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    _isEditing ? Icons.close : CupertinoIcons.pencil,
                                    color: _isEditing ? theme.colorScheme.error : theme.colorScheme.onSurface,
                                    size: 28,
                                  ),
                                  tooltip: _isEditing ? 'Cancelar Edição' : 'Editar',
                                  onPressed: _isEditing ? () {
                                    setState(() {
                                      _isEditing = false;
                                    });
                                  } : () {
                                    setState(() {
                                      _isEditing = true;
                                    });
                                  },
                                ),
                                if (_isEditing)
                                  const SizedBox(width: 8),
                                if (_isEditing)
                                  SizedBox(
                                    width: 44,
                                    height: 44,
                                    child: IconButton(
                                      icon: _isSaving
                                          ? SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.5,
                                                valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                                              ),
                                            )
                                          : Icon(
                                              Icons.save_outlined,
                                              color: theme.colorScheme.primary,
                                              size: 28,
                                            ),
                                      onPressed: _isSaving ? null : _saveChanges,
                                      tooltip: 'Guardar',
                                      style: IconButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        shape: const CircleBorder(),
                                        padding: const EdgeInsets.all(0),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(16.0),
                      children: [
                        _buildDetailSectionTwoColumn(
                          context,
                          'Informação da Empresa',
                          [
                            [
                              AppInputField(controller: TextEditingController(text: detail.cpe?.name ?? ''), label: 'CPE', readOnly: true),
                              const SizedBox(height: 8),
                              AppInputField(controller: TextEditingController(text: detail.cpe?.entidadeName ?? ''), label: 'Entidade', readOnly: true),
                            ],
                            [
                              AppInputField(controller: TextEditingController(text: detail.cpe?.nifC ?? ''), label: 'NIF', readOnly: true),
                            ],
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildDetailSectionTwoColumn(
                          context,
                          'Informação do Local',
                          [
                            [
                              _isEditing
                                ? AppInputField(controller: _controllers['consumoAnualEsperadoKwhC']!, label: 'Consumo anual esperado (KWh)')
                                : AppInputField(controller: TextEditingController(text: detail.cpe?.consumoAnualEsperadoKwhC?.toString() ?? ''), label: 'Consumo anual esperado (KWh)', readOnly: true),
                              const SizedBox(height: 8),
                              _isEditing
                                ? AppInputField(controller: _controllers['fidelizacaoAnosC']!, label: 'Fidelização (Anos)')
                                : AppInputField(controller: TextEditingController(text: detail.cpe?.fidelizacaoAnosC?.toString() ?? ''), label: 'Fidelização (Anos)', readOnly: true),
                            ],
                            [
                              _isEditing
                                ? AppDropdownField<String>(
                                    label: 'Solução',
                                    value: _selectedSolucao,
                                    items: _solucaoOptions.map((s) => DropdownMenuItem<String>(value: s, child: Text(s))).toList(),
                                    onChanged: (v) => setState(() => _selectedSolucao = v),
                                  )
                                : AppInputField(controller: TextEditingController(text: detail.cpe?.solucaoC ?? ''), label: 'Solução', readOnly: true),
                            ],
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildDetailSectionTwoColumn(
                          context,
                          'Informação da Proposta',
                          [
                            [
                              _isEditing
                                ? AppDropdownField<String>(
                                    label: 'Status',
                                    value: _selectedStatus,
                                    items: _statusOptions.map((s) => DropdownMenuItem<String>(value: s, child: Text(s))).toList(),
                                    onChanged: (v) => setState(() => _selectedStatus = v),
                                  )
                                : AppInputField(controller: TextEditingController(text: detail.statusC ?? ''), label: 'Status', readOnly: true),
                              const SizedBox(height: 8),
                              _isEditing
                                ? AppInputField(controller: _controllers['consumoOuPotenciaPicoC']!, label: 'Consumo ou Potência Pico')
                                : AppInputField(controller: TextEditingController(text: detail.consumoOuPotenciaPicoC?.toString() ?? ''), label: 'Consumo ou Potência Pico', readOnly: true),
                              const SizedBox(height: 8),
                              _isEditing
                                ? AppInputField(controller: _controllers['fidelizacaoAnosCpeProposta']!, label: 'Fidelização (Anos)')
                                : AppInputField(controller: TextEditingController(text: detail.fidelizacaoAnosC?.toString() ?? ''), label: 'Fidelização (Anos)', readOnly: true),
                              const SizedBox(height: 8),
                              _isEditing
                                ? AppInputField(controller: _controllers['margemComercialC']!, label: 'Margem Comercial')
                                : AppInputField(controller: TextEditingController(text: detail.margemComercialC?.toString() ?? ''), label: 'Margem Comercial', readOnly: true),
                            ],
                            [
                              AppInputField(controller: TextEditingController(text: detail.agenteRetailName ?? ''), label: 'Agente Retail', readOnly: true),
                              const SizedBox(height: 8),
                              _isEditing
                                ? AppInputField(controller: _controllers['responsavelNegocioRetailC']!, label: 'Responsável de Negócio – Retail')
                                : AppInputField(controller: TextEditingController(text: detail.responsavelNegocioRetailC ?? ''), label: 'Responsável de Negócio – Retail', readOnly: true),
                              const SizedBox(height: 8),
                              _isEditing
                                ? AppInputField(controller: _controllers['responsavelNegocioExclusivoC']!, label: 'Responsável de Negócio – Exclusivo')
                                : AppInputField(controller: TextEditingController(text: detail.responsavelNegocioExclusivoC ?? ''), label: 'Responsável de Negócio – Exclusivo', readOnly: true),
                              const SizedBox(height: 8),
                              _isEditing
                                ? AppInputField(controller: _controllers['gestorDeRevendaC']!, label: 'Gestor de Revenda')
                                : AppInputField(controller: TextEditingController(text: detail.gestorDeRevendaC ?? ''), label: 'Gestor de Revenda', readOnly: true),
                            ],
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildDetailSectionTwoColumn(
                          context,
                          'Faturação Retail',
                          [
                            [
                              AppInputField(controller: TextEditingController(text: detail.cicloDeAtivacaoName ?? ''), label: 'Ciclo de Ativação', readOnly: true),
                              const SizedBox(height: 8),
                              _isEditing
                                ? AppInputField(controller: _controllers['comissaoRetailC']!, label: 'Comissão Retail')
                                : AppInputField(controller: TextEditingController(text: detail.comissaoRetailC?.toString() ?? ''), label: 'Comissão Retail', readOnly: true),
                              const SizedBox(height: 8),
                              _isEditing
                                ? AppInputField(controller: _controllers['notaInformativaC']!, label: 'Nota Informativa')
                                : AppInputField(controller: TextEditingController(text: detail.notaInformativaC ?? ''), label: 'Nota Informativa', readOnly: true),
                            ],
                            [
                              _isEditing
                                ? AppDateInputField(
                                    label: 'Pagamento da Factura Retail',
                                    value: _selectedPagamentoFacturaDate,
                                    onChanged: (date) => setState(() => _selectedPagamentoFacturaDate = date),
                                  )
                                : AppInputField(controller: TextEditingController(text: detail.pagamentoDaFacturaRetailC ?? ''), label: 'Pagamento da Factura Retail', readOnly: true),
                              const SizedBox(height: 8),
                              _isEditing
                                ? AppInputField(controller: _controllers['facturaRetailC']!, label: 'Factura Retail')
                                : AppInputField(controller: TextEditingController(text: detail.facturaRetailC ?? ''), label: 'Factura Retail', readOnly: true),
                            ],
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildSectionCard(
                          context,
                          'Visita Técnica',
                          [
                            _isEditing
                              ? AppDropdownField<String>(
                                  label: 'Visita Técnica',
                                  value: _selectedVisitaTecnica,
                                  items: _visitaTecnicaOptions.map((s) => DropdownMenuItem<String>(value: s, child: Text(s))).toList(),
                                  onChanged: (v) => setState(() => _selectedVisitaTecnica = v),
                                )
                              : AppInputField(controller: TextEditingController(text: detail.visitaTecnicaC ?? ''), label: 'Visita Técnica', readOnly: true),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildFilesSection(context, detail.files),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionCard(BuildContext context, String title, List<Widget> children) {
    final theme = Theme.of(context);
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: theme.dividerColor.withAlpha(25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 20,
                color: theme.colorScheme.primary,
              ),
              textAlign: TextAlign.left,
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildFilesSection(BuildContext context, List<dynamic> files) {
    final theme = Theme.of(context);
    final List<dynamic> displayedItems = [
      ...files.where((f) => !_filesToDelete.contains(f)),
      ..._filesToAdd,
    ];

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: theme.dividerColor.withAlpha(25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Ficheiros',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                    color: theme.colorScheme.primary,
                  ),
                  textAlign: TextAlign.left,
                ),
                if (_isEditing)
                  IconButton(
                    icon: const Icon(Icons.add),
                    tooltip: 'Adicionar Ficheiro',
                    onPressed: _pickFiles,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (displayedItems.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20.0),
                  child: Text(
                    'Sem ficheiros associados a esta CPE-Proposta.',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              )
            else
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: displayedItems.map((item) {
                  return _buildFilePreview(context, item);
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilePreview(BuildContext context, dynamic item) {
    final theme = Theme.of(context);
    String title;
    VoidCallback? onTapAction;
    bool isMarkedForDeletion = false;
    String? fileType;
    String? fileExtension;
    Widget iconWidget;

    if (item is PlatformFile) {
      // Handle newly picked files
      final file = item;
      fileExtension = (file.extension ?? '').toLowerCase();
      title = file.name;
      final iconAsset = FileIconService.getIconAssetPath(fileExtension);
      iconWidget = Image.asset(
        iconAsset,
        width: 30,
        height: 30,
        fit: BoxFit.contain,
      );
      onTapAction = null;
    } else if (item.runtimeType.toString().contains('ProposalFile') || 
               (item.runtimeType.toString().contains('File') && item is! PlatformFile)) {
      // Handle existing files from Salesforce
      fileType = item.fileType?.toLowerCase() ?? '';
      title = item.title ?? '';
      isMarkedForDeletion = _filesToDelete.contains(item);
      final iconAsset = FileIconService.getIconAssetPath(fileType);
      iconWidget = Image.asset(
        iconAsset,
        width: 30,
        height: 30,
        fit: BoxFit.contain,
      );
      onTapAction = () {
        if (isMarkedForDeletion) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SecureFileViewer(
              contentVersionId: item.contentVersionId,
              title: item.title,
              fileType: item.fileType,
            ),
            fullscreenDialog: true,
          ),
        );
      };
    } else {
      return const SizedBox.shrink();
    }

    return Container(
      width: 70,
      height: 70,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha((255 * 0.7).round()),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(
          color: Colors.black.withAlpha((255 * 0.1).round()),
          width: 0.5,
        ),
      ),
      child: Stack(
        children: [
          Center(
            child: InkWell(
              onTap: onTapAction,
              borderRadius: BorderRadius.circular(8.0),
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    iconWidget,
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 8),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_isEditing && !isMarkedForDeletion && item is! PlatformFile)
            Positioned(
              top: 2,
              right: 2,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha((255 * 0.08).round()),
                      blurRadius: 2,
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(Icons.close, size: 14),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  color: theme.colorScheme.error,
                  tooltip: 'Remover ficheiro',
                  onPressed: () {
                    setState(() {
                      _filesToDelete.add(item);
                    });
                  },
                ),
              ),
            ),
          if (_isEditing && item is PlatformFile)
            Positioned(
              top: 2,
              right: 2,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha((255 * 0.08).round()),
                      blurRadius: 2,
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(Icons.close, size: 14),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  color: theme.colorScheme.error,
                  tooltip: 'Remover ficheiro',
                  onPressed: () {
                    setState(() {
                      _filesToAdd.remove(item);
                    });
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailSectionTwoColumn(
    BuildContext context,
    String title,
    List<List<Widget>> columns,
  ) {
    final theme = Theme.of(context);
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: theme.dividerColor.withAlpha(25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 20,
                color: theme.colorScheme.primary,
              ),
              textAlign: TextAlign.left,
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Column(children: columns[0])),
                const SizedBox(width: 24),
                Expanded(child: Column(children: columns[1])),
              ],
            ),
          ],
        ),
      ),
    );
  }
} 