import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../features/auth/domain/models/app_user.dart';

class UserListItem extends StatelessWidget {
  final AppUser user;
  final Function(String, bool) onToggleEnabled;
  final Function(String) onResetPassword;

  const UserListItem({
    super.key,
    required this.user,
    required this.onToggleEnabled,
    required this.onResetPassword,
  });

  Color _getRoleColor() {
    switch (user.role) {
      case UserRole.admin:
        return Colors.red.shade300;
      case UserRole.reseller:
        return Colors.blue.shade300;
      default:
        return Colors.grey;
    }
  }

  String _getRoleText() {
    switch (user.role) {
      case UserRole.admin:
        return 'Administrator';
      case UserRole.reseller:
        return 'Reseller';
      default:
        return 'Unknown';
    }
  }

  bool get _isEnabled => user.additionalData?['isEnabled'] as bool? ?? true;
  bool get _isFirstLogin => user.isFirstLogin;
  bool get _isEmailVerified => user.isEmailVerified;
  DateTime? get _lastSignInTime =>
      user.additionalData?['lastSignInTime'] != null
          ? (user.additionalData!['lastSignInTime'] as Timestamp).toDate()
          : null;
  DateTime? get _creationTime =>
      user.additionalData?['creationTime'] != null
          ? (user.additionalData!['creationTime'] as Timestamp).toDate()
          : null;

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    // Use relative time for recent dates
    final difference = DateTime.now().difference(date);
    if (difference.inDays < 1) {
      if (difference.inHours < 1) {
        if (difference.inMinutes < 1) {
          return 'Just now';
        }
        return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
      }
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else {
      return DateFormat('MMM d, yyyy').format(date);
    }
  }

  void _showResetPasswordConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Reset Password'),
            content: Text(
              'Are you sure you want to send a password reset email to ${user.email}?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('CANCEL'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  onResetPassword(user.email);
                },
                child: const Text('SEND RESET EMAIL'),
              ),
            ],
          ),
    );
  }

  void _showToggleUserConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(_isEnabled ? 'Disable User' : 'Enable User'),
            content: Text(
              _isEnabled
                  ? 'Are you sure you want to disable ${user.displayName ?? user.email}? They will no longer be able to sign in.'
                  : 'Are you sure you want to enable ${user.displayName ?? user.email}? They will be able to sign in again.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('CANCEL'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  onToggleEnabled(user.uid, !_isEnabled);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: _isEnabled ? Colors.red : Colors.green,
                ),
                child: Text(_isEnabled ? 'DISABLE' : 'ENABLE'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                // User Avatar
                Hero(
                  tag: 'user-avatar-${user.uid}',
                  child: CircleAvatar(
                    backgroundColor: _getRoleColor(),
                    radius: 24,
                    child: Text(
                      user.displayName?.isNotEmpty == true
                          ? user.displayName![0].toUpperCase()
                          : user.email.isNotEmpty
                          ? user.email[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // User Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName ?? user.email,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (user.displayName != null)
                        Text(
                          user.email,
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 14,
                          ),
                        ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          Chip(
                            label: Text(_getRoleText()),
                            backgroundColor: _getRoleColor().withOpacity(0.2),
                            labelStyle: TextStyle(
                              color: _getRoleColor(),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                            padding: EdgeInsets.zero,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ),
                          Chip(
                            label: Text(_isEnabled ? 'Active' : 'Disabled'),
                            backgroundColor:
                                _isEnabled
                                    ? Colors.green.withOpacity(0.2)
                                    : Colors.red.withOpacity(0.2),
                            labelStyle: TextStyle(
                              color: _isEnabled ? Colors.green : Colors.red,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                            padding: EdgeInsets.zero,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ),
                          if (_isFirstLogin)
                            Chip(
                              label: const Text('First Login'),
                              backgroundColor: Colors.orange.withOpacity(0.2),
                              labelStyle: TextStyle(
                                color: Colors.orange.shade800,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                              padding: EdgeInsets.zero,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                          Chip(
                            label: Text(
                              _isEmailVerified ? 'Verified' : 'Unverified',
                            ),
                            backgroundColor:
                                _isEmailVerified
                                    ? Colors.teal.withOpacity(0.2)
                                    : Colors.grey.withOpacity(0.2),
                            labelStyle: TextStyle(
                              color:
                                  _isEmailVerified
                                      ? Colors.teal
                                      : Colors.grey.shade700,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                            padding: EdgeInsets.zero,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Action Buttons
                Column(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.key),
                      tooltip: 'Reset Password',
                      onPressed: () => _showResetPasswordConfirmation(context),
                    ),
                    IconButton(
                      icon: Icon(_isEnabled ? Icons.block : Icons.check_circle),
                      tooltip: _isEnabled ? 'Disable User' : 'Enable User',
                      color: _isEnabled ? Colors.red : Colors.green,
                      onPressed: () => _showToggleUserConfirmation(context),
                    ),
                  ],
                ),
              ],
            ),
            // User activity info
            if (_creationTime != null || _lastSignInTime != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_creationTime != null)
                      Flexible(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              const TextSpan(
                                text: 'Created: ',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                              TextSpan(
                                text: _formatDate(_creationTime),
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (_lastSignInTime != null)
                      Flexible(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              const TextSpan(
                                text: 'Last login: ',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                              TextSpan(
                                text: _formatDate(_lastSignInTime),
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
