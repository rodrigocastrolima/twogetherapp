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

  // --- ADDED: Fetch Invoice Download URL ---
  Future<String?> _fetchInvoiceDownloadUrl() async {
    final storagePath = widget.submission.invoicePhoto?.storagePath;
    if (storagePath == null || storagePath.isEmpty) {
      print("No storage path found for invoice.");
      return null; // No path, no URL
    }

    try {
      if (kDebugMode) {
        print("Attempting to get download URL for: $storagePath");
      }
      final downloadUrl =
          await FirebaseStorage.instance.ref(storagePath).getDownloadURL();
      if (kDebugMode) {
        print("Obtained download URL: $downloadUrl");
      }
      // Store the fetched URL in state if needed outside FutureBuilder
      // WidgetsBinding.instance.addPostFrameCallback((_) {
      //   if (mounted) setState(() => _invoiceDownloadUrl = downloadUrl);
      // });
      return downloadUrl;
    } on FirebaseException catch (e) {
      if (kDebugMode) {
        print("Firebase Error getting download URL: ${e.code} - ${e.message}");
      }
      // Handle specific errors if needed (e.g., object-not-found)
      return null; // Indicate error by returning null
    } catch (e) {
      if (kDebugMode) {
        print("Generic Error getting download URL: $e");
      }
      return null; // Indicate error
    }
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

              // --- Simplified Reference & Required Fields ---
              // Removed: Original Submission ID, Original Reseller Name, Email, Phone
              // --- Refactored Read-Only Field ---
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

              // --- Invoice --- Updated with Preview & Tap Action
              const Divider(height: 32),
              Text(
                l10n.opportunityDetailInvoiceSectionTitle, // Use localization key
                style: textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              // Use FutureBuilder to fetch URL and display preview/link
              FutureBuilder<String?>(
                future: _fetchInvoiceDownloadUrl(),
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

                  // Check for errors
                  if (snapshot.hasError) {
                    return Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: colorScheme.error,
                        ), // Use theme color
                        const SizedBox(width: 8),
                        Text(
                          l10n.opportunityDetailInvoiceError, // Use localization key
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.error, // Use theme color
                          ),
                        ),
                      ],
                    );
                  }

                  // Check if data (URL) exists and is not null
                  final downloadUrl = snapshot.data;
                  final invoicePhoto = widget.submission.invoicePhoto;

                  if (downloadUrl == null || invoicePhoto == null) {
                    return Text(
                      l10n.opportunityDetailInvoiceNotAvailable, // Use localization key
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant, // Use theme color
                      ),
                    );
                  }

                  // --- Display Image Preview (Tappable) ---
                  final contentType = invoicePhoto.contentType.toLowerCase();
                  final fileName = invoicePhoto.fileName;

                  if (contentType.startsWith('image/')) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () {
                            // Navigate to full-screen viewer on tap, using ROOT navigator
                            Navigator.of(context, rootNavigator: true).push(
                              MaterialPageRoute(
                                builder:
                                    (_) => FullScreenImageViewer(
                                      imageUrl: downloadUrl,
                                      imageName:
                                          fileName, // Pass name for context
                                    ),
                                fullscreenDialog:
                                    true, // Treat as a fullscreen dialog
                              ),
                            );
                          },
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxHeight: 200, // Keep preview height reasonable
                              maxWidth: double.infinity,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(
                                8.0,
                              ), // Use standard radius value
                              child: Image.network(
                                downloadUrl,
                                fit:
                                    BoxFit
                                        .cover, // Cover for preview looks better
                                // Add loading/error builders for the preview image itself
                                loadingBuilder: (
                                  context,
                                  child,
                                  loadingProgress,
                                ) {
                                  if (loadingProgress == null) return child;
                                  return Center(
                                    child: CircularProgressIndicator(
                                      value:
                                          loadingProgress.expectedTotalBytes !=
                                                  null
                                              ? loadingProgress
                                                      .cumulativeBytesLoaded /
                                                  loadingProgress
                                                      .expectedTotalBytes!
                                              : null,
                                      color:
                                          colorScheme
                                              .primary, // Use theme color
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  return Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.broken_image,
                                          color:
                                              colorScheme
                                                  .onSurfaceVariant, // Use theme color
                                          size: 40,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          l10n.opportunityDetailInvoicePreviewError, // Use localization key
                                          style: textTheme.bodySmall?.copyWith(
                                            color:
                                                colorScheme
                                                    .onSurfaceVariant, // Use theme color
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  } else if (contentType == 'application/pdf') {
                    return GestureDetector(
                      onTap: () {
                        // Navigate to full-screen PDF viewer on tap, using ROOT navigator
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
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          children: [
                            Icon(
                              Icons.picture_as_pdf,
                              color:
                                  colorScheme
                                      .error, // Use theme error color for PDF
                              size: 30,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                fileName,
                                style: textTheme.bodyLarge,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              // Add a visual cue for tapping
                              Icons.open_in_new,
                              size: 18,
                              color: colorScheme.primary, // Correct theme usage
                            ),
                          ],
                        ),
                      ),
                    );
                  } else {
                    // Fallback for other types
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.insert_drive_file,
                              size: 30,
                              color:
                                  colorScheme
                                      .onSurfaceVariant, // Use theme color
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                fileName,
                                style: textTheme.bodyLarge,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          icon: const Icon(Icons.download),
                          label: Text(
                            l10n.opportunityDetailInvoiceDownloadButton, // Use localization key
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor:
                                colorScheme.primary, // Use theme color
                          ),
                          onPressed: () => _launchUrl(downloadUrl),
                        ),
                      ],
                    );
                  }
                },
              ),
              const SizedBox(height: 32),

              // --- Actions ---
              Center(
                child: Wrap(
                  spacing: 16.0, // Horizontal space between buttons
                  runSpacing: 8.0, // Vertical space if buttons wrap
                  alignment: WrapAlignment.center,
                  children: [
                    // Approve Button (Existing)
                    ElevatedButton(
                      onPressed:
                          _isSubmitting
                              ? null
                              : () async {
                                // Disable button when submitting
                                // Validate the form
                                if (_formKey.currentState?.validate() ??
                                    false) {
                                  // --- Check if essential fetched data is available ---
                                  if (_isLoadingReseller) {
                                    // Add mounted check before showing SnackBar
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          l10n.opportunitySubmitLoadingAgentError, // Use localization key
                                        ),
                                      ),
                                    );
                                    return; // Prevent submission while loading
                                  }
                                  if (_resellerSalesforceId == null ||
                                      _resellerSalesforceId!.isEmpty) {
                                    // Add mounted check before showing SnackBar
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          l10n.opportunitySubmitMissingAgentError, // Use localization key
                                        ),
                                        backgroundColor: colorScheme.error,
                                      ),
                                    );
                                    return; // Prevent submission if ID is missing
                                  }
                                  // -----------------------------------------------------

                                  // Set loading state
                                  setState(() {
                                    _isSubmitting = true;
                                  });

                                  // If valid and ID exists, collect data
                                  final opportunityData = {
                                    'Name': _nameController.text,
                                    'NIF__c': _nifController.text,
                                    'Data_de_Cria_o_da_Oportunidade__c':
                                        DateFormat(
                                          'yyyy-MM-dd',
                                        ).format(DateTime.now()),
                                    'Data_da_ltima_actualiza_o_de_Fase__c':
                                        DateFormat(
                                          'yyyy-MM-dd',
                                        ).format(DateTime.now()),
                                    'Fase__c': _faseValue,
                                    'tipoOportunidadeValue':
                                        _tipoOportunidadeValue,
                                    'Segmento_de_Cliente__c':
                                        _selectedSegmentoCliente,
                                    'agenteRetailSalesforceId':
                                        _resellerSalesforceId, // Send the ID
                                    'Solu_o__c': _selectedSolucao,
                                    'Data_de_Previs_o_de_Fecho__c':
                                        _fechoController.text,
                                    // Include original submission ID and invoice path for the Cloud Function
                                    'originalSubmissionId':
                                        widget.submission.id,
                                    'invoiceStoragePath':
                                        widget
                                            .submission
                                            .invoicePhoto
                                            ?.storagePath,
                                  };

                                  if (kDebugMode) {
                                    print(
                                      "--- Opportunity Data for Submission ---",
                                    );
                                    opportunityData.forEach((key, value) {
                                      print("$key: $value");
                                    });
                                    print(
                                      "---------------------------------------",
                                    );
                                  }

                                  // --- Call Cloud Function ---
                                  try {
                                    final callable = FirebaseFunctions.instanceFor(
                                      region: 'us-central1',
                                    ) // Ensure region matches function deployment
                                    .httpsCallable(
                                      'createSalesforceOpportunity',
                                    );
                                    final result = await callable
                                        .call<Map<String, dynamic>>(
                                          opportunityData,
                                        );
                                    final resultData = result.data;

                                    if (kDebugMode) {
                                      print(
                                        "Cloud Function Result: $resultData",
                                      );
                                    }

                                    if (resultData['success'] == true) {
                                      // Success!
                                      if (mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              // Use l10n with placeholder
                                              l10n.opportunitySubmitSuccess(
                                                resultData['opportunityId'] ??
                                                    'N/A',
                                              ),
                                            ),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                        // Optionally navigate back or refresh list
                                        if (Navigator.canPop(context)) {
                                          Navigator.of(context).pop();
                                        }
                                      }
                                    } else {
                                      // Handle failure reported by the function
                                      if (mounted) {
                                        // Add mounted check before showing SnackBar
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              // Use l10n with placeholder
                                              l10n.opportunitySubmitFunctionError(
                                                resultData['error'] ??
                                                    l10n.commonUnknownError,
                                              ),
                                            ),
                                            backgroundColor: colorScheme.error,
                                          ),
                                        );
                                      }
                                    }
                                  } on FirebaseFunctionsException catch (e) {
                                    // Handle Cloud Functions specific errors (e.g., permission denied, not found)
                                    if (mounted) {
                                      // Add mounted check before showing SnackBar
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            // Use l10n with placeholders
                                            l10n.opportunitySubmitCloudFunctionError(
                                              e.code,
                                              e.message ?? '',
                                            ),
                                          ),
                                          backgroundColor: colorScheme.error,
                                        ),
                                      );
                                    }
                                    // Use kDebugMode check for print
                                    if (kDebugMode) {
                                      print(
                                        "FirebaseFunctionsException: ${e.code} - ${e.message}",
                                      );
                                    }
                                  } catch (e) {
                                    // Handle unexpected errors during the call
                                    if (mounted) {
                                      // Add mounted check before showing SnackBar
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            // Use l10n with placeholder
                                            l10n.opportunitySubmitUnexpectedError(
                                              e.toString(),
                                            ),
                                          ),
                                          backgroundColor: colorScheme.error,
                                        ),
                                      );
                                    }
                                    // Use kDebugMode check for print
                                    if (kDebugMode) {
                                      print(
                                        "Generic Error calling Cloud Function: $e",
                                      );
                                    }
                                  } finally {
                                    // Reset loading state
                                    if (mounted) {
                                      setState(() {
                                        _isSubmitting = false;
                                      });
                                    }
                                  }
                                  // -------------------------
                                } else {
                                  // Form is invalid, show error message
                                  // Add mounted check before showing SnackBar
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        l10n.commonFormValidationFixErrors, // Use localization key
                                      ),
                                      backgroundColor: colorScheme.error,
                                    ),
                                  );
                                }
                              },
                      style: ElevatedButton.styleFrom(
                        // Inherits style from ElevatedButtonTheme
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 15,
                        ), // Keep padding for emphasis
                      ),
                      child:
                          _isSubmitting
                              ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color:
                                      colorScheme
                                          .onPrimary, // Contrasting color
                                ),
                              )
                              : Text(
                                l10n.opportunityApproveButton, // Use localization key
                              ),
                    ),

                    // --- NEW: Reject Button ---
                    OutlinedButton.icon(
                      icon: const Icon(Icons.cancel_outlined),
                      label: Text(
                        l10n.opportunityRejectButton, // Use localization key
                      ),
                      onPressed:
                          _isSubmitting
                              ? null
                              : () async {
                                // Use kDebugMode check for print
                                if (kDebugMode) {
                                  print('Reject button pressed');
                                }
                                final reason = await _showRejectionDialog();
                                if (reason != null && reason.isNotEmpty) {
                                  // Handle rejection logic
                                  await _handleRejection(reason);
                                }
                              },
                      style: OutlinedButton.styleFrom(
                        // Use theme for styling error buttons if defined, else derive
                        foregroundColor: colorScheme.error,
                        side: BorderSide(
                          color: colorScheme.error.withAlpha(
                            (255 * 0.7).round(),
                          ), // Fix deprecated withOpacity
                          width: 1.5,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 15,
                        ), // Keep padding
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ), // End of Scaffold body (SingleChildScrollView)
    ); // End of Scaffold
  }

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
            'Your submission requires attention. Reason: $reason', // Placeholder - Use l10n.notificationOpportunityRejectedBody(reason)
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'type':
            'opportunity_rejected', // Define a specific type for handling clicks
        'relatedId': submissionId, // Link to the submission
        'relatedDataType':
            'serviceSubmission', // Specify the type of related data
        'icon': 'warning', // Optional: suggest an icon name
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
}
