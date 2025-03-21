import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:ui';
import '../../../core/theme/theme.dart';
import '../../../core/utils/constants.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedUserType = 'All';
  String _searchQuery = '';

  final List<Map<String, dynamic>> _users = [
    {
      'id': '1',
      'name': 'Ana Silva',
      'email': 'ana.silva@example.com',
      'type': 'Reseller',
      'status': 'Active',
      'createdAt': '2023-12-15',
    },
    {
      'id': '2',
      'name': 'Carlos Lima',
      'email': 'carlos.lima@example.com',
      'type': 'Reseller',
      'status': 'Active',
      'createdAt': '2023-11-20',
    },
    {
      'id': '3',
      'name': 'Miguel Santos',
      'email': 'miguel.santos@example.com',
      'type': 'Admin',
      'status': 'Active',
      'createdAt': '2023-10-05',
    },
    {
      'id': '4',
      'name': 'Fernanda Costa',
      'email': 'fernanda.costa@example.com',
      'type': 'Reseller',
      'status': 'Inactive',
      'createdAt': '2023-09-12',
    },
    {
      'id': '5',
      'name': 'João Martins',
      'email': 'joao.martins@example.com',
      'type': 'Reseller',
      'status': 'Active',
      'createdAt': '2023-08-25',
    },
  ];

  List<Map<String, dynamic>> get filteredUsers {
    return _users.where((user) {
      final nameMatch = user['name'].toLowerCase().contains(
        _searchQuery.toLowerCase(),
      );
      final emailMatch = user['email'].toLowerCase().contains(
        _searchQuery.toLowerCase(),
      );
      final typeMatch =
          _selectedUserType == 'All' || user['type'] == _selectedUserType;
      return (nameMatch || emailMatch) && typeMatch;
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'User Management',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: AppTheme.foreground,
          ),
        ),
        const SizedBox(height: 24),
        _buildFilters(),
        const SizedBox(height: 24),
        _buildUserList(),
      ],
    );
  }

  Widget _buildFilters() {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(color: AppTheme.foreground),
                  decoration: InputDecoration(
                    hintText: 'Search users...',
                    hintStyle: TextStyle(
                      color: AppTheme.foreground.withOpacity(0.5),
                    ),
                    prefixIcon: Icon(
                      CupertinoIcons.search,
                      color: AppTheme.foreground.withOpacity(0.7),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 1,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedUserType,
                    dropdownColor: Colors.grey[800],
                    icon: Icon(
                      CupertinoIcons.chevron_down,
                      color: AppTheme.foreground.withOpacity(0.7),
                    ),
                    style: TextStyle(color: AppTheme.foreground, fontSize: 16),
                    isExpanded: true,
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedUserType = newValue!;
                      });
                    },
                    items:
                        <String>[
                          'All',
                          'Reseller',
                          'Admin',
                        ].map<DropdownMenuItem<String>>((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        ElevatedButton.icon(
          onPressed: () {
            // Add user logic
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Icons.add),
          label: const Text('Add User'),
        ),
      ],
    );
  }

  Widget _buildUserList() {
    return Expanded(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 0.5,
              ),
            ),
            child: Column(
              children: [
                // Table Header
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          'Name/Email',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.foreground,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          'Type',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.foreground,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          'Status',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.foreground,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          'Created',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.foreground,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          'Actions',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.foreground,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),

                Divider(color: Colors.white.withOpacity(0.1), height: 1),

                // Table Body
                Expanded(
                  child: ListView.builder(
                    itemCount: filteredUsers.length,
                    itemBuilder: (context, index) {
                      final user = filteredUsers[index];
                      return Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        user['name'],
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.foreground,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        user['email'],
                                        style: TextStyle(
                                          color: AppTheme.foreground
                                              .withOpacity(0.7),
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Text(
                                    user['type'],
                                    style: TextStyle(
                                      color:
                                          user['type'] == 'Admin'
                                              ? Colors.amber
                                              : AppTheme.foreground,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color:
                                              user['status'] == 'Active'
                                                  ? Colors.green
                                                  : Colors.red,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        user['status'],
                                        style: TextStyle(
                                          color: AppTheme.foreground,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Text(
                                    user['createdAt'],
                                    style: TextStyle(
                                      color: AppTheme.foreground,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          Icons.edit,
                                          color: AppTheme.foreground
                                              .withOpacity(0.7),
                                          size: 20,
                                        ),
                                        onPressed: () {
                                          // Edit user
                                        },
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          Icons.delete,
                                          color: Colors.red.withOpacity(0.7),
                                          size: 20,
                                        ),
                                        onPressed: () {
                                          // Delete user
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (index < filteredUsers.length - 1)
                            Divider(
                              color: Colors.white.withOpacity(0.1),
                              height: 1,
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
