import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';

class SubmissionDetailPage extends StatefulWidget {
  final String submissionId;

  const SubmissionDetailPage({super.key, required this.submissionId});

  @override
  State<SubmissionDetailPage> createState() => _SubmissionDetailPageState();
}

class _SubmissionDetailPageState extends State<SubmissionDetailPage> {
  bool _isPreparingDocuments = false;
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _estimatedSavingsController =
      TextEditingController();

  // Temporary data for demonstration
  final Map<String, dynamic> _submissionData = {
    'id': 'S001',
    'clientName': 'ABC Company',
    'reseller': 'João Silva',
    'service': 'Energy',
    'serviceType': 'Commercial',
    'status': 'Pending Review',
    'submittedDate': '2024-03-20',
    'currentMonthlySpend': '€45,000',
    'documents': ['LastInvoice.pdf', 'ConsumptionHistory.pdf'],
    'clientInfo': {
      'nif': '123456789',
      'phone': '+351 912 345 678',
      'email': 'contact@abccompany.com',
      'address': 'Rua Principal, 123',
    },
  };

  @override
  void dispose() {
    _commentController.dispose();
    _estimatedSavingsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 48,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Client Submission Details', style: AppTextStyles.h3),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildClientInfo(),
            const SizedBox(height: 24),
            _buildSubmissionDocuments(),
            const SizedBox(height: 24),
            _buildReviewSection(),
            const SizedBox(height: 24),
            if (_submissionData['status'] == 'Approved')
              _buildDocumentPreparationSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final statusColor = _getStatusColor(_submissionData['status']);

    return Card(
      elevation: 0,
      color: Colors.grey[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(_submissionData['clientName'], style: AppTextStyles.h2),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _submissionData['status'],
                    style: TextStyle(
                      fontSize: 12,
                      color: statusColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildInfoItem('Reseller', _submissionData['reseller']),
                const SizedBox(width: 24),
                _buildInfoItem('Service', _submissionData['service']),
                const SizedBox(width: 24),
                _buildInfoItem('Type', _submissionData['serviceType']),
              ],
            ),
            const SizedBox(height: 8),
            _buildInfoItem(
              'Current Monthly Spend',
              _submissionData['currentMonthlySpend'],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: AppTextStyles.body2.copyWith(color: Colors.grey[600]),
        ),
        Text(value, style: AppTextStyles.body2),
      ],
    );
  }

  Widget _buildClientInfo() {
    return Card(
      elevation: 0,
      color: Colors.grey[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Client Information', style: AppTextStyles.h3),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem(
                    'NIF',
                    _submissionData['clientInfo']['nif'],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: _buildInfoItem(
                    'Phone',
                    _submissionData['clientInfo']['phone'],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem(
                    'Email',
                    _submissionData['clientInfo']['email'],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: _buildInfoItem(
                    'Address',
                    _submissionData['clientInfo']['address'],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmissionDocuments() {
    return Card(
      elevation: 0,
      color: Colors.grey[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Submitted Documents', style: AppTextStyles.h3),
            const SizedBox(height: 16),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _submissionData['documents'].length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final document = _submissionData['documents'][index];
                return Row(
                  children: [
                    Expanded(child: Text(document, style: AppTextStyles.body2)),
                    FilledButton.icon(
                      onPressed: () {
                        // TODO: Implement document view/download
                      },
                      icon: const Icon(Icons.visibility),
                      label: const Text('View'),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewSection() {
    return Card(
      elevation: 0,
      color: Colors.grey[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Review Submission', style: AppTextStyles.h3),
            const SizedBox(height: 16),
            TextField(
              controller: _estimatedSavingsController,
              decoration: InputDecoration(
                labelText: 'Estimated Monthly Savings',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixText: '€ ',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _commentController,
              decoration: InputDecoration(
                labelText: 'Review Comments',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _submissionData['status'] = 'Rejected';
                    });
                    // TODO: Implement rejection notification
                  },
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Reject Submission'),
                ),
                const SizedBox(width: 16),
                FilledButton(
                  onPressed: () {
                    setState(() {
                      _submissionData['status'] = 'Approved';
                    });
                    // TODO: Implement approval notification
                  },
                  child: const Text('Approve Submission'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentPreparationSection() {
    return Card(
      elevation: 0,
      color: Colors.grey[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Prepare Documents', style: AppTextStyles.h3),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildDocumentUpload(
                    'Proposal Document',
                    'Upload the proposal document (PDF)',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildDocumentUpload(
                    'Contract',
                    'Upload the contract document (PDF)',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed:
                    _isPreparingDocuments
                        ? null
                        : () {
                          setState(() {
                            _isPreparingDocuments = true;
                            _submissionData['status'] = 'Documents Sent';
                          });
                          // TODO: Implement document submission
                          // After submission is complete:
                          // setState(() => _isPreparingDocuments = false);
                        },
                child:
                    _isPreparingDocuments
                        ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                        : const Text('Send Documents to Reseller'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentUpload(String title, String description) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.body1.copyWith(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: AppTextStyles.body2.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () {
              // TODO: Implement document upload
            },
            icon: const Icon(Icons.upload_file),
            label: const Text('Choose File'),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending Review':
        return Colors.orange;
      case 'Approved':
        return Colors.green;
      case 'Rejected':
        return Colors.red;
      case 'Documents Sent':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}
