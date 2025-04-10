import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // For date formatting
import '../../../../../core/models/service_submission.dart'; // Adjust path if needed
import '../../../../../core/models/service_types.dart'; // For enums if needed later
import 'package:url_launcher/url_launcher.dart'; // Needed for invoice link
import 'package:flutter/foundation.dart'; // For kDebugMode
import 'package:firebase_storage/firebase_storage.dart'; // Import Firebase Storage
import 'package:cloud_functions/cloud_functions.dart'; // Import Cloud Functions

// Provider to stream pending opportunity submissions
final pendingOpportunitiesProvider = StreamProvider<List<ServiceSubmission>>((
  ref,
) {
  return FirebaseFirestore.instance
      .collection('serviceSubmissions')
      .where('status', isEqualTo: 'pending_review')
      .orderBy('submissionTimestamp', descending: true)
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.docs
                .map((doc) => ServiceSubmission.fromFirestore(doc))
                .toList(),
      );
});

class OpportunityVerificationPage extends ConsumerWidget {
  const OpportunityVerificationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingOpportunitiesAsync = ref.watch(pendingOpportunitiesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Verify Opportunities')),
      body: pendingOpportunitiesAsync.when(
        data: (submissions) {
          if (submissions.isEmpty) {
            return const Center(child: Text('No pending opportunities found.'));
          }
          return ListView.builder(
            itemCount: submissions.length,
            itemBuilder: (context, index) {
              final submission = submissions[index];
              return ListTile(
                title: Text(
                  submission.companyName ?? submission.responsibleName,
                ),
                subtitle: Text(
                  'NIF: ${submission.nif} \nReseller: ${submission.resellerName} \nSubmitted: ${DateFormat.yMd().add_jms().format(submission.submissionDate.toLocal())} \nStatus: ${submission.status}',
                ), // Using submissionDate getter
                isThreeLine: true,
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // Navigate to Detail View, passing the submission
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) =>
                              OpportunityDetailFormView(submission: submission),
                    ),
                  );
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, stack) =>
                Center(child: Text('Error loading submissions: $error')),
      ),
    );
  }
}

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

  @override
  Widget build(BuildContext context) {
    // Calculate potential Opportunity Name - moved initialization to initState

    return Scaffold(
      appBar: AppBar(title: Text('Opportunity: ${widget.submission.id}')),
      body: SingleChildScrollView(
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
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Oportunidade (Name) *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Opportunity Name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // NIF (From submission, editable, mandatory)
              TextFormField(
                controller: _nifController,
                decoration: const InputDecoration(
                  labelText: 'NIF (NIF__c) * (Mandatory for Account Link)',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'NIF is required';
                  }
                  // Optional: Add more specific NIF format validation
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Data de Criação (Auto-set based on view time)
              _buildReadOnlyField(
                'Data de Criação da Oportunidade',
                DateFormat.yMd().format(DateTime.now()), // Set to current date
              ),
              const SizedBox(height: 16),

              // Data da última actualização de Fase (Auto-set based on view time)
              _buildReadOnlyField(
                'Data da última actualização de Fase',
                DateFormat.yMd().format(DateTime.now()), // Set to current date
              ),
              const SizedBox(height: 16),

              // Fase (Fixed value - Display as read-only)
              _buildReadOnlyField('Fase (Fase__c)', _faseValue),
              const SizedBox(height: 16),

              // Tipo de Oportunidade (Derived value - Display as read-only)
              _buildReadOnlyField(
                'Tipo de Oportunidade (Tipo_de_Oportunidade__c)',
                _tipoOportunidadeValue ?? 'Not Determined',
              ),
              const SizedBox(height: 16),

              // Segmento de Cliente (Picklist - Required)
              DropdownButtonFormField<String>(
                value: _selectedSegmentoCliente, // Use state variable
                decoration: const InputDecoration(
                  labelText: 'Segmento de Cliente (Segmento_de_Cliente__c) *',
                  border: OutlineInputBorder(),
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
              const SizedBox(height: 16),

              // Solução (Picklist - Required)
              DropdownButtonFormField<String>(
                value: _selectedSolucao, // Use state variable
                decoration: const InputDecoration(
                  labelText: 'Solução (Solu_o__c) *',
                  border: OutlineInputBorder(),
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
              const SizedBox(height: 16),

              // Data de Previsão de Fecho (Date - Required)
              TextFormField(
                controller: _fechoController, // Use controller
                decoration: const InputDecoration(
                  labelText:
                      'Data de Previsão de Fecho (Data_de_Previs_o_de_Fecho__c) *',
                  hintText: 'YYYY-MM-DD',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today),
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
                    return 'Data de Previsão de Fecho is required';
                  }
                  // Optional: Validate date format if needed, though picker ensures it
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // --- Invoice ---
              const Divider(height: 32),
              Text('Invoice', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              widget.submission.invoicePhoto?.storagePath != null
                  ? TextButton.icon(
                    icon:
                        _isFetchingInvoiceUrl
                            ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.link),
                    label: const Text('View Submitted Invoice'),
                    onPressed:
                        _isFetchingInvoiceUrl
                            ? null
                            : () async {
                              final storagePath =
                                  widget.submission.invoicePhoto!.storagePath;
                              if (storagePath.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Invoice storage path is empty.',
                                    ),
                                  ),
                                );
                                return;
                              }

                              setState(() {
                                _isFetchingInvoiceUrl = true;
                              });

                              try {
                                if (kDebugMode) {
                                  print(
                                    "Attempting to get download URL for: $storagePath",
                                  );
                                }
                                // Get the actual download URL from Firebase Storage
                                final downloadUrl =
                                    await FirebaseStorage.instance
                                        .ref(storagePath)
                                        .getDownloadURL();

                                if (kDebugMode) {
                                  print("Obtained download URL: $downloadUrl");
                                }
                                // Launch the obtained URL
                                await _launchUrl(downloadUrl);
                              } on FirebaseException catch (e) {
                                if (kDebugMode) {
                                  print(
                                    "Firebase Error getting download URL: ${e.code} - ${e.message}",
                                  );
                                }
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Error accessing invoice file: ${e.message ?? e.code}',
                                      ),
                                      backgroundColor:
                                          Theme.of(context).colorScheme.error,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (kDebugMode) {
                                  print(
                                    "Generic Error getting download URL: $e",
                                  );
                                }
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Could not view invoice: $e',
                                      ),
                                      backgroundColor:
                                          Theme.of(context).colorScheme.error,
                                    ),
                                  );
                                }
                              } finally {
                                if (mounted) {
                                  setState(() {
                                    _isFetchingInvoiceUrl = false;
                                  });
                                }
                              }
                            },
                  )
                  : const Text('No invoice submitted.'),
              const SizedBox(height: 32),

              // --- Actions ---
              Center(
                child: ElevatedButton(
                  onPressed:
                      _isSubmitting
                          ? null
                          : () async {
                            // Disable button when submitting
                            // Validate the form
                            if (_formKey.currentState?.validate() ?? false) {
                              // --- Check if essential fetched data is available ---
                              if (_isLoadingReseller) {
                                ScaffoldMessenger.of(context).showSnackBar(
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
                                ScaffoldMessenger.of(context).showSnackBar(
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
                                'Data_de_Cria_o_da_Oportunidade__c': DateFormat(
                                  'yyyy-MM-dd',
                                ).format(DateTime.now()),
                                'Data_da_ltima_actualiza_o_de_Fase__c':
                                    DateFormat(
                                      'yyyy-MM-dd',
                                    ).format(DateTime.now()),
                                'Fase__c': _faseValue,
                                'tipoOportunidadeValue': _tipoOportunidadeValue,
                                'Segmento_de_Cliente__c':
                                    _selectedSegmentoCliente,
                                'agenteRetailSalesforceId':
                                    _resellerSalesforceId, // Send the ID
                                'Solu_o__c': _selectedSolucao,
                                'Data_de_Previs_o_de_Fecho__c':
                                    _fechoController.text,
                                // Include original submission ID and invoice path for the Cloud Function
                                'originalSubmissionId': widget.submission.id,
                                'invoiceStoragePath':
                                    widget.submission.invoicePhoto?.storagePath,
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
                                .httpsCallable('createSalesforceOpportunity');
                                final result = await callable
                                    .call<Map<String, dynamic>>(
                                      opportunityData,
                                    );
                                final resultData = result.data;

                                if (kDebugMode) {
                                  print("Cloud Function Result: $resultData");
                                }

                                if (resultData['success'] == true) {
                                  // Success!
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
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
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Failed to create opportunity: ${resultData['error'] ?? 'Unknown error'}',
                                        ),
                                        backgroundColor:
                                            Theme.of(context).colorScheme.error,
                                      ),
                                    );
                                  }
                                }
                              } on FirebaseFunctionsException catch (e) {
                                // Handle Cloud Functions specific errors (e.g., permission denied, not found)
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Cloud Function Error: (${e.code}) ${e.message}',
                                      ),
                                      backgroundColor:
                                          Theme.of(context).colorScheme.error,
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
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'An unexpected error occurred: $e',
                                      ),
                                      backgroundColor:
                                          Theme.of(context).colorScheme.error,
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
                              ScaffoldMessenger.of(context).showSnackBar(
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
                  child: const Text('Approve & Create Opportunity'),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // Helper for read-only fields
  Widget _buildReadOnlyField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
        child: Text(value, style: Theme.of(context).textTheme.bodyLarge),
      ),
    );
  }
}
