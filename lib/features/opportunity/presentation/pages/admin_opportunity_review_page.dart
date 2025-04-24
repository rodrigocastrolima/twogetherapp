import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:url_launcher/url_launcher.dart'; // Needed for invoice link
import 'package:flutter/foundation.dart'; // For kDebugMode
import 'package:firebase_storage/firebase_storage.dart'; // Import Firebase Storage
import 'package:cloud_functions/cloud_functions.dart'; // Import Cloud Functions
import 'package:twogether/core/models/service_submission.dart'; // Using package path
import 'package:twogether/presentation/widgets/full_screen_image_viewer.dart'; // Using package path
import 'package:twogether/presentation/widgets/full_screen_pdf_viewer.dart'; // Using package path
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // Import AppLocalizations
import 'package:twogether/core/theme/theme.dart'; // Import AppTheme for context access if needed indirectly
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
  // --- END ADDED ---

  // State variables for dropdowns and date picker
  String? _selectedSegmentoCliente;
  String? _selectedSolucao;
  DateTime? _selectedFechoDate;

  // State variables for derived/fetched data
  String? _resellerDisplayName;
  bool _isLoadingReseller = true;
  String? _tipoOportunidadeValue;
  final String _faseValue = "0 - Oportunidade Identificada"; // Fixed value
  String? _resellerSalesforceId; // Added to store the fetched Salesforce ID

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
    _agenteRetailController = TextEditingController(text: 'Loading...');
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
    // --- END Initialize ---

    // Initialize derived picklist values
    _determineTipoOportunidade();
    _tipoOportunidadeController.text =
        _tipoOportunidadeValue ?? 'Not Determined'; // Set controller text

    // Start fetching reseller display name
    _fetchResellerName();
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
    // --- END Dispose ---
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
      _isLoadingReseller = true;
      _resellerDisplayName = null; // Reset on fetch start
      _resellerSalesforceId = null; // Reset on fetch start
      _agenteRetailController.text = 'Loading...'; // Update controller
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
                "${_resellerDisplayName ?? "Reseller"} (Missing SF ID!)";
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
          _resellerDisplayName = "Error: Not Found"; // Indicate error fetching
          _agenteRetailController.text =
              "Error: Not Found"; // Update controller
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
          _resellerDisplayName = "Error: Fetch Failed";
          _agenteRetailController.text =
              "Error: Fetch Failed"; // Update controller
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not launch $urlString')));
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
            String fileName = 'Unknown File';
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
            String fileName = 'Unknown File';
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
          title: const Text('Reject Submission'), // TODO: l10n
          content: Form(
            key: dialogFormKey,
            child: SingleChildScrollView(
              child: ListBody(
                children: <Widget>[
                  const Text(
                    'Please provide the reason for rejecting this submission.',
                  ), // TODO: l10n
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: reasonController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Enter reason here...', // TODO: l10n
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Rejection reason cannot be empty'; // TODO: l10n
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
              child: const Text('Cancel'), // TODO: l10n
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
              child: const Text('Confirm Rejection'), // TODO: l10n
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
    if (!(_formKey.currentState?.validate() ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all required fields.'),
        ), // TODO: l10n
      );
      return;
    }

    // 2. Validate Reseller Salesforce ID
    if (_resellerSalesforceId == null || _resellerSalesforceId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot approve: Reseller Salesforce ID is missing.'),
        ), // TODO: l10n
      );
      return;
    }

    // 3. Get Salesforce Auth Details
    setState(() => _isSubmitting = true);
    final sfAuthNotifier = ref.read(salesforceAuthProvider.notifier);
    final String? accessToken = await sfAuthNotifier.getValidAccessToken();
    final String? instanceUrl = sfAuthNotifier.currentInstanceUrl;

    if (accessToken == null || instanceUrl == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Salesforce session invalid. Please try logging out and back in, or refresh.',
            ),
          ), // TODO: l10n
        );
      }
      setState(() => _isSubmitting = false);
      return;
    }

    // 4. Gather Parameters
    final params = CreateOppParams(
      submissionId: widget.submission.id!, // Assume ID is non-null here
      accessToken: accessToken,
      instanceUrl: instanceUrl,
      resellerSalesforceId: _resellerSalesforceId!,
      opportunityName: _nameController.text,
      nif: _nifController.text,
      companyName:
          widget.submission.companyName ??
          widget.submission.responsibleName, // Use fallback logic
      segment: _selectedSegmentoCliente!, // Assume selected
      solution: _selectedSolucao!, // Assume selected
      closeDate:
          _fechoController.text, // <-- CORRECTED: Pass the formatted string
      opportunityType: _tipoOportunidadeValue!, // Assume determined
      phase: _faseValue, // Use fixed value
      fileUrls: widget.submission.documentUrls, // Pass the list
    );

    // 5. Call the Provider
    try {
      // We call .future directly as we want to handle the result here, not just display UI based on AsyncValue
      final result = await ref.read(createOpportunityProvider(params).future);
      _handleCreateResult(result); // Handle success/failure
    } catch (e) {
      // Catch potential errors if the provider itself throws before returning AsyncError
      _handleCreateError(e);
    } finally {
      // Ensure loading state is reset even if error handling fails (though unlikely)
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  // --- NEW: Handler for Cloud Function Result ---
  Future<void> _handleCreateResult(CreateOppResult result) async {
    final l10n = AppLocalizations.of(context)!; // Get l10n
    if (!mounted) return; // Check if widget is still mounted

    if (result.success) {
      // --- Success Case ---
      // Update Firestore document
      try {
        await FirebaseFirestore.instance
            .collection('serviceSubmissions')
            .doc(widget.submission.id)
            .update({
              'status': 'approved', // Update status
              'salesforceOpportunityId': result.opportunityId, // Store SF ID
              'reviewedAt': FieldValue.serverTimestamp(), // Timestamp approval
              'reviewDetails': null, // Clear any previous rejection details
            });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.opportunityApprovedSuccess),
          ), // TODO: l10n key
        );

        // Navigate back or to the new opportunity list
        // context.pop(); // Simple pop back
        // OR navigate to a different list page, maybe forcing refresh
        context.go(
          '/admin',
        ); // Navigate back to admin home/verification list for now
      } catch (firestoreError) {
        print("Error updating Firestore after SF success: $firestoreError");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "${l10n.opportunityApprovedSuccessButFirestoreError}: $firestoreError",
            ),
          ), // TODO: l10n key
        );
        // Still likely want to navigate away or reset state
        context.go('/admin');
      }
    } else {
      // --- Failure Case ---
      if (result.sessionExpired) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.errorSalesforceSessionExpired),
          ), // TODO: l10n key
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "${l10n.errorCreatingOpportunity}: ${result.error ?? 'Unknown error'}",
            ),
          ), // TODO: l10n key
        );
      }
    }
  }

  // --- NEW: Handler for Provider Call Errors ---
  void _handleCreateError(Object e) {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!; // Get l10n
    print("Error calling createOpportunityProvider: $e");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("${l10n.errorUnexpected}: ${e.toString()}"),
      ), // TODO: l10n key
    );
  }

  @override
  Widget build(BuildContext context) {
    // Calculate status bar height
    // final statusBarHeight = MediaQuery.of(context).padding.top; // No longer needed
    final theme = Theme.of(context); // Get theme
    final colorScheme = theme.colorScheme; // Get color scheme
    final textTheme = theme.textTheme; // Get text theme
    final l10n = AppLocalizations.of(context)!; // Get localizations

    // Reintroduce Scaffold for proper context and structure
    return Scaffold(
      backgroundColor: colorScheme.surface, // Use theme surface color
      appBar: AppBar(
        // Use AppBarTheme from main theme.dart
        title: Text(
          l10n.opportunityDetailTitle, // Use localization key
          // Style defaults to AppBarTheme's titleTextStyle
        ),
        // backgroundColor defaults to AppBarTheme
        // elevation defaults to AppBarTheme
        // iconTheme defaults to AppBarTheme
        leading: IconButton(
          // Explicit back button if needed, AppBar provides one by default
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        // Make SingleChildScrollView the direct body
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.opportunityDetailHeadline, // Use localization key
                style: textTheme.headlineSmall, // Use theme text style
              ),
              const SizedBox(height: 16),

              // --- Display Status --- // ADDED
              Row(
                children: [
                  Text(
                    'Status:',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color:
                          widget.submission.status == 'rejected'
                              ? colorScheme.errorContainer.withOpacity(0.8)
                              : colorScheme.secondaryContainer.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      widget.submission.status
                          .replaceAll('_', ' ')
                          .split(' ')
                          .map(
                            (word) =>
                                '${word[0].toUpperCase()}${word.substring(1)}',
                          )
                          .join(' '),
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color:
                            widget.submission.status == 'rejected'
                                ? colorScheme.onErrorContainer
                                : colorScheme.onSecondaryContainer,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 32),
              // -------------------- //

              // --- Simplified Reference & Required Fields ---
              TextFormField(
                controller: _agenteRetailController,
                readOnly: true,
                decoration: InputDecoration(
                  labelText:
                      l10n.opportunityDetailAgentLabel, // Use localization key
                  // Inherits border, fill, etc. from global theme
                ),
              ),
              const Divider(height: 32),

              // --- Salesforce Opportunity Fields ---
              Text(
                l10n.opportunityDetailSalesforceSectionTitle, // Use localization key
                style: textTheme.titleLarge, // Use theme text style
              ),
              const SizedBox(height: 16),

              // Opportunity Name (Auto-calculated, but editable)
              // --- Removed custom Column/Padding/SizedBox wrapper ---
              TextFormField(
                controller: _nameController,
                // style: textTheme.bodyLarge, // Inherited via InputDecorator
                decoration: InputDecoration(
                  labelText:
                      l10n.opportunityDetailNameLabel, // Use localization key
                  // Inherits border, fill, padding etc. from global theme
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return l10n
                        .opportunityDetailNameRequiredError; // Use localization key
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // NIF (From submission, editable, mandatory)
              // --- Removed custom Column/Padding/SizedBox wrapper ---
              TextFormField(
                controller: _nifController,
                decoration: InputDecoration(
                  labelText:
                      l10n.opportunityDetailNifLabel, // Use localization key
                  // Inherits border, fill, padding etc. from global theme
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return l10n
                        .opportunityDetailNifRequiredError; // Use localization key
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Data de Criação (Auto-set based on view time)
              // --- Refactored Read-Only Field ---
              TextFormField(
                controller: _dataCriacaoController,
                readOnly: true,
                decoration: InputDecoration(
                  labelText:
                      l10n.opportunityDetailCreationDateLabel, // Use localization key
                ),
              ),
              const SizedBox(height: 16),

              // Data da última actualização de Fase (Auto-set based on view time)
              // --- Refactored Read-Only Field ---
              TextFormField(
                controller: _dataUltimaAtualizacaoController,
                readOnly: true,
                decoration: InputDecoration(
                  labelText:
                      l10n.opportunityDetailLastUpdateLabel, // Use localization key
                ),
              ),
              const SizedBox(height: 16),

              // Fase (Fixed value - Display as read-only)
              // --- Refactored Read-Only Field ---
              TextFormField(
                controller: _faseController,
                readOnly: true,
                decoration: InputDecoration(
                  labelText:
                      l10n.opportunityDetailPhaseLabel, // Use localization key
                ),
              ),
              const SizedBox(height: 16),

              // Tipo de Oportunidade (Derived value - Display as read-only)
              // --- Refactored Read-Only Field ---
              TextFormField(
                controller: _tipoOportunidadeController,
                readOnly: true,
                decoration: InputDecoration(
                  labelText:
                      l10n.opportunityDetailTypeLabel, // Use localization key
                ),
              ),
              const SizedBox(height: 16),

              // Segmento de Cliente (Picklist - Required)
              // --- Removed custom Column/Padding/SizedBox wrapper ---
              DropdownButtonFormField<String>(
                value: _selectedSegmentoCliente,
                // style: textTheme.bodyLarge, // Inherited via InputDecorator
                // dropdownColor: colorScheme.surfaceVariant, // Use theme surface variant
                // borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadiusValue), // Use theme constant if available
                decoration: InputDecoration(
                  labelText:
                      l10n.opportunityDetailSegmentLabel, // Use localization key
                  // Inherits border, fill, padding etc. from global theme
                ),
                // Populate items from _segmentoOptions
                items:
                    _segmentoOptions.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                onChanged: (value) {
                  // Update state variable on change
                  setState(() {
                    _selectedSegmentoCliente = value;
                  });
                },
                validator: (value) {
                  if (value == null || value == '--None--') {
                    return l10n
                        .opportunityDetailSegmentRequiredError; // Use localization key
                  }
                  return null;
                },
                hint: Text(
                  l10n.opportunityDetailSegmentHint,
                ), // Use localization key
              ),
              const SizedBox(height: 16),

              // Solução (Picklist - Required)
              // --- Removed custom Column/Padding/SizedBox wrapper ---
              DropdownButtonFormField<String>(
                value: _selectedSolucao,
                // style: textTheme.bodyLarge, // Inherited via InputDecorator
                // dropdownColor: colorScheme.surfaceVariant, // Use theme surface variant
                // borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadiusValue), // Use theme constant
                decoration: InputDecoration(
                  labelText:
                      l10n.opportunityDetailSolutionLabel, // Use localization key
                  // Inherits border, fill, padding etc. from global theme
                ),
                // Populate items from _solucaoOptions
                items:
                    _solucaoOptions.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                onChanged: (value) {
                  // Update state variable on change
                  setState(() {
                    _selectedSolucao = value;
                  });
                },
                validator: (value) {
                  if (value == null || value == '--None--') {
                    return l10n
                        .opportunityDetailSolutionRequiredError; // Use localization key
                  }
                  return null;
                },
                hint: Text(
                  l10n.opportunityDetailSolutionHint,
                ), // Use localization key
              ),
              const SizedBox(height: 16),

              // Data de Previsão de Fecho (Date - Required)
              // --- Removed custom Column/Padding/SizedBox wrapper ---
              TextFormField(
                controller: _fechoController,
                decoration: InputDecoration(
                  labelText:
                      l10n.opportunityDetailCloseDateLabel, // Use localization key
                  hintText:
                      l10n.opportunityDetailCloseDateHint, // Use localization key
                  // Inherits border, fill, padding etc. from global theme
                  suffixIcon: const Icon(Icons.calendar_today),
                ),
                keyboardType: TextInputType.datetime,
                readOnly: true, // Prevent manual text input, use picker
                onTap: () async {
                  // Implement Date Picker logic
                  DateTime? pickedDate = await showDatePicker(
                    context: context,
                    initialDate: _selectedFechoDate ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2101),
                    // Use theme colors for picker
                    builder: (context, child) {
                      return Theme(
                        data: theme.copyWith(
                          colorScheme: theme.colorScheme.copyWith(
                            primary:
                                colorScheme.primary, // header background color
                            onPrimary:
                                colorScheme.onPrimary, // header text color
                            onSurface: colorScheme.onSurface, // body text color
                          ),
                          textButtonTheme: TextButtonThemeData(
                            style: TextButton.styleFrom(
                              foregroundColor:
                                  colorScheme.primary, // button text color
                            ),
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (pickedDate != null && pickedDate != _selectedFechoDate) {
                    // Update state/controller with pickedDate (formatted as YYYY-MM-DD)
                    setState(() {
                      _selectedFechoDate = pickedDate;
                      _fechoController.text = DateFormat(
                        'yyyy-MM-dd',
                      ).format(pickedDate);
                    });
                    print(
                      'Date selected: ${DateFormat('yyyy-MM-dd').format(pickedDate)}',
                    );
                  }
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return l10n
                        .opportunityDetailCloseDateRequiredError; // Use localization key
                  }
                  // Optional: Validate date format if needed, though picker ensures it
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // --- Invoice Section --- Updated to handle multiple files
              const Divider(height: 32),
              Text(
                l10n.opportunityDetailInvoiceSectionTitle, // Use localization key
                style: textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
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
                          l10n.opportunityDetailInvoiceLoading, // Use localization key
                          style: textTheme.bodyMedium,
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
                            '${l10n.opportunityDetailInvoiceError}: ${snapshot.error}',
                            style: textTheme.bodyMedium?.copyWith(
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
                      l10n.opportunityDetailInvoiceNotAvailable, // Use localization key
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant, // Use theme color
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
              const SizedBox(height: 32),

              // --- Actions or Rejection Info --- // MODIFIED
              // Conditionally display based on status
              if (widget.submission.status == 'rejected')
                _buildRejectionInfoSection(context, theme, l10n)
              else // Assuming 'pending_review'
                _buildActionButtons(context, theme, l10n),
              // ---------------------------------- //
              const SizedBox(height: 24),
            ],
          ),
        ),
      ), // End of Scaffold body (SingleChildScrollView)
    ); // End of Scaffold
  }

  // --- NEW: Widget Builder for Rejection Info Section ---
  Widget _buildRejectionInfoSection(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    final rejectionReason = widget.submission.reviewDetails?.rejectionReason;
    final reviewTimestamp =
        widget.submission.reviewDetails?.reviewTimestamp
            ?.toDate(); // Convert Timestamp to DateTime
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
        color: theme.colorScheme.errorContainer.withOpacity(0.15),
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
                'Rejection Details', // Placeholder
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ),
          const Divider(height: 20, thickness: 0.5),
          Text(
            "Rejection Reason:", // Placeholder
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            rejectionReason ?? "No reason provided.", // Placeholder
            style: theme.textTheme.bodyMedium,
          ),
          if (reviewTimestamp != null || reviewerId != null) ...[
            const SizedBox(height: 12),
            Text(
              "Rejected on: $formattedTimestamp", // Placeholder
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            // Optionally display reviewer if needed
            // Text(
            //   "Reviewer: ${reviewerId ?? 'Unknown'}",
            //   style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            // ),
          ],
        ],
      ),
    );
  }
  // ---------------------------------------------------- //

  // --- MODIFIED: _buildActionButtons --- //
  Widget _buildActionButtons(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    final colorScheme = theme.colorScheme;
    return Center(
      child: Wrap(
        spacing: 16.0,
        runSpacing: 8.0,
        alignment: WrapAlignment.center,
        children: [
          // Approve Button
          ElevatedButton(
            // *** MODIFIED: Call the new handler ***
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
                    : Text(l10n.opportunityApproveButton),
          ),
          // Reject Button
          OutlinedButton.icon(
            icon: const Icon(Icons.cancel_outlined),
            label: Text(l10n.opportunityRejectButton),
            onPressed:
                _isSubmitting
                    ? null
                    : () async {
                      final reason = await _showRejectionDialog();
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
          content: Text("Error: Submission ID missing"),
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
      print("Warning: Using placeholder Admin ID for rejection.");
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
        print("Error creating rejection notification: $e");
        // Non-critical, don't fail the whole rejection
      }
      // ---------------------------------------------------

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              // AppLocalizations.of(context)!.opportunityRejectedSuccess, // TODO l10n
              'Submission rejected successfully.',
            ),
            backgroundColor:
                Colors.orange, // Use orange/yellow for rejection success
          ),
        );
        // Optionally navigate back
        if (Navigator.canPop(context)) {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      print("Error rejecting submission: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              // '${AppLocalizations.of(context)!.opportunityRejectedError}: $e', // TODO l10n
              'Failed to reject submission: ${e.toString()}',
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
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
        'title':
            'Opportunity Rejected', // Placeholder - Use l10n.notificationOpportunityRejectedTitle
        'body':
            'Your submission was rejected. Reason: $reason', // Placeholder - Use l10n.notificationOpportunityRejectedBody(reason)
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
    final l10n = AppLocalizations.of(context)!;

    final String? downloadUrl = fileData['url'];
    final String? storagePath = fileData['path'];
    final String? error = fileData['error'];
    final String fileName = fileData['fileName'] ?? 'Unknown File';
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
        message: 'Error loading: $error',
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
        message: 'Preview unavailable',
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
                message: 'Preview error: $error',
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
        color: colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.dividerColor.withOpacity(0.3),
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
}
