import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

// Moved from user_management_page.dart

/// Form for entering a Salesforce ID to initiate user creation.
typedef SalesforceSubmitCallback =
    void Function({required String salesforceId});

class SalesforceUserCreationForm extends ConsumerStatefulWidget {
  final SalesforceSubmitCallback onSubmit;
  final VoidCallback onCancel;
  final bool isLoading;

  const SalesforceUserCreationForm({
    required this.onSubmit,
    required this.onCancel,
    this.isLoading = false,
    super.key,
  });

  @override
  SalesforceUserCreationFormState createState() =>
      SalesforceUserCreationFormState();
}

class SalesforceUserCreationFormState
    extends ConsumerState<SalesforceUserCreationForm> {
  final _formKey = GlobalKey<FormState>();
  final _salesforceIdController = TextEditingController();

  @override
  void dispose() {
    _salesforceIdController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() == true) {
      if (kDebugMode) {
        print('Submitting Salesforce ID: ${_salesforceIdController.text}');
      }
      widget.onSubmit(salesforceId: _salesforceIdController.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _salesforceIdController,
            decoration: const InputDecoration(
              labelText: 'Salesforce User ID',
              hintText: 'Enter the 18-character Salesforce ID',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a Salesforce User ID';
              }
              if (value.trim().length != 18) {
                return 'Salesforce ID must be 18 characters long';
              }
              // Optional: Add regex check for valid characters
              return null;
            },
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: widget.isLoading ? null : widget.onCancel,
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                icon:
                    widget.isLoading
                        ? Container(
                          width: 16,
                          height: 16,
                          margin: const EdgeInsets.only(right: 8),
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                        : const Icon(Icons.verified_user, size: 16),
                label: Text(
                  widget.isLoading ? 'Verifying...' : 'Verify & Create User',
                ),
                onPressed: widget.isLoading ? null : _submit,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
