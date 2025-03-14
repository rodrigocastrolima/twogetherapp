import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/colors.dart';

class ResellerProfilePage extends StatefulWidget {
  const ResellerProfilePage({super.key});

  @override
  State<ResellerProfilePage> createState() => _ResellerProfilePageState();
}

class _ResellerProfilePageState extends State<ResellerProfilePage> {
  String _selectedCycle = 'Cycle 1';
  String? _selectedCustomerType;
  String _cepFilter = '';
  final _cepController = TextEditingController();

  // Temporary data - Replace with actual data from backend
  final Map<String, dynamic> _resellerData = {
    'name': 'John Doe',
    'email': 'john.doe@example.com',
    'phone': '+55 11 99999-9999',
    'registrationDate': '01/01/2024',
    'totalClients': 15,
    'activeClients': 12,
  };

  final List<Map<String, dynamic>> _revenueCycles = [
    {'id': 'Cycle 1', 'startDate': '2024-03-01', 'endDate': '2024-03-15'},
    {'id': 'Cycle 2', 'startDate': '2024-02-15', 'endDate': '2024-02-29'},
    {'id': 'Cycle 3', 'startDate': '2024-02-01', 'endDate': '2024-02-14'},
  ];

  final List<Map<String, dynamic>> _revenueData = [
    {
      'cycle': 'Cycle 1',
      'type': 'B2B',
      'cep': '12345-678',
      'amount': 5000.0,
      'clientName': 'Company A',
    },
    {
      'cycle': 'Cycle 1',
      'type': 'B2C',
      'cep': '98765-432',
      'amount': 1500.0,
      'clientName': 'John Smith',
    },
    // Add more sample data as needed
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final l10n = AppLocalizations.of(context)!;
      setState(() {
        _selectedCustomerType = l10n.profileAll;
      });
    });
  }

  List<Map<String, dynamic>> get filteredRevenue {
    if (_selectedCustomerType == null) return [];

    return _revenueData.where((revenue) {
      bool matchesCycle = revenue['cycle'] == _selectedCycle;
      bool matchesType =
          _selectedCustomerType == AppLocalizations.of(context)!.profileAll ||
          revenue['type'] == _selectedCustomerType;
      bool matchesCep =
          _cepFilter.isEmpty || revenue['cep'].contains(_cepFilter);
      return matchesCycle && matchesType && matchesCep;
    }).toList();
  }

  double get totalRevenue {
    return filteredRevenue.fold(0, (sum, item) => sum + item['amount']);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProfileSection(),
              const SizedBox(height: 24),
              _buildRevenueDashboard(),
              const SizedBox(height: 24),
              _buildLogoutButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(26),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: AppColors.primary.withAlpha(26),
                child: Text(
                  _resellerData['name'].substring(0, 1),
                  style: TextStyle(
                    fontSize: 32,
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _resellerData['name'],
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _resellerData['email'],
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildProfileStats(),
        ],
      ),
    );
  }

  Widget _buildProfileStats() {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildStatItem(
          l10n.profileTotalClients,
          _resellerData['totalClients'].toString(),
        ),
        _buildStatItem(
          l10n.profileActiveClients,
          _resellerData['activeClients'].toString(),
        ),
        _buildStatItem(l10n.profileSince, _resellerData['registrationDate']),
      ],
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildRevenueDashboard() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(26),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.profileRevenueDashboard,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildFilters(),
          const SizedBox(height: 24),
          _buildTotalRevenue(),
          const SizedBox(height: 16),
          _buildRevenueList(),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    final l10n = AppLocalizations.of(context)!;
    final customerTypes = <String>[l10n.profileAll, 'B2B', 'B2C'];

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _selectedCycle,
                decoration: InputDecoration(
                  labelText: l10n.profileCycle,
                  border: const OutlineInputBorder(),
                ),
                items:
                    _revenueCycles.map((cycle) {
                      return DropdownMenuItem<String>(
                        value: cycle['id'] as String,
                        child: Text(cycle['id'] as String),
                      );
                    }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedCycle = value;
                    });
                  }
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _selectedCustomerType,
                decoration: InputDecoration(
                  labelText: l10n.profileCustomerType,
                  border: const OutlineInputBorder(),
                ),
                items:
                    customerTypes.map((type) {
                      return DropdownMenuItem<String>(
                        value: type,
                        child: Text(type),
                      );
                    }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCustomerType = value;
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _cepController,
          decoration: InputDecoration(
            labelText: l10n.profileFilterByCep,
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                setState(() {
                  _cepFilter = _cepController.text;
                });
              },
            ),
          ),
          onSubmitted: (value) {
            setState(() {
              _cepFilter = value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildTotalRevenue() {
    final l10n = AppLocalizations.of(context)!;
    final currencyFormat = NumberFormat.currency(
      locale: 'pt_BR',
      symbol: 'R\$',
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(26),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            l10n.profileTotalRevenue,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Text(
            currencyFormat.format(totalRevenue),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueList() {
    return Column(
      children:
          filteredRevenue.map((revenue) {
            final currencyFormat = NumberFormat.currency(
              locale: 'pt_BR',
              symbol: 'R\$',
            );
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.withAlpha(26)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          revenue['clientName'],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${revenue['type']} • ${revenue['cep']}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    currencyFormat.format(revenue['amount']),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            );
          }).toList(),
    );
  }

  Widget _buildLogoutButton() {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: TextButton.icon(
        onPressed: () {
          // Implement logout functionality
        },
        icon: const Icon(Icons.logout, color: Colors.grey, size: 20),
        label: Text(
          l10n.profileLogout,
          style: TextStyle(fontSize: 14, color: Colors.grey[700]),
        ),
      ),
    );
  }
}
