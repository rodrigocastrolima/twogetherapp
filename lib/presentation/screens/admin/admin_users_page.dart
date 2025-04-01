import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/ui_styles.dart';
import '../../../core/theme/theme.dart';
import '../../widgets/user_profile_dialog.dart';

class AdminUsersPage extends ConsumerStatefulWidget {
  const AdminUsersPage({super.key});

  @override
  ConsumerState<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends ConsumerState<AdminUsersPage> {
  final searchController = TextEditingController();
  String filterRole = 'all';
  String searchQuery = '';
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Manage Users',
          style: AppTextStyles.h3.copyWith(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
          clipBehavior: Clip.antiAlias,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: BackdropFilter(
            filter: AppStyles.standardBlur,
            child: Container(
              decoration: AppStyles.glassCard(context),
              child: Column(
                children: [_buildFilters(), Expanded(child: _buildUsersList())],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 48,
                  decoration: AppStyles.inputContainer(context),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: searchController,
                    onChanged: (value) {
                      setState(() {
                        searchQuery = value.trim();
                      });
                    },
                    style: AppTextStyles.body2.copyWith(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search users...',
                      hintStyle: AppTextStyles.body2.copyWith(
                        color: AppColors.whiteAlpha50,
                      ),
                      border: InputBorder.none,
                      prefixIcon: Icon(
                        CupertinoIcons.search,
                        color: AppColors.whiteAlpha70,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: AppStyles.inputContainer(context),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: filterRole,
                    dropdownColor: AppColors.blackAlpha70,
                    style: AppTextStyles.body2.copyWith(color: Colors.white),
                    icon: Icon(
                      CupertinoIcons.chevron_down,
                      size: 16,
                      color: AppColors.whiteAlpha70,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    items: [
                      DropdownMenuItem(
                        value: 'all',
                        child: Text(
                          'All Roles',
                          style: AppTextStyles.body2.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'reseller',
                        child: Text(
                          'Resellers',
                          style: AppTextStyles.body2.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'admin',
                        child: Text(
                          'Admins',
                          style: AppTextStyles.body2.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          filterRole = value;
                        });
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              // Show add user dialog
              _showAddUserDialog();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.amber,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(CupertinoIcons.person_add),
                const SizedBox(width: 8),
                Text(
                  'Add User',
                  style: AppTextStyles.button.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsersList() {
    // Create query based on filters
    Query query = firestore.collection('users');

    if (filterRole != 'all') {
      query = query.where('role', isEqualTo: filterRole);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    CupertinoIcons.exclamationmark_triangle_fill,
                    size: 48,
                    color: Colors.amber,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading users',
                    style: AppTextStyles.body1.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body2.copyWith(
                      color: AppColors.whiteAlpha70,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  CupertinoIcons.person_3_fill,
                  size: 48,
                  color: AppColors.whiteAlpha50,
                ),
                const SizedBox(height: 16),
                Text(
                  'No users found',
                  style: AppTextStyles.body1.copyWith(
                    color: AppColors.whiteAlpha70,
                  ),
                ),
              ],
            ),
          );
        }

        // Filter users if search query is not empty
        var filteredDocs = snapshot.data!.docs;
        if (searchQuery.isNotEmpty) {
          filteredDocs =
              filteredDocs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final name = data['displayName'] as String? ?? '';
                final email = data['email'] as String? ?? '';
                return name.toLowerCase().contains(searchQuery.toLowerCase()) ||
                    email.toLowerCase().contains(searchQuery.toLowerCase());
              }).toList();

          // If no matches, show "No matching users"
          if (filteredDocs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    CupertinoIcons.search,
                    size: 48,
                    color: AppColors.whiteAlpha50,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No matching users found',
                    style: AppTextStyles.body1.copyWith(
                      color: AppColors.whiteAlpha70,
                    ),
                  ),
                ],
              ),
            );
          }
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) {
            final userData = filteredDocs[index].data() as Map<String, dynamic>;
            final userId = filteredDocs[index].id;
            final displayName = userData['displayName'] as String? ?? 'No Name';
            final email = userData['email'] as String? ?? 'No Email';
            final role = userData['role'] as String? ?? 'Unknown';
            final isActive = userData['isActive'] as bool? ?? false;

            return _buildUserItem(
              userId: userId,
              displayName: displayName,
              email: email,
              role: role,
              isActive: isActive,
            );
          },
        );
      },
    );
  }

  Widget _buildUserItem({
    required String userId,
    required String displayName,
    required String email,
    required String role,
    required bool isActive,
  }) {
    // Icon based on role
    IconData roleIcon = CupertinoIcons.person;
    Color roleColor = AppColors.whiteAlpha70;

    if (role == 'admin') {
      roleIcon = CupertinoIcons.shield_fill;
      roleColor = AppColors.amber;
    } else if (role == 'reseller') {
      roleIcon = CupertinoIcons.person_badge_plus_fill;
      roleColor = AppTheme.primary;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AppStyles.glassCardWithHighlight(
        isHighlighted: isActive,
        context: context,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                // Show user profile dialog
                showDialog(
                  context: context,
                  builder:
                      (context) => UserProfileDialog(
                        userId: userId,
                        currentRole: role,
                        isCurrentlyActive: isActive,
                      ),
                );
              },
              borderRadius: BorderRadius.circular(16),
              splashColor: AppColors.whiteAlpha10,
              highlightColor: AppColors.whiteAlpha10,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Role icon
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: roleColor.withAlpha(38),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: roleColor.withAlpha(77),
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Icon(roleIcon, size: 24, color: roleColor),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // User info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  displayName,
                                  style: AppTextStyles.body1.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  color:
                                      isActive
                                          ? Colors.green.shade900.withAlpha(204)
                                          : Colors.red.shade900.withAlpha(204),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color:
                                        isActive
                                            ? Colors.green.shade300
                                            : Colors.red.shade300,
                                    width: 0.5,
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                child: Text(
                                  isActive ? 'Active' : 'Inactive',
                                  style: AppTextStyles.caption.copyWith(
                                    color:
                                        isActive
                                            ? Colors.green.shade300
                                            : Colors.red.shade300,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            email,
                            style: AppTextStyles.body2.copyWith(
                              color: AppColors.whiteAlpha70,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: _getRoleBackgroundColor(role),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                child: Text(
                                  role.capitalize(),
                                  style: AppTextStyles.caption.copyWith(
                                    color: _getRoleTextColor(role),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Edit icon
                    IconButton(
                      icon: Icon(
                        CupertinoIcons.ellipsis_vertical,
                        color: AppColors.whiteAlpha70,
                      ),
                      onPressed: () {
                        _showUserOptions(userId, role, isActive);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getRoleBackgroundColor(String role) {
    switch (role) {
      case 'admin':
        return Colors.amber.withAlpha(77);
      case 'reseller':
        return AppTheme.primary.withAlpha(77);
      default:
        return Colors.grey.withAlpha(77);
    }
  }

  Color _getRoleTextColor(String role) {
    switch (role) {
      case 'admin':
        return Colors.amber;
      case 'reseller':
        return AppTheme.primary;
      default:
        return Colors.grey;
    }
  }

  void _showUserOptions(String userId, String currentRole, bool isActive) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.blackAlpha70,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: BackdropFilter(
            filter: AppStyles.standardBlur,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 24,
                  horizontal: 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'User Options',
                      style: AppTextStyles.h4.copyWith(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ListTile(
                      leading: Icon(
                        CupertinoIcons.person_crop_circle_badge_exclam,
                        color: AppColors.whiteAlpha70,
                      ),
                      title: Text(
                        'View Full Profile',
                        style: AppTextStyles.body1.copyWith(
                          color: Colors.white,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        showDialog(
                          context: context,
                          builder:
                              (context) => UserProfileDialog(
                                userId: userId,
                                currentRole: currentRole,
                                isCurrentlyActive: isActive,
                              ),
                        );
                      },
                    ),
                    ListTile(
                      leading: Icon(
                        isActive
                            ? CupertinoIcons.person_badge_minus
                            : CupertinoIcons.person_badge_plus,
                        color:
                            isActive
                                ? Colors.red.shade300
                                : Colors.green.shade300,
                      ),
                      title: Text(
                        isActive ? 'Deactivate User' : 'Activate User',
                        style: AppTextStyles.body1.copyWith(
                          color:
                              isActive
                                  ? Colors.red.shade300
                                  : Colors.green.shade300,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _toggleUserActiveStatus(userId, isActive);
                      },
                    ),
                    if (currentRole != 'admin') ...[
                      ListTile(
                        leading: Icon(
                          CupertinoIcons.shield_fill,
                          color: AppColors.amber,
                        ),
                        title: Text(
                          'Make Admin',
                          style: AppTextStyles.body1.copyWith(
                            color: AppColors.amber,
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          _updateUserRole(userId, 'admin');
                        },
                      ),
                    ],
                    if (currentRole != 'reseller') ...[
                      ListTile(
                        leading: Icon(
                          CupertinoIcons.person_badge_plus_fill,
                          color: AppTheme.primary,
                        ),
                        title: Text(
                          'Make Reseller',
                          style: AppTextStyles.body1.copyWith(
                            color: AppTheme.primary,
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          _updateUserRole(userId, 'reseller');
                        },
                      ),
                    ],
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.blackAlpha30,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: AppTextStyles.button.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _updateUserRole(String userId, String newRole) async {
    try {
      await firestore.collection('users').doc(userId).update({'role': newRole});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User role updated to $newRole'),
            backgroundColor: Colors.green.withAlpha(204),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating user role: ${e.toString()}'),
            backgroundColor: AppTheme.destructive.withAlpha(204),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  void _toggleUserActiveStatus(String userId, bool currentStatus) async {
    try {
      await firestore.collection('users').doc(userId).update({
        'isActive': !currentStatus,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              currentStatus
                  ? 'User has been deactivated'
                  : 'User has been activated',
            ),
            backgroundColor: Colors.green.withAlpha(204),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating user status: ${e.toString()}'),
            backgroundColor: AppTheme.destructive.withAlpha(204),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  void _showAddUserDialog() {
    showDialog(
      context: context,
      builder: (context) => UserProfileDialog(isNewUser: true),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
