import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/theme.dart';

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
    'name': 'Bernardo Ribeiro',
    'email': 'bernardo.ribeiro@mail.com',
    'phone': '+351 912 345 678', // Using a Portuguese phone format
    'registrationDate': 'Janeiro 2023',
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
      'clientName': 'Empresa A',
    },
    {
      'cycle': 'Cycle 1',
      'type': 'B2C',
      'cep': '98765-432',
      'amount': 1500.0,
      'clientName': 'João Silva',
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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const CircleAvatar(
            radius: 40,
            backgroundColor: Colors.white,
            child: Icon(Icons.person, size: 48, color: AppColors.primary),
          ),
          const SizedBox(height: 12),
          Text(
            _resellerData['name'],
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            _resellerData['email'],
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 4),
          Text(
            _resellerData['phone'],
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          _buildMembershipCard(),
        ],
      ),
    );
  }

  Widget _buildMembershipCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(20),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withAlpha(25), width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Membro desde',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.foreground.withAlpha(178),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _resellerData['registrationDate'],
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.foreground.withAlpha(230),
                ),
              ),
            ],
          ),
        ),
      ),
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
