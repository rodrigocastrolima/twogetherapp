import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../presentation/widgets/logo.dart';
import '../../../../presentation/widgets/app_loading_indicator.dart';
import '../../../../presentation/widgets/simple_list_item.dart';
import '../../../../presentation/widgets/secure_file_viewer.dart';
import '../../../../presentation/widgets/success_dialog.dart';
import '../../../../core/services/salesforce_auth_service.dart';
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
    _controllers['solucaoC'] = TextEditingController(text: detail.cpe?.solucaoC ?? '');
    
    // CPE_Proposta fields (editable)
    _controllers['statusC'] = TextEditingController(text: detail.statusC ?? '');
    _controllers['consumoOuPotenciaPicoC'] = TextEditingController(text: detail.consumoOuPotenciaPicoC?.toString() ?? '');
    _controllers['fidelizacaoAnosCpeProposta'] = TextEditingController(text: detail.fidelizacaoAnosC?.toString() ?? '');
    _controllers['margemComercialC'] = TextEditingController(text: detail.margemComercialC?.toString() ?? '');
    _controllers['responsavelNegocioRetailC'] = TextEditingController(text: detail.responsavelNegocioRetailC ?? '');
    _controllers['responsavelNegocioExclusivoC'] = TextEditingController(text: detail.responsavelNegocioExclusivoC ?? '');
    _controllers['gestorDeRevendaC'] = TextEditingController(text: detail.gestorDeRevendaC ?? '');
    _controllers['comissaoRetailC'] = TextEditingController(text: detail.comissaoRetailC?.toString() ?? '');
    _controllers['notaInformativaC'] = TextEditingController(text: detail.notaInformativaC ?? '');
    _controllers['pagamentoDaFacturaRetailC'] = TextEditingController(text: detail.pagamentoDaFacturaRetailC ?? '');
    _controllers['facturaRetailC'] = TextEditingController(text: detail.facturaRetailC ?? '');
    _controllers['visitaTecnicaC'] = TextEditingController(text: detail.visitaTecnicaC ?? '');
  }

  // --- SHARED INPUT DECORATION (copied from admin_salesforce_proposal_detail_page.dart) ---
  InputDecoration _inputDecoration({
    required String label,
    String? hint,
    bool readOnly = false,
    Widget? suffixIcon,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    return InputDecoration(
      labelText: label,
      labelStyle: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500),
      hintText: hint,
      hintStyle: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant.withOpacity(0.7)),
      filled: true,
      fillColor: readOnly ? colorScheme.surfaceVariant.withOpacity(0.7) : colorScheme.surfaceVariant,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.primary, width: 2),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.08)),
      ),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      suffixIcon: suffixIcon,
    );
  }

  // --- REFACTOR: Editable text field builder (copied from admin_salesforce_proposal_detail_page.dart) ---
  Widget _buildEditableTextField(String label, TextEditingController controller, {int? maxLines, String? hint, bool readOnly = false, Widget? suffixIcon}) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 56,
      child: TextFormField(
        controller: controller,
        maxLines: maxLines ?? 1,
        minLines: 1,
        readOnly: readOnly,
        style: readOnly ? theme.textTheme.bodySmall?.copyWith(color: theme.disabledColor) : theme.textTheme.bodySmall,
        decoration: _inputDecoration(label: label, hint: hint, readOnly: readOnly, suffixIcon: suffixIcon),
      ),
    );
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
                fileName: file.name!,
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
      
      if (_controllers['solucaoC']!.text.isNotEmpty) {
        cpeFieldsToUpdate['Solu_o__c'] = _controllers['solucaoC']!.text;
      }

      // Prepare CPE_Proposta fields to update
      final cpePropostaFieldsToUpdate = <String, dynamic>{};
      if (_controllers['statusC']!.text.isNotEmpty) {
        cpePropostaFieldsToUpdate['Status__c'] = _controllers['statusC']!.text;
      }
      
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
      
      if (_controllers['pagamentoDaFacturaRetailC']!.text.isNotEmpty) {
        cpePropostaFieldsToUpdate['Pagamento_da_Factura_Retail__c'] = _controllers['pagamentoDaFacturaRetailC']!.text;
      }
      
      if (_controllers['facturaRetailC']!.text.isNotEmpty) {
        cpePropostaFieldsToUpdate['Factura_Retail__c'] = _controllers['facturaRetailC']!.text;
      }
      
      if (_controllers['visitaTecnicaC']!.text.isNotEmpty) {
        cpePropostaFieldsToUpdate['Visita_T_cnica__c'] = _controllers['visitaTecnicaC']!.text;
      }

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
      ref.refresh(cpePropostaDetailProvider(widget.cpePropostaId));
      
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
                    padding: const EdgeInsets.only(top: 24, left: 24, right: 24, bottom: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          detail.name ?? 'Detalhes da CPE-Proposta',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                          textAlign: TextAlign.left,
                        ),
                        Row(
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
                              _isEditing
                                ? _buildEditableTextField('CPE', TextEditingController(text: detail.cpe?.name ?? ''), readOnly: true)
                                : _buildDetailRow('CPE', detail.cpe?.name),
                              const SizedBox(height: 8),
                              _isEditing
                                ? _buildEditableTextField('Entidade', TextEditingController(text: detail.cpe?.entidadeName ?? ''), readOnly: true)
                                : _buildDetailRow('Entidade', detail.cpe?.entidadeName),
                            ],
                            [
                              _isEditing
                                ? _buildEditableTextField('NIF', TextEditingController(text: detail.cpe?.nifC ?? ''), readOnly: true)
                                : _buildDetailRow('NIF', detail.cpe?.nifC),
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
                                ? _buildEditableTextField('Consumo anual esperado (KWh)', _controllers['consumoAnualEsperadoKwhC']!)
                                : _buildDetailRow('Consumo anual esperado (KWh)', detail.cpe?.consumoAnualEsperadoKwhC?.toString()),
                              const SizedBox(height: 8),
                              _isEditing
                                ? _buildEditableTextField('Fidelização (Anos)', _controllers['fidelizacaoAnosC']!)
                                : _buildDetailRow('Fidelização (Anos)', detail.cpe?.fidelizacaoAnosC?.toString()),
                            ],
                            [
                              _isEditing
                                ? _buildEditableTextField('Solução', _controllers['solucaoC']!)
                                : _buildDetailRow('Solução', detail.cpe?.solucaoC),
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
                                ? _buildEditableTextField('Status', _controllers['statusC']!)
                                : _buildDetailRow('Status', detail.statusC),
                              const SizedBox(height: 8),
                              _isEditing
                                ? _buildEditableTextField('Consumo ou Potência Pico', _controllers['consumoOuPotenciaPicoC']!)
                                : _buildDetailRow('Consumo ou Potência Pico', detail.consumoOuPotenciaPicoC?.toString()),
                              const SizedBox(height: 8),
                              _isEditing
                                ? _buildEditableTextField('Fidelização (Anos)', _controllers['fidelizacaoAnosCpeProposta']!)
                                : _buildDetailRow('Fidelização (Anos)', detail.fidelizacaoAnosC?.toString()),
                              const SizedBox(height: 8),
                              _isEditing
                                ? _buildEditableTextField('Margem Comercial', _controllers['margemComercialC']!)
                                : _buildDetailRow('Margem Comercial', detail.margemComercialC?.toString()),
                            ],
                            [
                              _isEditing
                                ? _buildEditableTextField('Agente Retail', TextEditingController(text: detail.agenteRetailName ?? ''), readOnly: true)
                                : _buildDetailRow('Agente Retail', detail.agenteRetailName),
                              const SizedBox(height: 8),
                              _isEditing
                                ? _buildEditableTextField('Responsável de Negócio – Retail', _controllers['responsavelNegocioRetailC']!)
                                : _buildDetailRow('Responsável de Negócio – Retail', detail.responsavelNegocioRetailC),
                              const SizedBox(height: 8),
                              _isEditing
                                ? _buildEditableTextField('Responsável de Negócio – Exclusivo', _controllers['responsavelNegocioExclusivoC']!)
                                : _buildDetailRow('Responsável de Negócio – Exclusivo', detail.responsavelNegocioExclusivoC),
                              const SizedBox(height: 8),
                              _isEditing
                                ? _buildEditableTextField('Gestor de Revenda', _controllers['gestorDeRevendaC']!)
                                : _buildDetailRow('Gestor de Revenda', detail.gestorDeRevendaC),
                            ],
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildDetailSectionTwoColumn(
                          context,
                          'Faturação Retail',
                          [
                            [
                              _isEditing
                                ? _buildEditableTextField('Ciclo de Ativação', TextEditingController(text: detail.cicloDeAtivacaoName ?? ''), readOnly: true)
                                : _buildDetailRow('Ciclo de Ativação', detail.cicloDeAtivacaoName),
                              const SizedBox(height: 8),
                              _isEditing
                                ? _buildEditableTextField('Comissão Retail', _controllers['comissaoRetailC']!)
                                : _buildDetailRow('Comissão Retail', detail.comissaoRetailC?.toString()),
                              const SizedBox(height: 8),
                              _isEditing
                                ? _buildEditableTextField('Nota Informativa', _controllers['notaInformativaC']!)
                                : _buildDetailRow('Nota Informativa', detail.notaInformativaC),
                            ],
                            [
                              _isEditing
                                ? _buildEditableTextField('Pagamento da Factura Retail', _controllers['pagamentoDaFacturaRetailC']!)
                                : _buildDetailRow('Pagamento da Factura Retail', detail.pagamentoDaFacturaRetailC),
                              const SizedBox(height: 8),
                              _isEditing
                                ? _buildEditableTextField('Factura Retail', _controllers['facturaRetailC']!)
                                : _buildDetailRow('Factura Retail', detail.facturaRetailC),
                            ],
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildSectionCard(
                          context,
                          'Visita Técnica',
                          [
                            _isEditing
                              ? _buildEditableTextField('Visita Técnica', _controllers['visitaTecnicaC']!)
                              : _buildDetailRow('Visita Técnica', detail.visitaTecnicaC),
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
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 200,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value ?? 'N/A',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilesSection(BuildContext context, List<dynamic> files) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
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
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
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
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    String title;
    String subtitle = '';
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
      subtitle = '${((file.size / 1024 * 100).round() / 100)} KB';
      if (["png", "jpg", "jpeg", "gif", "bmp", "webp", "heic"].contains(fileExtension)) {
        iconWidget = Icon(Icons.image_outlined, color: colorScheme.primary, size: 30);
      } else if (fileExtension == "pdf") {
        iconWidget = Icon(Icons.picture_as_pdf, color: colorScheme.error, size: 30);
      } else {
        iconWidget = Icon(Icons.insert_drive_file, color: colorScheme.onSurfaceVariant, size: 30);
      }
      onTapAction = null;
    } else if (item.runtimeType.toString().contains('ProposalFile') || 
               (item.runtimeType.toString().contains('File') && !(item is PlatformFile))) {
      // Handle existing files from Salesforce
      fileType = item.fileType?.toLowerCase() ?? '';
      title = item.title ?? '';
      subtitle = item.fileType?.toUpperCase() ?? '';
      isMarkedForDeletion = _filesToDelete.contains(item);
      final isImage = ['png', 'jpg', 'jpeg', 'gif', 'bmp', 'webp', 'heic'].contains(fileType);
      final isPdf = fileType == 'pdf';
      if (isImage) {
        iconWidget = Icon(Icons.image_outlined, color: colorScheme.primary, size: 30);
      } else if (isPdf) {
        iconWidget = Icon(Icons.picture_as_pdf, color: colorScheme.error, size: 30);
      } else {
        iconWidget = Icon(Icons.insert_drive_file, color: colorScheme.onSurfaceVariant, size: 30);
      }
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
        color: theme.colorScheme.surfaceVariant.withAlpha((255 * 0.7).round()),
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
                      style: textTheme.bodySmall?.copyWith(fontSize: 8),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_isEditing && !isMarkedForDeletion && !(item is PlatformFile))
            Positioned(
              top: 2,
              right: 2,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 2,
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(Icons.close, size: 14),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  color: colorScheme.error,
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
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 2,
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(Icons.close, size: 14),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  color: colorScheme.error,
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
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
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