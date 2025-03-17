import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../../core/theme/theme.dart';
import '../../../presentation/screens/clients/client_details_page.dart';

class ClientsPage extends StatefulWidget {
  const ClientsPage({super.key});

  @override
  State<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends State<ClientsPage> {
  String? _selectedServiceType;
  String? _selectedStatus;
  bool _isFilterMenuOpen = false;

  // Temporary data for demonstration
  final List<Map<String, dynamic>> _clients = [
    {
      'name': 'João Silva',
      'type': 'residential',
      'service': 'Energy',
      'status': 'Ação Necessária',
    },
    {
      'name': 'Tech Solutions Lda',
      'type': 'commercial',
      'service': 'Insurance',
      'status': 'Pendente',
    },
    {
      'name': 'Maria Santos',
      'type': 'residential',
      'service': 'Telecommunications',
      'status': 'Concluído',
    },
    {
      'name': 'Green Energy Corp',
      'type': 'commercial',
      'service': 'Energy',
      'status': 'Ação Necessária',
    },
  ];

  int get actionNeededCount =>
      _clients.where((c) => c['status'] == 'Ação Necessária').length;
  int get pendingCount =>
      _clients.where((c) => c['status'] == 'Pendente').length;

  List<Map<String, dynamic>> get filteredClients {
    return _clients.where((client) {
      bool matchesService =
          _selectedServiceType == null ||
          client['service'] == _selectedServiceType;
      bool matchesStatus =
          _selectedStatus == null || client['status'] == _selectedStatus;
      return matchesService && matchesStatus;
    }).toList();
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    IconData? icon,
    int? count,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
            borderRadius: BorderRadius.circular(8),
        child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
                color:
                    selected
                        ? AppTheme.primary.withOpacity(0.15)
                        : Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color:
                      selected
                          ? AppTheme.primary.withOpacity(0.3)
                          : Colors.white.withOpacity(0.15),
                  width: 0.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(
                      icon,
                      size: 16,
                      color:
                          selected
                              ? AppTheme.primary
                              : AppTheme.foreground.withOpacity(0.7),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      color:
                          selected
                              ? AppTheme.primary
                              : AppTheme.foreground.withOpacity(0.7),
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                    ),
                  ),
                  if (count != null) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color:
                            selected
                                ? AppTheme.primary
                                : AppTheme.foreground.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
                        count.toString(),
            style: TextStyle(
                          color:
                              selected
                                  ? Colors.white
                                  : AppTheme.foreground.withOpacity(0.7),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          color: Colors.transparent,
          child: Column(
                children: [
              // Status Filters
              SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip(
                      label: 'Todos',
                      selected: _selectedStatus == null,
                      onTap: () => setState(() => _selectedStatus = null),
                    ),
                    const SizedBox(width: 6),
                    _buildFilterChip(
                      label: 'Ação Necessária',
                      selected: _selectedStatus == 'Ação Necessária',
                            onTap:
                          () => setState(
                                () =>
                                _selectedStatus =
                                    _selectedStatus == 'Ação Necessária'
                                        ? null
                                        : 'Ação Necessária',
                          ),
                      icon: Icons.warning_amber_rounded,
                      count: actionNeededCount,
                    ),
                    const SizedBox(width: 6),
                          _buildFilterChip(
                      label: 'Pendente',
                      selected: _selectedStatus == 'Pendente',
                            onTap:
                                () => setState(
                                  () =>
                                _selectedStatus =
                                    _selectedStatus == 'Pendente'
                                              ? null
                                        : 'Pendente',
                          ),
                      icon: Icons.pending_outlined,
                      count: pendingCount,
                    ),
                    const SizedBox(width: 6),
                          _buildFilterChip(
                      label: 'Concluído',
                      selected: _selectedStatus == 'Concluído',
                            onTap:
                                () => setState(
                                  () =>
                                _selectedStatus =
                                    _selectedStatus == 'Concluído'
                                              ? null
                                        : 'Concluído',
                          ),
                      icon: Icons.check_circle_outline,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Service Type Filter
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                            onTap:
                                () => setState(
                                () => _isFilterMenuOpen = !_isFilterMenuOpen,
                              ),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.15),
                                width: 0.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.filter_list,
                                  size: 16,
                                  color: AppTheme.foreground.withOpacity(0.7),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  _isFilterMenuOpen
                                      ? Icons.expand_less
                                      : Icons.expand_more,
                                  size: 16,
                                  color: AppTheme.foreground.withOpacity(0.7),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_selectedServiceType != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppTheme.primary.withOpacity(0.3),
                                width: 0.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getServiceIcon(_selectedServiceType!),
                                  size: 16,
                                  color: AppTheme.primary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _selectedServiceType!,
                                  style: TextStyle(
                                    color: AppTheme.primary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                InkWell(
                                  onTap:
                                      () => setState(
                                        () => _selectedServiceType = null,
                                      ),
                                  child: Icon(
                                    Icons.close,
                                    size: 14,
                                    color: AppTheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ),
                    ),
                  ),
                ],
              ),
              if (_isFilterMenuOpen)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.15),
                            width: 0.5,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFilterMenuItem(
                              'Energy',
                              'Energy',
                              Icons.bolt_outlined,
                            ),
                            _buildFilterMenuItem(
                              'Insurance',
                              'Insurance',
                              Icons.security_outlined,
                            ),
                            _buildFilterMenuItem(
                              'Telecommunications',
                              'Telecommunications',
                              Icons.phone_outlined,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
            ),
          ),
          Expanded(
            child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: filteredClients.length,
              itemBuilder: (context, index) {
                final client = filteredClients[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) =>
                                      ClientDetailsPage(clientData: client),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.15),
                              width: 0.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                      decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.15),
                                    width: 0.5,
                                  ),
                      ),
                      child: Icon(
                        client['type'] == 'residential'
                            ? Icons.person_outline
                            : Icons.business_outlined,
                                  size: 20,
                                  color: AppTheme.foreground.withOpacity(0.7),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                                    Text(
                                      client['name'],
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                        const SizedBox(height: 4),
                                    Text(
                                      client['service'],
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: AppTheme.foreground.withOpacity(
                                          0.7,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                                  vertical: 4,
                          ),
                          decoration: BoxDecoration(
                                  color: _getStatusColor(
                                    client['status'],
                                  ).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: _getStatusColor(
                                      client['status'],
                                    ).withOpacity(0.3),
                                    width: 0.5,
                                  ),
                          ),
                          child: Text(
                            client['status'],
                            style: TextStyle(
                              fontSize: 12,
                                    color: _getStatusColor(client['status']),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.chevron_right,
                                size: 20,
                                color: AppTheme.foreground.withOpacity(0.7),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  ),
                );
              },
            ),
          ),
        ],
    );
  }

  Widget _buildFilterMenuItem(String label, String? value, IconData icon) {
    bool isSelected = _selectedServiceType == value;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedServiceType = _selectedServiceType == value ? null : value;
            _isFilterMenuOpen = false;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(
                icon,
                size: 16,
                color:
                    isSelected
                        ? AppTheme.primary
                        : AppTheme.foreground.withOpacity(0.7),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color:
                      isSelected
                          ? AppTheme.primary
                          : AppTheme.foreground.withOpacity(0.7),
                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                ),
              ),
              if (isSelected) ...[
                const Spacer(),
                Icon(Icons.check, size: 16, color: AppTheme.primary),
              ],
            ],
          ),
        ),
      ),
    );
  }

  IconData _getServiceIcon(String service) {
    switch (service) {
      case 'Energy':
        return Icons.bolt_outlined;
      case 'Insurance':
        return Icons.security_outlined;
      case 'Telecommunications':
        return Icons.phone_outlined;
      default:
        return Icons.category_outlined;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Ação Necessária':
        return const Color(0xFFFF6B6B);
      case 'Pendente':
        return const Color(0xFFFFBE0B);
      case 'Concluído':
        return const Color(0xFF40C057);
      default:
        return AppTheme.foreground;
    }
  }
}
