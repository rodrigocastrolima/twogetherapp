import 'package:flutter/material.dart';

class SalesforceUserCreationForm extends StatefulWidget {
  final Function({required String salesforceId}) onSubmit;
  final VoidCallback onCancel;
  final bool isLoading;

  const SalesforceUserCreationForm({
    super.key,
    required this.onSubmit,
    required this.onCancel,
    this.isLoading = false,
  });

  @override
  State<SalesforceUserCreationForm> createState() =>
      _SalesforceUserCreationFormState();
}

class _SalesforceUserCreationFormState
    extends State<SalesforceUserCreationForm> {
  final _formKey = GlobalKey<FormState>();
  final _salesforceIdController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _salesforceIdController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(SalesforceUserCreationForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update local state based on parent widget
    if (widget.isLoading != _isSubmitting) {
      setState(() {
        _isSubmitting = widget.isLoading;
      });
    }
  }

  void _handleSubmit() {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    widget.onSubmit(salesforceId: _salesforceIdController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _salesforceIdController,
            decoration: const InputDecoration(
              labelText: 'Salesforce ID',
              hintText: 'Enter a valid Salesforce User ID',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.sync_alt),
              helperText: 'System will fetch user data from Salesforce',
              helperMaxLines: 2,
            ),
            autofocus: true,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Salesforce ID is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          const Text(
            'The system will fetch user information from Salesforce and create an account automatically. '
            'Email, name, and other information will be populated from Salesforce data.',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _isSubmitting ? null : widget.onCancel,
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                icon:
                    _isSubmitting
                        ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                        : const Icon(Icons.search),
                label: const Text('Verify User'),
                onPressed: _isSubmitting ? null : _handleSubmit,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
