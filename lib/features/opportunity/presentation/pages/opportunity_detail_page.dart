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

  // State for invoice button loading
  bool _isFetchingInvoiceUrl = false;

  // State for submission button loading
  bool _isSubmitting = false;

  // --- ADDED: State for Invoice Preview ---
  String? _invoiceDownloadUrl; // To store the fetched URL
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
    super.initState();

    // Initialize controllers
    final potentialOpportunityName =
        '${widget.submission.companyName ?? widget.submission.responsibleName}_${DateFormat('yyyyMMdd_HHmmss').format(widget.submission.submissionDate)}';
    _nameController = TextEditingController(text: potentialOpportunityName);
    _nifController = TextEditingController(text: widget.submission.nif);
    _fechoController = TextEditingController(); // Initialize empty

    // Initialize derived picklist values
    _determineTipoOportunidade();

    // Start fetching reseller display name
    _fetchResellerName();
  }

  @override
  void dispose() {
    // Dispose controllers
    _nameController.dispose();
    _nifController.dispose();
    _fechoController.dispose();
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
    });
    try {
      final resellerDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(widget.submission.resellerId)
              .get();
      if (mounted && resellerDoc.exists) {
        setState(() {
          _resellerDisplayName = resellerDoc.data()?['displayName'] as String?;
          _resellerSalesforceId =
              resellerDoc.data()?['salesforceId']
                  as String?; // Fetch Salesforce ID
          _isLoadingReseller = false;
          if (kDebugMode) {
            print("Fetched reseller display name: $_resellerDisplayName");
            print(
              "Fetched reseller Salesforce ID: $_resellerSalesforceId",
            ); // Log fetched ID
          }
          // Add check if Salesforce ID is missing after fetch
          if (_resellerSalesforceId == null || _resellerSalesforceId!.isEmpty) {
            print("Warning: Reseller found but missing Salesforce ID.");
            // Optionally update display name to show an error state
            _resellerDisplayName =
                (_resellerDisplayName ?? "Reseller") + " (Missing SF ID!)";
          }
        });
      } else if (mounted) {
        if (kDebugMode) {
          print(
            "Reseller document not found for ID: ${widget.submission.resellerId}",
          );
        }
        setState(() {
          _resellerDisplayName = "Error: Not Found"; // Indicate error fetching
          _isLoadingReseller = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error fetching reseller name: $e");
      }
      if (mounted) {
        setState(() {
          _resellerDisplayName = "Error: Fetch Failed";
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
    final statusBarHeight = MediaQuery.of(context).padding.top;

    // Reintroduce Scaffold for proper context and structure
    return Scaffold(
      backgroundColor: Colors.white, // Ensure background matches
      appBar: null, // No standard AppBar
      body: Column(
        // Body is a Column containing our custom header and the scrollable content
        children: [
          // Custom navigation bar Container
          Container(
            color: Colors.white, // Match background
            margin: EdgeInsets.zero,
            padding: EdgeInsets.only(
              top: statusBarHeight,
            ), // Pad inside for status bar
            height: statusBarHeight + 48, // Total height including status bar
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Back button (should work now with Scaffold context)
                IconButton(
                  padding: const EdgeInsets.only(left: 8.0),
                  icon: const Icon(Icons.arrow_back, color: Colors.black87),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                // Title text
                Expanded(
                  child: Text(
                    'Opportunity: ${widget.submission.id}',
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Spacer
                const SizedBox(width: 16),
              ],
            ),
          ),
          // Content Area
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Review and Complete Opportunity Details',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),

                    // --- Simplified Reference & Required Fields ---
                    // Removed: Original Submission ID, Original Reseller Name, Email, Phone
                    _buildReadOnlyField(
                      'Agente Retail (Salesforce User Name)', // Kept for context
                      _isLoadingReseller
                          ? 'Loading...'
                          : (_resellerDisplayName ?? 'Not Found/Error'),
                    ),
                    const Divider(height: 32),

                    // --- Salesforce Opportunity Fields ---
                    Text(
                      'Salesforce Opportunity Fields',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),

                    // Opportunity Name (Auto-calculated, but editable)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Label above the field
                        Padding(
                          padding: const EdgeInsets.only(
                            bottom: 8.0,
                            left: 4.0,
                          ),
                          child: Text(
                            'Oportunidade *',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: Theme.of(context).hintColor),
                          ),
                        ),
                        SizedBox(
                          height: 48, // Fixed height for all field types
                          child: TextFormField(
                            controller: _nameController,
                            style: Theme.of(context).textTheme.bodyLarge,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(20),
                                ),
                                borderSide: BorderSide(
                                  color: Colors.grey.withOpacity(0.3),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(20),
                                ),
                                borderSide: BorderSide(
                                  color: Colors.grey.withOpacity(0.3),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(20),
                                ),
                                borderSide: BorderSide(
                                  color: Colors.grey.withOpacity(0.5),
                                ),
                              ),
                              disabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(20),
                                ),
                                borderSide: BorderSide(
                                  color: Colors.grey.withOpacity(0.3),
                                ),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(20),
                                ),
                                borderSide: BorderSide(
                                  color: Colors.red.withOpacity(0.5),
                                ),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(20),
                                ),
                                borderSide: BorderSide(
                                  color: Colors.red.withOpacity(0.5),
                                ),
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF0F0F4),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              isDense: true,
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Opportunity Name is required';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // NIF (From submission, editable, mandatory)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Label above the field
                        Padding(
                          padding: const EdgeInsets.only(
                            bottom: 8.0,
                            left: 4.0,
                          ),
                          child: Text(
                            'NIF *',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: Theme.of(context).hintColor),
                          ),
                        ),
                        SizedBox(
                          height: 48, // Fixed height for all field types
                          child: TextFormField(
                            controller: _nifController,
                            style: Theme.of(context).textTheme.bodyLarge,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(20),
                                ),
                                borderSide: BorderSide(
                                  color: Colors.grey.withOpacity(0.3),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(20),
                                ),
                                borderSide: BorderSide(
                                  color: Colors.grey.withOpacity(0.3),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(20),
                                ),
                                borderSide: BorderSide(
                                  color: Colors.grey.withOpacity(0.5),
                                ),
                              ),
                              disabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(20),
                                ),
                                borderSide: BorderSide(
                                  color: Colors.grey.withOpacity(0.3),
                                ),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(20),
                                ),
                                borderSide: BorderSide(
                                  color: Colors.red.withOpacity(0.5),
                                ),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(20),
                                ),
                                borderSide: BorderSide(
                                  color: Colors.red.withOpacity(0.5),
                                ),
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF0F0F4),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              isDense: true,
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'NIF is required';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Data de Criação (Auto-set based on view time)
                    _buildReadOnlyField(
                      'Data de Criação da Oportunidade',
                      DateFormat.yMd().format(
                        DateTime.now(),
                      ), // Set to current date
                    ),
                    const SizedBox(height: 16),

                    // Data da última actualização de Fase (Auto-set based on view time)
                    _buildReadOnlyField(
                      'Data da última actualização de Fase',
                      DateFormat.yMd().format(
                        DateTime.now(),
                      ), // Set to current date
                    ),
                    const SizedBox(height: 16),

                    // Fase (Fixed value - Display as read-only)
                    _buildReadOnlyField('Fase', _faseValue),
                    const SizedBox(height: 16),

                    // Tipo de Oportunidade (Derived value - Display as read-only)
                    _buildReadOnlyField(
                      'Tipo de Oportunidade',
                      _tipoOportunidadeValue ?? 'Not Determined',
                    ),
                    const SizedBox(height: 16),

                    // Segmento de Cliente (Picklist - Required)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Label above the field
                        Padding(
                          padding: const EdgeInsets.only(
                            bottom: 8.0,
                            left: 4.0,
                          ),
                          child: Text(
                            'Segmento de Cliente *',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: Theme.of(context).hintColor),
                          ),
                        ),
                        SizedBox(
                          height: 48, // Fixed height for all field types
                          child: DropdownButtonFormField<String>(
                            value: _selectedSegmentoCliente,
                            style: Theme.of(context).textTheme.bodyLarge,
                            dropdownColor: const Color(0xFFF0F0F4),
                            borderRadius: BorderRadius.circular(20),
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(20),
                                ),
                                borderSide: BorderSide(
                                  color: Colors.grey.withOpacity(0.3),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(20),
                                ),
                                borderSide: BorderSide(
                                  color: Colors.grey.withOpacity(0.3),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(20),
                                ),
                                borderSide: BorderSide(
                                  color: Colors.grey.withOpacity(0.5),
                                ),
                              ),
                              disabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(20),
                                ),
                                borderSide: BorderSide(
                                  color: Colors.grey.withOpacity(0.3),
                                ),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(20),
                                ),
                                borderSide: BorderSide(
                                  color: Colors.red.withOpacity(0.5),
                                ),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(20),
                                ),
                                borderSide: BorderSide(
                                  color: Colors.red.withOpacity(0.5),
                                ),
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF0F0F4),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              isDense: true,
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
                                return 'Segmento de Cliente is required';
                              }
                              return null;
                            },
                            hint: const Text('Select Segmento'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Solução (Picklist - Required)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Label above the field
                        Padding(
                          padding: const EdgeInsets.only(
                            bottom: 8.0,
                            left: 4.0,
                          ),
                          child: Text(
                            'Solução *',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: Theme.of(context).hintColor),
                          ),
                        ),
                        SizedBox(
                          height: 48, // Fixed height for all field types
                          child: DropdownButtonFormField<String>(
                            value: _selectedSolucao,
                            style: Theme.of(context).textTheme.bodyLarge,
                            dropdownColor: const Color(0xFFF0F0F4),
                            borderRadius: BorderRadius.circular(20),
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(20),
                                ),
                                borderSide: BorderSide(
                                  color: Colors.grey.withOpacity(0.3),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(20),
                                ),
                                borderSide: BorderSide(
                                  color: Colors.grey.withOpacity(0.3),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(20),
                                ),
                                borderSide: BorderSide(
                                  color: Colors.grey.withOpacity(0.5),
                                ),
                              ),
                              disabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(20),
                                ),
                                borderSide: BorderSide(
                                  color: Colors.grey.withOpacity(0.3),
                                ),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(20),
                                ),
                                borderSide: BorderSide(
                                  color: Colors.red.withOpacity(0.5),
                                ),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(20),
                                ),
                                borderSide: BorderSide(
                                  color: Colors.red.withOpacity(0.5),
                                ),
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF0F0F4),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              isDense: true,
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
                                return 'Solução is required';
                              }
                              return null;
                            },
                            hint: const Text('Select Solução'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Data de Previsão de Fecho (Date - Required)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Label above the field
                        Padding(
                          padding: const EdgeInsets.only(
                            bottom: 8.0,
                            left: 4.0,
                          ),
                          child: Text(
                            'Data de Previsão de Fecho *',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: Theme.of(context).hintColor),
                          ),
                        ),
                        SizedBox(
                          height: 48, // Fixed height for all field types
                          child: TextFormField(
                            controller: _fechoController,
                            style: Theme.of(context).textTheme.bodyLarge,
                            decoration: InputDecoration(
                              hintText: 'YYYY-MM-DD',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(20),
                                ),
                                borderSide: BorderSide(
                                  color: Colors.grey.withOpacity(0.3),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(20),
                                ),
                                borderSide: BorderSide(
                                  color: Colors.grey.withOpacity(0.3),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(20),
                                ),
                                borderSide: BorderSide(
                                  color: Colors.grey.withOpacity(0.5),
                                ),
                              ),
                              disabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(20),
                                ),
                                borderSide: BorderSide(
                                  color: Colors.grey.withOpacity(0.3),
                                ),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(20),
                                ),
                                borderSide: BorderSide(
                                  color: Colors.red.withOpacity(0.5),
                                ),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(20),
                                ),
                                borderSide: BorderSide(
                                  color: Colors.red.withOpacity(0.5),
                                ),
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF0F0F4),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              isDense: true,
                              suffixIcon: const Icon(Icons.calendar_today),
                            ),
                            keyboardType: TextInputType.datetime,
                            readOnly:
                                true, // Prevent manual text input, use picker
                            onTap: () async {
                              // Implement Date Picker logic
                              DateTime? pickedDate = await showDatePicker(
                                context: context,
                                initialDate:
                                    _selectedFechoDate ?? DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2101),
                              );
                              if (pickedDate != null &&
                                  pickedDate != _selectedFechoDate) {
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
                                return 'Data de Previsão de Fecho is required';
                              }
                              // Optional: Validate date format if needed, though picker ensures it
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // --- Invoice --- Updated with Preview & Tap Action
                    const Divider(height: 32),
                    Text(
                      'Invoice',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    // Use FutureBuilder to fetch URL and display preview/link
                    FutureBuilder<String?>(
                      future: _fetchInvoiceDownloadUrl(),
                      builder: (context, snapshot) {
                        // Check connection state
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Row(
                            children: [
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 8),
                              Text('Loading invoice...'),
                            ],
                          );
                        }

                        // Check for errors
                        if (snapshot.hasError) {
                          return const Row(
                            children: [
                              Icon(Icons.error_outline, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Error loading invoice details.'),
                            ],
                          );
                        }

                        // Check if data (URL) exists and is not null
                        final downloadUrl = snapshot.data;
                        final invoicePhoto = widget.submission.invoicePhoto;

                        if (downloadUrl == null || invoicePhoto == null) {
                          return const Text(
                            'No invoice submitted or path is invalid.',
                          );
                        }

                        // --- Display Image Preview (Tappable) ---
                        final contentType =
                            invoicePhoto.contentType.toLowerCase();
                        final fileName = invoicePhoto.fileName;

                        if (contentType.startsWith('image/')) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  // Navigate to full-screen viewer on tap, using ROOT navigator
                                  Navigator.of(
                                    context,
                                    rootNavigator: true,
                                  ).push(
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
                                    maxHeight:
                                        200, // Keep preview height reasonable
                                    maxWidth: double.infinity,
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
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
                                        if (loadingProgress == null)
                                          return child;
                                        return Center(
                                          child: CircularProgressIndicator(
                                            value:
                                                loadingProgress
                                                            .expectedTotalBytes !=
                                                        null
                                                    ? loadingProgress
                                                            .cumulativeBytesLoaded /
                                                        loadingProgress
                                                            .expectedTotalBytes!
                                                    : null,
                                          ),
                                        );
                                      },
                                      errorBuilder: (
                                        context,
                                        error,
                                        stackTrace,
                                      ) {
                                        return const Center(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.broken_image,
                                                color: Colors.grey,
                                                size: 40,
                                              ),
                                              SizedBox(height: 8),
                                              Text('Preview not available.'),
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
                              padding: const EdgeInsets.symmetric(
                                vertical: 8.0,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.picture_as_pdf,
                                    color: Colors.red.shade700,
                                    size: 30,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      fileName,
                                      style:
                                          Theme.of(context).textTheme.bodyLarge,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    // Add a visual cue for tapping
                                    Icons.open_in_new,
                                    size: 18,
                                    color:
                                        Theme.of(context).colorScheme.primary,
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
                                  const Icon(Icons.insert_drive_file, size: 30),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      fileName,
                                      style:
                                          Theme.of(context).textTheme.bodyLarge,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              TextButton.icon(
                                icon: const Icon(Icons.download),
                                label: const Text('Download File'),
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
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Still loading reseller data...',
                                              ),
                                            ),
                                          );
                                          return; // Prevent submission while loading
                                        }
                                        if (_resellerSalesforceId == null ||
                                            _resellerSalesforceId!.isEmpty) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Cannot submit: Reseller Salesforce ID is missing or invalid.',
                                              ),
                                              backgroundColor: Colors.red,
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
                                          final callable =
                                              FirebaseFunctions.instanceFor(
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
                                                    'Opportunity created successfully! ID: ${resultData['opportunityId'] ?? 'N/A'}',
                                                  ),
                                                  backgroundColor: Colors.green,
                                                ),
                                              );
                                              // Optionally navigate back or refresh list
                                              // Navigator.of(context).pop();
                                            }
                                          } else {
                                            // Handle failure reported by the function
                                            if (mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Failed to create opportunity: ${resultData['error'] ?? 'Unknown error'}',
                                                  ),
                                                  backgroundColor:
                                                      Theme.of(
                                                        context,
                                                      ).colorScheme.error,
                                                ),
                                              );
                                            }
                                          }
                                        } on FirebaseFunctionsException catch (
                                          e
                                        ) {
                                          // Handle Cloud Functions specific errors (e.g., permission denied, not found)
                                          if (mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Cloud Function Error: (${e.code}) ${e.message}',
                                                ),
                                                backgroundColor:
                                                    Theme.of(
                                                      context,
                                                    ).colorScheme.error,
                                              ),
                                            );
                                          }
                                          if (kDebugMode) {
                                            print(
                                              "FirebaseFunctionsException: ${e.code} - ${e.message}",
                                            );
                                          }
                                        } catch (e) {
                                          // Handle unexpected errors during the call
                                          if (mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'An unexpected error occurred: $e',
                                                ),
                                                backgroundColor:
                                                    Theme.of(
                                                      context,
                                                    ).colorScheme.error,
                                              ),
                                            );
                                          }
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

                                        // ScaffoldMessenger.of(context).showSnackBar(
                                        //   const SnackBar(
                                        //     content: Text(
                                        //       'Form Valid. Submission logic pending.',
                                        //     ),
                                        //     backgroundColor: Colors.green,
                                        //   ),
                                        // );
                                      } else {
                                        // Form is invalid, show error message
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Please fix the errors in the form.',
                                            ),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 40,
                                vertical: 15,
                              ),
                            ),
                            child:
                                _isSubmitting
                                    ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                    : const Text(
                                      'Approve & Create Opportunity',
                                    ),
                          ),

                          // --- NEW: Reject Button ---
                          OutlinedButton.icon(
                            icon: const Icon(Icons.cancel_outlined),
                            label: const Text('Reject'),
                            onPressed:
                                _isSubmitting
                                    ? null
                                    : () async {
                                      // TODO: Call rejection dialog and handling logic
                                      print('Reject button pressed');
                                      final reason =
                                          await _showRejectionDialog();
                                      if (reason != null && reason.isNotEmpty) {
                                        // Handle rejection logic
                                        await _handleRejection(reason);
                                      }
                                    },
                            style: OutlinedButton.styleFrom(
                              foregroundColor:
                                  Theme.of(context).colorScheme.error,
                              side: BorderSide(
                                color: Theme.of(
                                  context,
                                ).colorScheme.error.withOpacity(0.7),
                                width: 1.5,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 40,
                                vertical: 15,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
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

      await docRef.update({'status': 'rejected', 'reviewDetails': reviewData});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Submission rejected successfully.'),
            backgroundColor:
                Colors.orange, // Use orange/yellow for rejection success
          ),
        );
        // Optionally navigate back
        // Navigator.of(context).pop();
      }
    } catch (e) {
      print("Error rejecting submission: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reject submission: ${e.toString()}'),
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

  // Helper for read-only fields
  Widget _buildReadOnlyField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Label above the field
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).hintColor,
              ),
            ),
          ),
          // Value in a container styled like a disabled TextFormField
          SizedBox(
            height: 48, // Fixed height for all field types
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFF0F0F4),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.withOpacity(0.3)),
              ),
              // Use a properly centered row instead of padding + alignment
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
