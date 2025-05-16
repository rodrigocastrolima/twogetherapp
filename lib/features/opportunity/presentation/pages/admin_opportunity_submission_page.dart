import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:url_launcher/url_launcher.dart'; // Needed for invoice link
import 'package:flutter/foundation.dart'; // For kDebugMode
import 'package:firebase_storage/firebase_storage.dart'; // Import Firebase Storage
import 'package:cloud_functions/cloud_functions.dart'; // Import Cloud Functions
import 'package:firebase_auth/firebase_auth.dart'; // Import FirebaseAuth
import 'package:flutter/cupertino.dart'; // For CupertinoIcons
import '../../../../presentation/widgets/logo.dart'; // Import LogoWidget

import 'package:twogether/core/models/service_submission.dart'; // Using package path
import 'package:twogether/presentation/widgets/full_screen_image_viewer.dart'; // Using package path
import 'package:twogether/presentation/widgets/full_screen_pdf_viewer.dart'; // Using package path
import 'package:twogether/core/services/salesforce_auth_service.dart'; // Import SF Auth Service
import 'package:twogether/features/opportunity/data/models/create_opp_models.dart'; // Import models
import 'package:twogether/features/opportunity/presentation/providers/opportunity_providers.dart'; // Import provider
import 'package:go_router/go_router.dart'; // For navigation

// Detail Form View Widget (With Skeleton Fields)
class OpportunityDetailFormView extends ConsumerStatefulWidget {
  final ServiceSubmission submission;

  const OpportunityDetailFormView({required this.submission, super.key});

  @override
  ConsumerState<OpportunityDetailFormView> createState() =>
      _OpportunityDetailFormViewState();
}

class _OpportunityDetailFormViewState
    extends ConsumerState<OpportunityDetailFormView> {
  final _formKey = GlobalKey<FormState>();

  // Controllers for editable text fields
  late TextEditingController _nameController;
  late TextEditingController _nifController;
  late TextEditingController _fechoController;
  // --- ADDED: Controllers for Read-Only Fields ---
  late TextEditingController _agenteRetailController;
  late TextEditingController _dataCriacaoController;
  late TextEditingController _dataUltimaAtualizacaoController;
  late TextEditingController _faseController;
  late TextEditingController _tipoOportunidadeController;
  // --- NEW: Controllers for Responsible/Company Name --- //
  late TextEditingController _responsibleNameController;
  late TextEditingController _companyNameController;
  // --- END NEW --- //

  // State variables for dropdowns and date picker
  String? _selectedSegmentoCliente;
  String? _selectedSolucao;
  DateTime? _selectedFechoDate;

  // State variables for derived/fetched data
  String? _resellerDisplayName;
  bool _isLoadingReseller = true; // Restoring field
  String? _tipoOportunidadeValue;
  final String _faseValue = "0 - Oportunidade Identificada"; // Fixed value
  String? _resellerSalesforceId; // Added to store the fetched Salesforce ID

  // --- NEW: State for NIF Check --- //
  NifCheckStatus _nifCheckStatus = NifCheckStatus.initial;
  String? _nifCheckMessage;
  bool _isCheckingNif = false; // Restoring field
  // --- END NEW --- //

  // State for submission button loading
  bool _isSubmitting = false;

  // --- ADDED: State for Invoice Preview ---
  // String? _invoiceDownloadUrl; // To store the fetched URL
  // Note: FutureBuilder will handle loading state for the URL fetch

  // Define picklist options (API Names)
  final List<String> _segmentoOptions = const [
    '--None--',
    'Cessou Actividade',
    'Ouro',
    'Prata',
    'Bronze',
    'Lata',
  ];
  final List<String> _solucaoOptions = const [
    '--None--',
    'LEC',
    'PAP',
    'PP',
    'Energia',
    'Gás',
  ];

  // --- NEW: Icon mapping for Segmento --- //
  final Map<String, Widget> _segmentoIcons = {
    '--None--': const Text('--None--'), // Keep text for none
    'Cessou Actividade': const Row(
      children: [
        Icon(Icons.cancel_outlined, color: Colors.red),
        SizedBox(width: 8),
        Text('Cessou Actividade'),
      ],
    ),
    'Ouro': Row(
      children: [
        Icon(Icons.emoji_events, color: Colors.amber.shade700),
        const SizedBox(width: 8),
        const Text('Ouro'),
      ],
    ),
    'Prata': Row(
      children: [
        Icon(Icons.emoji_events, color: Colors.grey.shade500),
        const SizedBox(width: 8),
        const Text('Prata'),
      ],
    ),
    'Bronze': Row(
      children: [
        Icon(Icons.emoji_events, color: Colors.brown.shade400),
        const SizedBox(width: 8),
        const Text('Bronze'),
      ],
    ),
    'Lata': Row(
      children: [
        Icon(Icons.circle, color: Colors.blueGrey.shade200),
        const SizedBox(width: 8),
        const Text('Lata'),
      ],
    ),
  };
  // --- END NEW --- //

  // Picklist options
  final List<String> _tipoOportunidadeOptions = const [
    '--None--',
    'Fidelizada',
    'Cross',
    'Angariada',
  ];
  final List<String> _faseOptions = const [
    '--None--',
    'Outro Agente',
    '0 - Oportunidade Identificada',
    '1 - Cliente Contactado',
    '2 - Visita Marcada',
    '3 - Oportunidade Qualificada',
    '4 - Proposta Apresentada',
    '5 - Negociação Final',
    '6 - Conclusão Ganho',
    '6 - Conclusão Perdido Futuro',
    '6 - Conclusão Desistência Cliente',
  ];

  @override
  void initState() {
    // Assuming context is available via WidgetsBinding.instance.addPostFrameCallback or similar
    // if needed before build, otherwise move l10n initialization inside build.
    // final l10n = AppLocalizations.of(context)!;
    super.initState();

    // Initialize controllers
    final potentialOpportunityName =
        '${widget.submission.companyName ?? widget.submission.responsibleName}_${DateFormat('yyyyMMdd_HHmmss').format(widget.submission.submissionDate)}';
    _nameController = TextEditingController(text: potentialOpportunityName);
    _nifController = TextEditingController(text: widget.submission.nif);
    _fechoController = TextEditingController(); // Initialize empty

    // --- Initialize Read-Only Controllers ---
    _agenteRetailController = TextEditingController(
      text: 'A carregar...',
    ); // Loading...
    _dataCriacaoController = TextEditingController(
      text: DateFormat.yMd().format(
        DateTime.now(),
      ), // Use default locale initially
    );
    _dataUltimaAtualizacaoController = TextEditingController(
      text: DateFormat.yMd().format(
        DateTime.now(),
      ), // Use default locale initially
    );
    _faseController = TextEditingController(text: _faseValue);
    _tipoOportunidadeController =
        TextEditingController(); // Set after determining

    // --- NEW: Initialize Responsible/Company Name Controllers --- //
    _responsibleNameController = TextEditingController(
      text: widget.submission.responsibleName,
    );
    _companyNameController = TextEditingController(
      text: widget.submission.companyName ?? 'N/A',
    ); // Handle null
    // --- END NEW --- //

    // Initialize derived picklist values
    _determineTipoOportunidade();
    _tipoOportunidadeController.text =
        _tipoOportunidadeValue ?? 'Não Determinado'; // Not Determined

    // Start fetching reseller display name
    _fetchResellerName();

    // --- ADDED: Trigger NIF check automatically after build ---
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _nifController.text.isNotEmpty) {
        _checkNif();
      }
    });
    // --- END ADDED ---
  }

  @override
  void dispose() {
    // Dispose controllers
    _nameController.dispose();
    _nifController.dispose();
    _fechoController.dispose();
    // --- Dispose Read-Only Controllers ---
    _agenteRetailController.dispose();
    _dataCriacaoController.dispose();
    _dataUltimaAtualizacaoController.dispose();
    _faseController.dispose();
    _tipoOportunidadeController.dispose();
    // --- NEW: Dispose Responsible/Company Name Controllers --- //
    _responsibleNameController.dispose();
    _companyNameController.dispose();
    // --- END NEW --- //
    super.dispose();
  }

  void _determineTipoOportunidade() {
    // Check energyType case-insensitively for 'solar'
    final energyTypeName = widget.submission.energyType?.name?.toLowerCase();
    if (energyTypeName == 'solar') {
      _tipoOportunidadeValue = 'Angariada Solar';
    } else {
      // Default to Energy if null or not 'solar'
      _tipoOportunidadeValue = 'Angariada Energia';
    }
  }

  Future<void> _fetchResellerName() async {
    setState(() {
      _resellerDisplayName = null; // Reset on fetch start
      _resellerSalesforceId = null; // Reset on fetch start
      _agenteRetailController.text = 'A carregar...'; // Loading...
    });
    try {
      final resellerDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(widget.submission.resellerId)
              .get();
      if (mounted && resellerDoc.exists) {
        final displayName = resellerDoc.data()?['displayName'] as String?;
        final salesforceId = resellerDoc.data()?['salesforceId'] as String?;

        setState(() {
          _resellerDisplayName = displayName;
          _resellerSalesforceId = salesforceId; // Fetch Salesforce ID
          _isLoadingReseller = false;

          // Add check if Salesforce ID is missing after fetch
          if (_resellerSalesforceId == null || _resellerSalesforceId!.isEmpty) {
            // Use kDebugMode check for print
            if (kDebugMode) {
              print("Warning: Reseller found but missing Salesforce ID.");
            }
            // Optionally update display name to show an error state
            _agenteRetailController.text =
                "${_resellerDisplayName ?? "Revendedor"} (SF ID em falta!)"; // Reseller, Missing SF ID!
            // Optionally disable submit button or show persistent warning here
          } else {
            _agenteRetailController.text =
                _resellerDisplayName ?? 'N/A'; // Update controller
          }

          // Use kDebugMode check for print
          if (kDebugMode) {
            print("Fetched reseller display name: $_resellerDisplayName");
            print(
              "Fetched reseller Salesforce ID: $_resellerSalesforceId",
            ); // Log fetched ID
          }
        });
      } else if (mounted) {
        // Use kDebugMode check for print
        if (kDebugMode) {
          print(
            "Reseller document not found for ID: ${widget.submission.resellerId}",
          );
        }
        setState(() {
          _resellerDisplayName = "Erro: Não Encontrado"; // Error: Not Found
          _agenteRetailController.text =
              "Erro: Não Encontrado"; // Error: Not Found
          _isLoadingReseller = false;
        });
      }
    } catch (e) {
      // Use kDebugMode check for print
      if (kDebugMode) {
        print("Error fetching reseller name: $e");
      }
      if (mounted) {
        setState(() {
          _resellerDisplayName =
              "Erro: Falha ao Carregar"; // Error: Fetch Failed
          _agenteRetailController.text =
              "Error: Falha ao Carregar"; // Error: Fetch Failed
          _isLoadingReseller = false;
        });
      }
    }
  }

  Future<void> _launchUrl(String urlString) async {
    // TODO: Verify if urlString is already a download URL or just a path.
    // If it's just a path, need Firebase Storage logic to get the download URL first.
    // final downloadUrl = await _getDownloadUrl(urlString); // Placeholder
    final Uri url = Uri.parse(
      urlString,
    ); // Assuming urlString IS the download URL for now
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível abrir $urlString')),
        ); // Could not launch
      }
    }
  }
  // --- Helper Placeholder for getting Download URL ---
  // Future<String?> _getDownloadUrl(String storagePath) async {
  //   try {
  //     // Requires firebase_storage package
  //     // final storageRef = FirebaseStorage.instance.ref(storagePath);
  //     // return await storageRef.getDownloadURL();
  //     print("Warning: Invoice URL generation from path not implemented yet.");
  //     return storagePath; // Temporary passthrough
  //   } catch (e) {
  //     print("Error getting download URL: $e");
  //     return null;
  //   }
  // }

  // --- ADDED: Fetch Invoice Download URL --- // Modified to fetch multiple URLs
  Future<List<Map<String, String?>>> _fetchMultipleDownloadUrls() async {
    List<String>? urlsOrPaths =
        widget.submission.documentUrls; // Prefer this field
    bool usingLegacyField = false;

    // Fallback to legacy field if primary is empty/null
    if (urlsOrPaths == null || urlsOrPaths.isEmpty) {
      if (kDebugMode) {
        print(
          "'documentUrls' is empty/null. Checking legacy 'attachmentUrls'...",
        );
      }
      // Assuming the factory constructor already read 'attachmentUrls' into documentUrls
      // If not, we might need to read snapshot directly, but let's assume model is correct
      // For robustness, let's re-check the logic: the model read it, so urlsOrPaths *should* contain it.
      // If it's STILL null/empty here, then there are truly no URLs.

      // Final check: try the single invoicePhoto as a last resort
      final legacyInvoicePhoto = widget.submission.invoicePhoto;
      if (legacyInvoicePhoto?.storagePath != null &&
          legacyInvoicePhoto!.storagePath.isNotEmpty) {
        if (kDebugMode) {
          print(
            "Falling back to single legacy invoicePhoto path: ${legacyInvoicePhoto.storagePath}",
          );
        }
        usingLegacyField = true;
        urlsOrPaths = [
          legacyInvoicePhoto.storagePath,
        ]; // Treat the path as a list of one
      } else {
        if (kDebugMode) {
          print("No valid URLs or paths found in submission data.");
        }
        return []; // No files found
      }
    }

    if (kDebugMode) {
      print("Processing URLs/Paths: $urlsOrPaths");
    }

    final List<Future<Map<String, String?>>> futures =
        urlsOrPaths.map((urlOrPath) async {
          try {
            String downloadUrl;
            String pathForFileName = urlOrPath; // Path used to extract filename

            // If using the legacy field, we assume it's a path and need to get the URL
            if (usingLegacyField) {
              downloadUrl =
                  await FirebaseStorage.instance
                      .ref(urlOrPath)
                      .getDownloadURL();
            } else {
              // Otherwise, assume it's already a download URL
              downloadUrl = urlOrPath;
            }

            // Extract filename (best effort from URL or path)
            String fileName = 'Ficheiro Desconhecido'; // Unknown File
            try {
              // Try decoding the URL part before splitting
              final decodedPath = Uri.decodeComponent(
                pathForFileName.split('/').last.split('?').first,
              );
              fileName =
                  decodedPath
                      .split('/')
                      .last; // Get last segment after decoding
              // Remove potential index prefix like "attachment_0_"
              fileName = fileName.replaceFirst(RegExp(r'^attachment_\d+_'), '');
            } catch (e) {
              print(
                "Error decoding/parsing filename from $pathForFileName: $e",
              );
              // Fallback if decoding fails
              fileName = pathForFileName
                  .split('/')
                  .last
                  .split('?')
                  .first
                  .replaceFirst(RegExp(r'^attachment_\d+_'), '');
            }

            return {
              'url': downloadUrl,
              'path':
                  usingLegacyField
                      ? urlOrPath
                      : null, // Store original path only if it was a path
              'error': null,
              'fileName': fileName,
              'contentType':
                  usingLegacyField
                      ? widget.submission.invoicePhoto?.contentType
                      : null,
            };
          } catch (e) {
            if (kDebugMode) {
              print("Error processing URL/Path $urlOrPath: $e");
            }
            String fileName = 'Ficheiro Desconhecido'; // Unknown File
            try {
              final decodedPath = Uri.decodeComponent(
                urlOrPath.split('/').last.split('?').first,
              );
              fileName = decodedPath
                  .split('/')
                  .last
                  .replaceFirst(RegExp(r'^attachment_\d+_'), '');
            } catch (parseErr) {
              fileName = urlOrPath
                  .split('/')
                  .last
                  .split('?')
                  .first
                  .replaceFirst(RegExp(r'^attachment_\d+_'), '');
            }

            return {
              'url': null,
              'path': urlOrPath,
              'error': e.toString(),
              'fileName': fileName,
              'contentType':
                  usingLegacyField
                      ? widget.submission.invoicePhoto?.contentType
                      : null,
            };
          }
        }).toList();

    final results = await Future.wait(futures);
    if (kDebugMode) {
      print("Obtained download URL results: $results");
    }
    return results;
  }

  // --- ADDED: Rejection Dialog ---
  Future<String?> _showRejectionDialog() async {
    final reasonController = TextEditingController();
    final dialogFormKey = GlobalKey<FormState>(); // Key for the dialog's form

    return showDialog<String>(
      context: context,
      barrierDismissible: false, // User must tap button!
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Text('Rejeitar Submissão'), // Reject Submission
          content: Form(
            key: dialogFormKey,
            child: SingleChildScrollView(
              child: ListBody(
                children: <Widget>[
                  const Text(
                    'Por favor, indique o motivo para rejeitar esta submissão.', // Please provide the reason for rejecting this submission.
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: reasonController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText:
                          'Insira o motivo aqui...', // Enter reason here...
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'O motivo da rejeição não pode estar vazio'; // Rejection reason cannot be empty
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'), // Cancel
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(null); // Dismiss and return null
              },
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor:
                    Theme.of(context).colorScheme.error, // Use error color
              ),
              child: const Text('Confirmar Rejeição'), // Confirm Rejection
              onPressed: () {
                // Validate the reason field
                if (dialogFormKey.currentState?.validate() ?? false) {
                  Navigator.of(dialogContext).pop(
                    reasonController.text.trim(),
                  ); // Dismiss and return reason
                }
              },
            ),
          ],
        );
      },
    );
  }

  // --- NEW: Handler for the Approve Action ---
  Future<void> _approveSubmission() async {
    // 1. Validate Form
    final isValid = _formKey.currentState?.validate() ?? false;

    if (kDebugMode) {
      print('User pressed approve. Validation passed: $isValid');
    }

    if (isValid) {
      // 2. Validate Reseller Salesforce ID
      if (_resellerSalesforceId == null || _resellerSalesforceId!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não é possível aprovar: ID Salesforce do Revendedor em falta.',
            ), // Cannot approve: Reseller Salesforce ID is missing.
          ),
        );
        return;
      }

      setState(() => _isSubmitting = true);

      // --- RE-ENABLE Salesforce Auth Check --- //
      // 3. Get Salesforce Auth Details
      final sfAuthNotifier = ref.read(salesforceAuthProvider.notifier);
      final String? accessToken = await sfAuthNotifier.getValidAccessToken();
      final String? instanceUrl = sfAuthNotifier.currentInstanceUrl;

      if (accessToken == null || instanceUrl == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Sessão Salesforce inválida. Tente sair e entrar novamente ou atualizar.', // Salesforce session invalid. Please try logging out and back in, or refresh.
              ),
            ),
          );
        }
        setState(() => _isSubmitting = false);
        return;
      }
      // print("--- SKIPPED Salesforce Auth Check for UI testing ---");
      // --- END RE-ENABLE --- //

      // --- RE-ENABLE Params creation --- //
      // 4. Gather Parameters
      final String formattedCloseDate;
      if (_selectedFechoDate != null) {
        formattedCloseDate = DateFormat('yyyy-MM-dd').format(_selectedFechoDate!);
      } else {
        // Default to today if no date was picked, though the validator should prevent this
        formattedCloseDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
      }

      final params = CreateOppParams(
        submissionId: widget.submission.id!, // Assume ID is non-null here
        accessToken: accessToken, // Use the fetched token
        instanceUrl: instanceUrl, // Use the fetched URL
        resellerSalesforceId:
            _resellerSalesforceId!, // Use fetched Reseller SF ID
        opportunityName: _nameController.text,
        nif: _nifController.text,
        companyName:
            widget.submission.companyName ??
            widget.submission.responsibleName, // Use fallback logic
        segment: _selectedSegmentoCliente!, // Assume selected
        solution: _selectedSolucao!, // Assume selected
        closeDate: formattedCloseDate, // Pass the CORRECTLY formatted string
        opportunityType: _tipoOportunidadeValue!, // Assume determined
        phase: _faseValue, // Use fixed value
        fileUrls: widget.submission.documentUrls, // Pass the list of URLs/paths
      );
      // print("--- SKIPPED Param Creation for UI testing ---");
      // --- END RE-ENABLE --- //

      // 5. Call the Provider & Remove Dummy Result
      try {
        // --- RE-ENABLE the actual call --- //
        final result = await ref.read(createOpportunityProvider(params).future);
        // --- END RE-ENABLE --- //

        // --- REMOVE Dummy Result --- //
        /*
        final result = CreateOppResult(
          success: true,
          opportunityId: 'DUMMY_OPP_ID_123', // Placeholder SF Opportunity ID
          error: null,
          sessionExpired: false,
        );
        */
        // --- END REMOVE --- //

        _handleCreateResult(
          result,
        ); // Handle the actual success/failure from the function call
      } catch (e) {
        _handleCreateError(e);
        // If an error happened *before* _handleCreateResult, reset loading state
        if (mounted) {
          setState(() => _isSubmitting = false);
        }
      }
      // No finally block needed, _handleCreateResult manages state
    }
  }

  // --- NEW: Handler for Cloud Function Result ---
  Future<void> _handleCreateResult(CreateOppResult result) async {
    if (!mounted) return;

    // --- Handle session expiration first ---
    if (result.sessionExpired) {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Sessão Salesforce expirou. Por favor, atualize ou faça login novamente.', // Salesforce session expired. Please refresh or log in again.
          ),
        ),
      );
      // Optional: Trigger re-authentication flow
      // ref.read(salesforceAuthProvider.notifier).authenticate(); // salesforceAuthProvider is from core/services
      return;
    }

    if (result.success) {
      // --- Success Case ---
      try {
        // --- RE-ENABLE Firestore update --- //
        await FirebaseFirestore.instance
            .collection('serviceSubmissions')
            .doc(widget.submission.id)
            .update({
              'status': 'approved',
              'salesforceOpportunityId': result.opportunityId,
              'salesforceAccountId': result.accountId,
              'adminReviewTimestamp': FieldValue.serverTimestamp(),
              'adminReviewedBy':
                  FirebaseAuth
                      .instance
                      .currentUser
                      ?.uid, // Use direct FirebaseAuth instance
              'approvedDetails': {
                'opportunityName': _nameController.text,
                'nif': _nifController.text,
                'segmentoCliente': _selectedSegmentoCliente,
                'solucao': _selectedSolucao,
                'dataFecho': _fechoController.text,
                'opportunityType': _tipoOportunidadeValue,
              },
            });
        // print("--- SKIPPED Firestore update for UI testing --- ");
        // --- END RE-ENABLE --- //

        // --- MODIFICATION START: Show Dialog or Fallback ---
        if (!mounted) return;

        final opportunityName = _nameController.text;
        final accountName =
            widget.submission.companyName ?? widget.submission.responsibleName;
        final nif = _nifController.text;
        final resellerSfId = _resellerSalesforceId;
        final resellerName = _resellerDisplayName;
        final sfOpportunityId = result.opportunityId; // Will use actual ID now
        final sfAccountId =
            result.accountId; // <-- Use the actual account ID from the result

        // Check if we have essential data for proposal creation
        // This check should now use the actual accountId
        if (sfOpportunityId == null ||
            sfAccountId == null || // Check the actual account ID
            resellerSfId == null) {
          // ... (fallback logic remains the same) ...
          // If essential data is missing (esp. accountId), show standard success and navigate away
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Oportunidade Aprovada. Faltam dados necessários para a criação da proposta.', // Opportunity Approved. Required data for proposal creation missing.
              ),
            ),
          );
          // Reset loading state before navigating
          if (mounted) setState(() => _isSubmitting = false);
          context.go('/admin'); // Fallback navigation
          return;
        }

        // --- Show Dialog --- // Use actual IDs now
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              title: const Text(
                'Oportunidade Criada', // Opportunity Created
              ),
              content: Text(
                'Oportunidade "$opportunityName" (ID: $sfOpportunityId) criada. Criar uma Proposta agora?', // Opportunity ... created. Create a Proposal now?
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Mais Tarde'), // Later
                  onPressed: () {
                    Navigator.of(dialogContext).pop(); // Close dialog
                    // Show original success message before navigating
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Oportunidade Aprovada com Sucesso', // Opportunity Approved Successfully
                        ),
                      ),
                    );
                    // Reset loading state before navigating
                    if (mounted) setState(() => _isSubmitting = false);
                    context.go('/admin'); // Navigate away
                  },
                ),
                TextButton(
                  child: const Text('Criar Proposta'), // Create Proposal
                  onPressed: () {
                    Navigator.of(dialogContext).pop(); // Close dialog
                    // Reset loading state before navigating to new page
                    if (mounted) setState(() => _isSubmitting = false);
                    // Navigate to the Proposal Creation Page with ACTUAL data
                    context.push(
                      '/proposal/create',
                      extra: {
                        'salesforceOpportunityId': sfOpportunityId, // Actual ID
                        'salesforceAccountId': sfAccountId, // Actual ID
                        'accountName': accountName,
                        'resellerSalesforceId': resellerSfId,
                        'resellerName': resellerName ?? 'N/A',
                        'nif': nif,
                        'opportunityName': opportunityName,
                      },
                    );
                  },
                ),
              ],
            );
          },
        );
        // --- MODIFICATION END ---
      } catch (e, s) {
        // Firestore update failed (or skipped)
        // ... (error handling remains the same) ...
        if (kDebugMode) {
          print("Error updating Firestore after approval: $e");
          print(s);
        }
        if (!mounted) return;
        // Reset loading state as we are staying on the page
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Erro durante a fase de atualização do Firestore: ${e.toString()}', // Error during Firestore update phase: ...
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } else {
      // --- Failure Case (from Cloud Function/Provider - OR DUMMY FAILURE) ---
      // ... (error handling remains the same) ...
      if (kDebugMode) {
        print("Create Opportunity Failed: ${result.error}"); // Use result.error
      }
      // Reset loading state as we are staying on the page
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Falha ao criar oportunidade: ${result.error ?? 'Erro desconhecido'}', // Failed to create opportunity: ... Unknown error
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  // --- NEW: Handler for Provider Call Errors ---
  void _handleCreateError(Object e) {
    if (!mounted) return;
    if (kDebugMode) {
      print("Error calling createOpportunityProvider: $e");
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Erro: ${e.toString()}")), // Error: ...
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final horizontalPadding = EdgeInsets.symmetric(horizontal: 32.0);

    InputDecoration _inputDecoration({
      required String label,
      String? hint,
      bool readOnly = false,
      Widget? suffixIcon,
    }) {
      return InputDecoration(
        labelText: label,
        labelStyle: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500),
        hintText: hint,
        hintStyle: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant.withOpacity(0.7)),
        filled: true,
        fillColor: readOnly ? colorScheme.surfaceVariant.withOpacity(0.7) : colorScheme.surfaceVariant,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.08)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        suffixIcon: suffixIcon,
      );
    }

    Widget _sectionTitle(String text) => Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(
        text,
        style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
    );

    Widget _readOnlyField(String label, TextEditingController controller) {
      return TextFormField(
        controller: controller,
        readOnly: true,
        style: textTheme.bodySmall,
        decoration: _inputDecoration(label: label, readOnly: true),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(CupertinoIcons.chevron_left, color: colorScheme.onSurface),
          onPressed: () => context.pop(),
        ),
        title: LogoWidget(height: 60, darkMode: isDarkMode),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0.0,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(vertical: 32).add(horizontalPadding),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    'Detalhe da Oportunidade',
                    style: textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Responsible/Company
                  TextFormField(
                    controller: _responsibleNameController,
                    style: textTheme.bodySmall,
                    decoration: _inputDecoration(label: 'Nome do Responsável'),
                  ),
                  const SizedBox(height: 12),
                  if (widget.submission.companyName != null && widget.submission.companyName!.isNotEmpty)
                    TextFormField(
                      controller: _companyNameController,
                      style: textTheme.bodySmall,
                      decoration: _inputDecoration(label: 'Nome da Empresa'),
                    ),
                  if (widget.submission.companyName != null && widget.submission.companyName!.isNotEmpty)
                    const SizedBox(height: 12),
                  _readOnlyField('Agente Retail', _agenteRetailController),
                  const SizedBox(height: 20),
                  // --- All Opportunity Fields (no section title) ---
                  TextFormField(
                    controller: _nameController,
                    style: textTheme.bodySmall,
                    decoration: _inputDecoration(label: 'Nome da Oportunidade'),
                    validator: (value) => (value == null || value.trim().isEmpty)
                        ? 'Nome da Oportunidade é obrigatório'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _nifController,
                          style: textTheme.bodySmall,
                          decoration: _inputDecoration(label: 'NIF'),
                          validator: (value) => (value == null || value.trim().isEmpty)
                              ? 'NIF é obrigatório'
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      _buildNifStatusIndicator(),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _dataCriacaoController,
                    style: textTheme.bodySmall,
                    decoration: _inputDecoration(label: 'Data de Criação'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _dataUltimaAtualizacaoController,
                    style: textTheme.bodySmall,
                    decoration: _inputDecoration(label: 'Última Atualização'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _faseOptions.contains(_faseController.text) ? _faseController.text : '--None--',
                    decoration: _inputDecoration(label: 'Fase'),
                    items: _faseOptions.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value, style: textTheme.bodySmall),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _faseController.text = value ?? '';
                      });
                    },
                    validator: (value) => (value == null || value == '--None--')
                        ? 'Fase é obrigatória'
                        : null,
                    hint: Text('Selecione uma fase', style: textTheme.bodySmall),
                    style: textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _tipoOportunidadeOptions.contains(_tipoOportunidadeController.text) ? _tipoOportunidadeController.text : '--None--',
                    decoration: _inputDecoration(label: 'Tipo de Oportunidade'),
                    items: _tipoOportunidadeOptions.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value, style: textTheme.bodySmall),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _tipoOportunidadeController.text = value ?? '';
                      });
                    },
                    validator: (value) => (value == null || value == '--None--')
                        ? 'Tipo de Oportunidade é obrigatório'
                        : null,
                    hint: Text('Selecione o tipo de oportunidade', style: textTheme.bodySmall),
                    style: textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _segmentoOptions.contains(_selectedSegmentoCliente) ? _selectedSegmentoCliente : '--None--',
                    decoration: _inputDecoration(label: 'Segmento de Cliente'),
                    items: _segmentoOptions.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: _segmentoIcons[value] ?? Text(value, style: textTheme.bodySmall),
                      );
                    }).toList(),
                    selectedItemBuilder: (BuildContext context) {
                      return _segmentoOptions.map<Widget>((String item) {
                        final iconWidget = _segmentoIcons[item];
                        if (iconWidget is Row) {
                          return iconWidget.children.firstWhere((w) => w is Icon);
                        } else if (iconWidget is Text && item == '--None--') {
                          return Text(
                            'Selecione um segmento',
                            style: textTheme.bodySmall?.copyWith(color: theme.hintColor),
                          );
                        } else {
                          return iconWidget ?? const SizedBox.shrink();
                        }
                      }).toList();
                    },
                    onChanged: (value) => setState(() => _selectedSegmentoCliente = value),
                    validator: (value) => (value == null || value == '--None--')
                        ? 'Segmento de Cliente é obrigatório'
                        : null,
                    hint: Text('Selecione um segmento de cliente', style: textTheme.bodySmall),
                    style: textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _solucaoOptions.contains(_selectedSolucao) ? _selectedSolucao : '--None--',
                    decoration: _inputDecoration(label: 'Solução'),
                    items: _solucaoOptions.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value, style: textTheme.bodySmall),
                      );
                    }).toList(),
                    onChanged: (value) => setState(() => _selectedSolucao = value),
                    validator: (value) => (value == null || value == '--None--')
                        ? 'Solução é obrigatória'
                        : null,
                    hint: Text('Selecione uma solução', style: textTheme.bodySmall),
                    style: textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _fechoController,
                    style: textTheme.bodySmall,
                    decoration: _inputDecoration(
                      label: 'Data de Previsão de Fecho',
                      hint: 'Selecione a data de fecho',
                      suffixIcon: const Icon(Icons.calendar_today),
                    ),
                    keyboardType: TextInputType.datetime,
                    readOnly: true,
                    onTap: () async {
                      DateTime? pickedDate = await showDatePicker(
                        context: context,
                        initialDate: _selectedFechoDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2101),
                        builder: (context, child) {
                          return Theme(
                            data: theme.copyWith(
                              colorScheme: theme.colorScheme.copyWith(
                                primary: colorScheme.primary,
                                onPrimary: colorScheme.onPrimary,
                                onSurface: colorScheme.onSurface,
                              ),
                              textButtonTheme: TextButtonThemeData(
                                style: TextButton.styleFrom(
                                  foregroundColor: colorScheme.primary,
                                ),
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (pickedDate != null && pickedDate != _selectedFechoDate) {
                        setState(() {
                          _selectedFechoDate = pickedDate;
                          _fechoController.text = DateFormat.yMd().format(pickedDate);
                        });
                      }
                    },
                    validator: (value) => (value == null || value.isEmpty)
                        ? 'Data de Previsão de Fecho é obrigatória'
                        : null,
                  ),
                  const SizedBox(height: 20),
                  // --- Faturas Section ---
                  _sectionTitle('Secção Faturas'),
                  const SizedBox(height: 12),
                  FutureBuilder<List<Map<String, String?>>>(
                    future: _fetchMultipleDownloadUrls(), // Call the new function
                    builder: (context, snapshot) {
                      // Check connection state
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Row(
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colorScheme.primary, // Use theme color
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'A carregar...', // Loading...
                              style: textTheme.bodySmall,
                            ),
                          ],
                        );
                      }

                      // Check for errors during the fetch process itself (e.g., network error)
                      if (snapshot.hasError) {
                        return Row(
                          children: [
                            Icon(Icons.error_outline, color: colorScheme.error),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Erro: ${snapshot.error}', // Error: ...
                                style: textTheme.bodySmall?.copyWith(
                                  color: colorScheme.error,
                                ),
                              ),
                            ),
                          ],
                        );
                      }

                      // Check if data (list of results) exists and is not null/empty
                      final results = snapshot.data;
                      if (results == null || results.isEmpty) {
                        return Text(
                          'Nenhum ficheiro disponível', // No files available
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        );
                      }

                      // --- Display Previews using Wrap --- //
                      return Wrap(
                        spacing: 8.0,
                        runSpacing: 8.0,
                        children:
                            results.map((fileData) {
                              return _buildDocumentPreview(context, fileData);
                            }).toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  // --- Actions or Rejection Info ---
                  if (widget.submission.status == 'rejected')
                    _buildRejectionInfoSection(context, theme)
                  else
                    Center(
                      child: Wrap(
                        spacing: 16.0,
                        runSpacing: 8.0,
                        alignment: WrapAlignment.center,
                        children: [
                          SizedBox(
                            height: 40,
                            child: FilledButton(
                              onPressed: _isSubmitting ? null : _approveSubmission,
                              style: FilledButton.styleFrom(
                                backgroundColor: colorScheme.primary,
                                foregroundColor: colorScheme.onPrimary,
                                minimumSize: const Size(120, 40),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                textStyle: textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              child: _isSubmitting
                                  ? SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: colorScheme.onPrimary,
                                      ),
                                    )
                                  : const Text('Aprovar'),
                            ),
                          ),
                          SizedBox(
                            height: 40,
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.cancel_outlined, size: 18),
                              label: const Text('Rejeitar'),
                              onPressed: _isSubmitting
                                  ? null
                                  : () async {
                                      final reason = await _showRejectionDialog();
                                      if (kDebugMode) {
                                        print('Rejection reason: $reason');
                                      }
                                      if (reason != null && reason.isNotEmpty) {
                                        await _handleRejection(reason);
                                      }
                                    },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: colorScheme.error,
                                side: BorderSide(
                                  color: colorScheme.error.withAlpha((255 * 0.7).round()),
                                  width: 1.2,
                                ),
                                minimumSize: const Size(120, 40),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                textStyle: textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- NEW: Widget Builder for Rejection Info Section ---
  Widget _buildRejectionInfoSection(BuildContext context, ThemeData theme) {
    final rejectionReason = widget.submission.reviewDetails?.rejectionReason;
    final reviewTimestamp =
        widget.submission.reviewDetails?.reviewTimestamp
            .toDate(); // Convert Timestamp to DateTime
    final reviewerId =
        widget
            .submission
            .reviewDetails
            ?.reviewerId; // TODO: Fetch reviewer name based on ID?

    String formattedTimestamp = 'Unknown date';
    if (reviewTimestamp != null) {
      formattedTimestamp = DateFormat.yMMMd().add_jm().format(
        reviewTimestamp.toLocal(),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withAlpha((255 * 0.15).round()),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.errorContainer, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: theme.colorScheme.error),
              const SizedBox(width: 8),
              Text(
                'Detalhes da Rejeição', // Rejection Details
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ),
          const Divider(height: 20, thickness: 0.5),
          Text(
            "Motivo da Rejeição:", // Rejection Reason:
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            rejectionReason ??
                "Nenhum motivo fornecido.", // No reason provided.
            style: theme.textTheme.bodyMedium,
          ),
          if (reviewTimestamp != null || reviewerId != null) ...[
            const SizedBox(height: 12),
            Text(
              "Rejeitado em: $formattedTimestamp", // Rejected on: ...
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            // Optionally display reviewer if needed
          ],
        ],
      ),
    );
  }
  // ---------------------------------------------------- //

  // --- MODIFIED: _buildActionButtons --- //
  Widget _buildActionButtons(BuildContext context, ThemeData theme) {
    final colorScheme = theme.colorScheme;
    return Center(
      child: Wrap(
        spacing: 16.0,
        runSpacing: 8.0,
        alignment: WrapAlignment.center,
        children: [
          // Approve Button
          ElevatedButton(
            onPressed: _isSubmitting ? null : _approveSubmission,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
            ),
            child:
                _isSubmitting
                    ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.onPrimary,
                      ),
                    )
                    : Text('Aprovar'),
          ),
          // Reject Button
          OutlinedButton.icon(
            icon: const Icon(Icons.cancel_outlined),
            label: Text('Rejeitar'), // Reject
            onPressed:
                _isSubmitting
                    ? null
                    : () async {
                      final reason = await _showRejectionDialog();
                      if (kDebugMode) {
                        print('Rejection reason: $reason');
                      }
                      if (reason != null && reason.isNotEmpty) {
                        await _handleRejection(reason);
                      }
                    },
            style: OutlinedButton.styleFrom(
              foregroundColor: colorScheme.error,
              side: BorderSide(
                color: colorScheme.error.withAlpha((255 * 0.7).round()),
                width: 1.5,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
            ),
          ),
        ],
      ),
    );
  }
  // ------------------------------------------ //

  // --- ADDED: Handle Rejection Logic ---
  Future<void> _handleRejection(String reason) async {
    if (widget.submission.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Erro: ID da Submissão em falta",
          ), // Error: Submission ID missing
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Ideally get admin user ID here, for now using a placeholder
    // final adminId = ref.read(authProvider).currentUser?.uid;
    const String adminId =
        "ADMIN_PLACEHOLDER_ID"; // Replace with actual admin ID fetch
    if (adminId == "ADMIN_PLACEHOLDER_ID") {
      if (kDebugMode) {
        print("Warning: Using placeholder Admin ID for rejection.");
      }
      // Potentially show a warning SnackBar if needed
    }

    setState(() {
      _isSubmitting = true; // Use the same flag to disable both buttons
    });

    try {
      final docRef = FirebaseFirestore.instance
          .collection('serviceSubmissions')
          .doc(widget.submission.id);

      // Prepare review details data
      final reviewData = {
        'reviewerId': adminId,
        'reviewTimestamp': Timestamp.now(),
        'rejectionReason': reason,
        'notes': null, // Explicitly set notes to null or handle separately
      };

      // Use Firestore transaction for atomic update
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        transaction.update(docRef, {
          'status': 'rejected',
          'reviewDetails': reviewData,
        });
      });

      // --- Optional: Create Notification for Reseller ---
      try {
        await _createRejectionNotification(
          widget.submission.resellerId,
          widget.submission.id!,
          reason,
        );
      } catch (e) {
        if (kDebugMode) {
          print("Error creating rejection notification: $e");
        }
        // Non-critical, don't fail the whole rejection
      }
      // ---------------------------------------------------

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Submissão rejeitada com sucesso.',
            ), // Submission rejected successfully.
            backgroundColor: Colors.orange,
          ),
        );
        // Optionally navigate back
        if (Navigator.canPop(context)) {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error rejecting submission: $e");
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Falha ao rejeitar submissão: ${e.toString()}',
            ), // Failed to reject submission: ...
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  // --- ADDED: Create Rejection Notification ---
  Future<void> _createRejectionNotification(
    String resellerId,
    String submissionId,
    String reason,
  ) async {
    try {
      final notificationRef =
          FirebaseFirestore.instance
              .collection('notifications')
              .doc(); // Auto-generate ID

      final notificationData = {
        'id': notificationRef.id,
        'userId': resellerId, // Target the reseller
        'title': 'Oportunidade Rejeitada', // Opportunity Rejected
        'body':
            'A sua submissão foi rejeitada. Motivo: $reason', // Your submission was rejected. Reason: ...
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
        'type':
            'rejection', // Use the correct string for NotificationType.rejection
        'relatedId': submissionId, // Link to the submission
        'relatedDataType':
            'serviceSubmission', // Specify the type of related data
        'icon': 'warning', // Optional: suggest an icon name
        'metadata': {
          'submissionId': submissionId,
          'rejectionReason': reason,
          'clientName':
              widget.submission.companyName ??
              widget.submission.responsibleName,
        },
      };

      await notificationRef.set(notificationData);
      // Use kDebugMode check for print
      if (kDebugMode) {
        print(
          'Rejection notification created for reseller $resellerId, submission $submissionId',
        );
      }
    } catch (e) {
      // Use kDebugMode check for print
      if (kDebugMode) {
        print('Error creating rejection notification: $e');
      }
      // Log or handle error, but don't block the main rejection flow
      rethrow; // Re-throw if needed for upstream handling
    }
  }

  // --- ADDED: Widget Builder for individual document preview ---
  Widget _buildDocumentPreview(
    BuildContext context,
    Map<String, String?> fileData,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final String? downloadUrl = fileData['url'];
    final String? storagePath = fileData['path'];
    final String? error = fileData['error'];
    final String fileName =
        fileData['fileName'] ?? 'Ficheiro Desconhecido'; // Unknown File
    final String? contentType = fileData['contentType']; // May be null

    // Use a fixed size for the preview container
    const double previewSize = 70.0;

    // Determine if it's an image (basic check based on extension from path)
    // More robust check would use contentType if available
    final bool isImage = _isImageFile(fileName);
    final bool isPdf = fileName.toLowerCase().endsWith('.pdf');

    Widget content;

    if (error != null) {
      // --- Error State ---
      content = Tooltip(
        message: 'Erro ao carregar: $error', // Error loading: ...
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: colorScheme.error, size: 30),
            Padding(
              padding: const EdgeInsets.only(top: 4.0, left: 2.0, right: 2.0),
              child: Text(
                fileName,
                style: textTheme.bodySmall?.copyWith(
                  fontSize: 8,
                  color: colorScheme.error,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    } else if (downloadUrl == null) {
      // --- Loading State (individual) or Invalid URL State ---
      // This case might occur if URL fetch failed silently or path was invalid
      content = Tooltip(
        message: 'Pré-visualização indisponível', // Preview unavailable
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.broken_image,
              color: colorScheme.onSurfaceVariant,
              size: 30,
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4.0, left: 2.0, right: 2.0),
              child: Text(
                fileName,
                style: textTheme.bodySmall?.copyWith(
                  fontSize: 8,
                  color: colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    } else if (isImage) {
      // --- Image Preview ---
      content = GestureDetector(
        onTap: () {
          Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute(
              builder:
                  (_) => FullScreenImageViewer(
                    imageUrl: downloadUrl,
                    imageName: fileName,
                  ),
              fullscreenDialog: true,
            ),
          );
        },
        child: Image.network(
          downloadUrl,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                value:
                    loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                        : null,
                strokeWidth: 2,
                color: colorScheme.primary,
              ),
            );
          },
          errorBuilder:
              (context, error, stackTrace) => Tooltip(
                message:
                    'Erro na pré-visualização: $error', // Error previewing: ...
                child: const Center(child: Icon(Icons.broken_image, size: 30)),
              ),
        ),
      );
    } else if (isPdf) {
      // --- PDF Preview Icon ---
      content = GestureDetector(
        onTap: () {
          Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute(
              builder:
                  (_) => FullScreenPdfViewer(
                    pdfUrl: downloadUrl,
                    pdfName: fileName,
                  ),
              fullscreenDialog: true,
            ),
          );
        },
        child: Tooltip(
          message: fileName,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.picture_as_pdf, color: colorScheme.error, size: 30),
              const SizedBox(height: 4),
              Icon(
                Icons.open_in_new,
                size: 14,
                color: colorScheme.primary,
              ), // Indicate tappable
            ],
          ),
        ),
      );
    } else {
      // --- Generic Document Preview Icon ---
      content = GestureDetector(
        onTap:
            () => _launchUrl(
              downloadUrl,
            ), // Use existing _launchUrl for generic download
        child: Tooltip(
          message: fileName,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.insert_drive_file,
                color: colorScheme.onSurfaceVariant,
                size: 30,
              ),
              const SizedBox(height: 4),
              Icon(
                Icons.download,
                size: 14,
                color: colorScheme.primary,
              ), // Indicate download
            ],
          ),
        ),
      );
    }

    // --- Return the container with content ---
    return Container(
      width: previewSize,
      height: previewSize,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(
          (255 * 0.7).round(),
        ),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(
          color: Colors.black.withAlpha((255 * 0.1).round()),
          width: 0.5,
        ),
      ),
      child: content,
    );
  }

  // --- ADDED: Helper to check if file is image (based on name) ---
  // (Similar to the one in FileUploadWidget)
  bool _isImageFile(String fileName) {
    final lowerCaseFileName = fileName.toLowerCase();
    return lowerCaseFileName.endsWith('.jpg') ||
        lowerCaseFileName.endsWith('.jpeg') ||
        lowerCaseFileName.endsWith('.png') ||
        lowerCaseFileName.endsWith('.gif') ||
        lowerCaseFileName.endsWith('.heic') ||
        lowerCaseFileName.endsWith('.webp');
  }

  // --- NEW: NIF Check Logic --- //
  Future<void> _checkNif() async {
    final nifToCheck = _nifController.text.trim();

    // --- ADDED: Client-side NIF validation ---
    final nifRegExp = RegExp(r'^\d{9}$'); // Exactly 9 digits
    if (nifToCheck.isEmpty) {
      // Don't show error if empty, just reset status
      setState(() {
        _nifCheckStatus = NifCheckStatus.initial;
        _nifCheckMessage = null;
      });
      return;
    } else if (!nifRegExp.hasMatch(nifToCheck)) {
      setState(() {
        _nifCheckStatus = NifCheckStatus.error;
        _nifCheckMessage =
            'NIF Inválido (deve ter 9 dígitos)'; // Invalid NIF (must have 9 digits)
      });
      return;
    }
    // --- END ADDED ---

    setState(() {
      _nifCheckStatus = NifCheckStatus.loading;
      _nifCheckMessage = null;
    });

    // --- Get Salesforce Auth Details --- //
    String? accessToken;
    String? instanceUrl;
    bool authValid = false;
    try {
      final sfAuthNotifier = ref.read(salesforceAuthProvider.notifier);
      accessToken = await sfAuthNotifier.getValidAccessToken();
      instanceUrl = sfAuthNotifier.currentInstanceUrl;
      if (accessToken != null && instanceUrl != null) {
        authValid = true;
      } else {
        _nifCheckStatus = NifCheckStatus.error;
        _nifCheckMessage = 'Erro: Sessão Salesforce inválida ou expirada.';
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error fetching Salesforce auth details for NIF check: $e");
      }
      _nifCheckStatus = NifCheckStatus.error;
      _nifCheckMessage = 'Erro ao obter detalhes da sessão Salesforce.';
    }

    if (!authValid) {
      // If auth details are invalid, update state and stop
      setState(() {
        _nifCheckStatus = NifCheckStatus.error;
      });
      return;
    }
    // --- End Get Salesforce Auth Details --- //

    try {
      // ** Call function in the correct region (us-central1) **
      final HttpsCallable callable = FirebaseFunctions.instanceFor(
        region: 'us-central1',
      ) // <-- CORRECT REGION
      .httpsCallable(
        'checkNifExistsInSalesforce',
        options: HttpsCallableOptions(timeout: Duration(seconds: 30)),
      );

      // ** Pass required parameters **
      final result = await callable.call<Map<String, dynamic>>({
        'nif': nifToCheck,
        'accessToken': accessToken,
        'instanceUrl': instanceUrl,
      });

      // ... rest of the result handling ...
      final data = result.data;
      final bool exists = data['exists'] as bool? ?? false;
      final String? errorMsg =
          data['error']
              as String?; // Renamed to avoid conflict with NifCheckStatus.error
      final bool sessionExpired = data['sessionExpired'] as bool? ?? false;

      if (sessionExpired) {
        setState(() {
          _nifCheckStatus = NifCheckStatus.error;
          _nifCheckMessage = 'Erro: Sessão Salesforce expirou.';
        });
      } else if (errorMsg != null) {
        setState(() {
          _nifCheckStatus = NifCheckStatus.error;
          _nifCheckMessage = 'Erro na verificação: $errorMsg';
        });
      } else if (exists) {
        setState(() {
          _nifCheckStatus = NifCheckStatus.exists;
          _nifCheckMessage =
              'Cliente existe no Salesforce.'; // Simplified message
        });
      } else {
        setState(() {
          _nifCheckStatus = NifCheckStatus.notExists;
          _nifCheckMessage =
              'Cliente não existe no Salesforce.'; // Simplified message
        });
      }
    } on FirebaseFunctionsException catch (e) {
      if (kDebugMode) {
        print(
          "FirebaseFunctionsException during NIF check: ${e.code} - ${e.message}",
        );
      }
      setState(() {
        _nifCheckStatus = NifCheckStatus.error;
        _nifCheckMessage =
            'Erro ao verificar NIF (${e.code})'; // Simplified Cloud Function error
      });
    } catch (e) {
      if (kDebugMode) {
        print("Generic error during NIF check: $e");
      }
      setState(() {
        _nifCheckStatus = NifCheckStatus.error;
        _nifCheckMessage =
            'Erro inesperado ao verificar NIF.'; // Simplified generic error
      });
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingNif = false; // Ensure loading state is reset
        });
      }
    }
  }

  // --- NEW: NIF Status Indicator Widget --- //
  Widget _buildNifStatusIndicator() {
    IconData iconData;
    Color iconColor;
    String tooltipMessage = _nifCheckMessage ?? '';

    switch (_nifCheckStatus) {
      case NifCheckStatus.loading:
        // Show loading indicator directly now
        return const SizedBox(
          width: 20, // Match size for alignment consistency
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case NifCheckStatus.exists:
        iconData = Icons.check_circle;
        iconColor = Colors.green;
        break;
      case NifCheckStatus.notExists:
        iconData = Icons.info_outline;
        iconColor = Colors.orange;
        break;
      case NifCheckStatus.error:
        iconData = Icons.error_outline;
        iconColor = Colors.red;
        break;
      case NifCheckStatus.initial:
        // Show nothing initially
        return const SizedBox(width: 24); // Placeholder for alignment
    }

    return Tooltip(
      message: tooltipMessage,
      child: Icon(iconData, color: iconColor, size: 24),
    );
  }

  // --- END NEW --- //

  // Add this method before _submitForm
  String formatDateForSalesforce(String dateStr) {
    if (dateStr.isEmpty) return '';
    final parts = dateStr.split('/');
    if (parts.length != 3) return dateStr;
    return '${parts[2]}-${parts[0].padLeft(2, '0')}-${parts[1].padLeft(2, '0')}';
  }

  Future<void> _submitForm() async {
    try {
      setState(() => _isSubmitting = true);

      // Get Salesforce auth data
      final sfAuthNotifier = ref.read(salesforceAuthProvider.notifier);
      final String? accessToken = await sfAuthNotifier.getValidAccessToken();
      final String? instanceUrl = sfAuthNotifier.currentInstanceUrl;

      if (accessToken == null || instanceUrl == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Sessão Salesforce inválida. Tente sair e entrar novamente ou atualizar.',
              ),
            ),
          );
        }
        setState(() => _isSubmitting = false);
        return;
      }

      // Format close date to ISO 8601 (YYYY-MM-DD)
      String formattedCloseDate;
      if (_selectedFechoDate != null) {
        formattedCloseDate = DateFormat('yyyy-MM-dd').format(_selectedFechoDate!);
      } else {
        formattedCloseDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
      }

      final params = CreateOppParams(
        submissionId: widget.submission.id!,
        accessToken: accessToken,
        instanceUrl: instanceUrl,
        resellerSalesforceId: _resellerSalesforceId!,
        opportunityName: _nameController.text,
        nif: _nifController.text,
        companyName: _companyNameController.text,
        segment: _selectedSegmentoCliente ?? '--None--',
        solution: _selectedSolucao ?? '--None--',
        closeDate: formattedCloseDate,
        opportunityType: _tipoOportunidadeController.text,
        phase: _faseController.text,
        fileUrls: widget.submission.documentUrls,
      );

      final result = await ref.read(createOpportunityProvider(params).future);
      
      if (result.success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Oportunidade criada com sucesso!')),
          );
          context.pop();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao criar oportunidade: ${result.error}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao criar oportunidade: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}

// --- NEW: Enum for NIF Check Status --- //
enum NifCheckStatus { initial, loading, exists, notExists, error }

// --- END NEW --- //
