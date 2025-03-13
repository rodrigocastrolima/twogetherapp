import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import 'submission_detail_page.dart';

class SubmissionsPage extends StatefulWidget {
  const SubmissionsPage({super.key});

  @override
  State<SubmissionsPage> createState() => _SubmissionsPageState();
}

class _SubmissionsPageState extends State<SubmissionsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedService = 'All';
  String _selectedStatus = 'All';

  // Temporary data for demonstration
  final List<Map<String, dynamic>> _submissions = [
    {
      'id': 'S001',
      'clientName': 'ABC Company',
      'reseller': 'João Silva',
      'service': 'Energy',
      'serviceType': 'Commercial',
      'status': 'Pending Review',
      'submittedDate': '2024-03-20',
      'currentMonthlySpend': '€45,000',
    },
    {
      'id': 'S002',
      'clientName': 'Restaurant XYZ',
      'reseller': 'Maria Santos',
      'service': 'Energy',
      'serviceType': 'Commercial',
      'status': 'Approved',
      'submittedDate': '2024-03-19',
      'currentMonthlySpend': '€12,000',
    },
    {
      'id': 'S003',
      'clientName': 'John Doe',
      'reseller': 'Ana Costa',
      'service': 'Gas',
      'serviceType': 'Residential',
      'status': 'Documents Sent',
      'submittedDate': '2024-03-18',
      'currentMonthlySpend': '€150',
    },
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Client Submissions', style: AppTextStyles.h1),
            const SizedBox(height: 8),
            Text(
              'Review and manage client submissions from resellers',
              style: AppTextStyles.body1.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            _buildFilters(),
            const SizedBox(height: 24),
            _buildSubmissionsTable(),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by client name or reseller',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onChanged: (value) {
              // TODO: Implement search
              setState(() {});
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: DropdownButtonFormField<String>(
            value: _selectedService,
            decoration: InputDecoration(
              labelText: 'Service',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            items:
                ['All', 'Energy', 'Gas']
                    .map(
                      (service) => DropdownMenuItem(
                        value: service,
                        child: Text(service),
                      ),
                    )
                    .toList(),
            onChanged: (value) {
              setState(() {
                _selectedService = value!;
              });
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: DropdownButtonFormField<String>(
            value: _selectedStatus,
            decoration: InputDecoration(
              labelText: 'Status',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            items:
                [
                      'All',
                      'Pending Review',
                      'Approved',
                      'Rejected',
                      'Documents Sent',
                    ]
                    .map(
                      (status) =>
                          DropdownMenuItem(value: status, child: Text(status)),
                    )
                    .toList(),
            onChanged: (value) {
              setState(() {
                _selectedStatus = value!;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSubmissionsTable() {
    return Expanded(
      child: Card(
        elevation: 0,
        child: SingleChildScrollView(
          child: DataTable(
            columnSpacing: 24,
            columns: const [
              DataColumn(label: Text('Client Name')),
              DataColumn(label: Text('Reseller')),
              DataColumn(label: Text('Service')),
              DataColumn(label: Text('Type')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Submitted')),
              DataColumn(label: Text('Monthly Spend')),
              DataColumn(label: Text('Actions')),
            ],
            rows:
                _submissions
                    .where((submission) {
                      final matchesSearch =
                          _searchController.text.isEmpty ||
                          submission['clientName'].toLowerCase().contains(
                            _searchController.text.toLowerCase(),
                          ) ||
                          submission['reseller'].toLowerCase().contains(
                            _searchController.text.toLowerCase(),
                          );

                      final matchesService =
                          _selectedService == 'All' ||
                          submission['service'] == _selectedService;

                      final matchesStatus =
                          _selectedStatus == 'All' ||
                          submission['status'] == _selectedStatus;

                      return matchesSearch && matchesService && matchesStatus;
                    })
                    .map(
                      (submission) => DataRow(
                        cells: [
                          DataCell(Text(submission['clientName'])),
                          DataCell(Text(submission['reseller'])),
                          DataCell(Text(submission['service'])),
                          DataCell(Text(submission['serviceType'])),
                          DataCell(_buildStatusBadge(submission['status'])),
                          DataCell(Text(submission['submittedDate'])),
                          DataCell(Text(submission['currentMonthlySpend'])),
                          DataCell(
                            FilledButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) => SubmissionDetailPage(
                                          submissionId: submission['id'],
                                        ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.visibility),
                              label: const Text('View'),
                            ),
                          ),
                        ],
                      ),
                    )
                    .toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final color = _getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w500,
        ),
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
