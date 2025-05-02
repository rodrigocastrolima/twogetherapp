import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'dart:ui';
import '../../../../features/auth/domain/models/app_user.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../providers/user_creation_provider.dart';

/// Extension on AppUser to safely access Salesforce-related fields
extension SalesforceUserExtension on AppUser {
  String? get salesforceId => additionalData['salesforceId'] as String?;
}

class UserManagementPage extends ConsumerStatefulWidget {
  const UserManagementPage({super.key});

  @override
  UserManagementPageState createState() => UserManagementPageState();
}

class UserManagementPageState extends ConsumerState<UserManagementPage> {
  bool _isLoading = true;
  List<AppUser> _users = [];
  String? _errorMessage;
  late final String _currentUserId;
  TextEditingController searchController = TextEditingController();
  String searchQuery = '';
  bool _isDialogShowing = false;

  bool _isCreatingUserMode = false;
  final _createUserFormKey = GlobalKey<FormState>();
  final _salesforceIdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    _loadUsers();
  }

  @override
  void dispose() {
    _salesforceIdController.dispose();
    searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    Future.delayed(const Duration(seconds: 15), () {
      if (mounted && _isLoading) {
        if (kDebugMode) {
          print('Loading users timed out');
        }
        setState(() {
          _isLoading = false;
          _errorMessage =
              'O carregamento excedeu o tempo limite. Por favor, tente novamente.';
        });
      }
    });

    try {
      if (kDebugMode) {
        print('Loading users');
      }
      final authRepository = ref.read(authRepositoryProvider);
      final resellers = await authRepository.getAllResellers();
      final adminUsers =
          await FirebaseFirestore.instance
              .collection('users')
              .where('role', isEqualTo: 'admin')
              .get();
      final admins =
          adminUsers.docs.map((doc) {
            final data = doc.data();
            return AppUser(
              uid: doc.id,
              email: data['email'] as String? ?? '',
              role: UserRole.admin,
              displayName: data['displayName'] as String?,
              photoURL: data['photoURL'] as String?,
              isFirstLogin: data['isFirstLogin'] as bool? ?? false,
              isEmailVerified: data['isEmailVerified'] as bool? ?? false,
              additionalData: data,
            );
          }).toList();
      if (mounted) {
        final allUsers = [...admins, ...resellers];
        _users = allUsers.where((user) => user.uid != _currentUserId).toList();
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading users: $e');
      }
      if (mounted) {
        setState(() {
          _errorMessage = 'Falha ao carregar utilizadores: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _setUserEnabled(String uid, bool enabled) async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final authRepository = ref.read(authRepositoryProvider);
      await authRepository.setUserEnabled(uid, enabled);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enabled ? 'Utilizador Ativado' : 'Utilizador Desativado',
          ),
          backgroundColor: Theme.of(context).colorScheme.secondary,
        ),
      );

      if (!mounted) return;
      await _loadUsers();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'Falha ao atualizar estado do utilizador: ${e.toString()}';
        _isLoading = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro: ${e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _resetPassword(String uid, String email) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final theme = Theme.of(context);

    try {
      final authRepository = ref.read(authRepositoryProvider);
      await authRepository.sendPasswordResetEmail(email);

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Email de redefinição de senha enviado'),
          backgroundColor: theme.colorScheme.secondary,
        ),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Erro: ${e.toString()}'),
          backgroundColor: theme.colorScheme.error,
        ),
      );
    }
  }

  Future<void> _deleteUser(String uid) async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final authRepository = ref.read(authRepositoryProvider);
      await authRepository.deleteUser(uid);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Utilizador eliminado'),
          backgroundColor: Theme.of(context).colorScheme.secondary,
        ),
      );

      if (!mounted) return;
      await _loadUsers();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Falha ao eliminar utilizador: ${e.toString()}';
        _isLoading = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro: ${e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'N/D';

    DateTime date;
    if (timestamp is Timestamp) {
      date = timestamp.toDate();
    } else {
      return 'N/D';
    }

    return DateFormat('dd/MM/yyyy HH:mm', 'pt_PT').format(date);
  }

  void _showUserActionMenu(BuildContext context, AppUser user) {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder:
          (context) => BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: AlertDialog(
              backgroundColor: theme.colorScheme.surface.withAlpha(
                (255 * 0.9).round(),
              ),
              title: Text(
                'Mais: ${user.displayName ?? user.email}',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(
                    (255 * 0.7).round(),
                  ),
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: Icon(
                      Icons.password,
                      color: theme.colorScheme.primary,
                    ),
                    title: Text(
                      'Redefinir Senha',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurface.withAlpha(
                          (255 * 0.7).round(),
                        ),
                      ),
                    ),
                    onTap: () {
                      Navigator.of(context).pop();
                      _resetPassword(user.uid, user.email);
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      user.additionalData['isEnabled'] == false
                          ? Icons.check_circle
                          : Icons.block,
                      color:
                          user.additionalData['isEnabled'] == false
                              ? theme.colorScheme.tertiary
                              : theme.colorScheme.error,
                    ),
                    title: Text(
                      user.additionalData['isEnabled'] == false
                          ? 'Ativar'
                          : 'Desativar',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurface.withAlpha(
                          (255 * 0.7).round(),
                        ),
                      ),
                    ),
                    onTap: () {
                      Navigator.of(context).pop();
                      _setUserEnabled(
                        user.uid,
                        !(user.additionalData['isEnabled'] ?? true),
                      );
                    },
                  ),
                  Divider(
                    color: theme.colorScheme.onSurface.withAlpha(
                      (255 * 0.2).round(),
                    ),
                  ),
                  ListTile(
                    leading: Icon(Icons.delete, color: theme.colorScheme.error),
                    title: Text(
                      'Eliminar',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                    onTap: () {
                      Navigator.of(context).pop();
                      _showDeleteConfirmation(context, user);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.onSurface.withAlpha(
                      (255 * 0.7).round(),
                    ),
                  ),
                  child: Text('Cancelar'),
                ),
              ],
            ),
          ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, AppUser user) {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder:
          (context) => BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: AlertDialog(
              backgroundColor: theme.colorScheme.surface.withAlpha(
                (255 * 0.9).round(),
              ),
              title: Text(
                'Eliminar Utilizador',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(
                    (255 * 0.7).round(),
                  ),
                ),
              ),
              content: Text(
                'Tem certeza que deseja eliminar permanentemente ${user.displayName ?? user.email}? Esta ação não pode ser desfeita.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(
                    (255 * 0.7).round(),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.onSurface.withAlpha(
                      (255 * 0.7).round(),
                    ),
                  ),
                  child: Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _deleteUser(user.uid);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.error,
                  ),
                  child: Text('Eliminar'),
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildUserTable() {
    final filteredUsers =
        searchQuery.isEmpty
            ? _users
            : _users.where((user) {
              final name = user.displayName?.toLowerCase() ?? '';
              final email = user.email.toLowerCase();
              final query = searchQuery.toLowerCase();
              return name.contains(query) || email.contains(query);
            }).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 700;
        final theme = Theme.of(context);

        if (isSmallScreen) {
          return filteredUsers.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.search_off,
                      size: 64,
                      color: theme.colorScheme.onSurface.withAlpha(
                        (255 * 0.5).round(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Nenhum utilizador encontrado',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.onSurface.withAlpha(
                          (255 * 0.7).round(),
                        ),
                      ),
                    ),
                  ],
                ),
              )
              : ListView.builder(
                itemCount: filteredUsers.length,
                padding: const EdgeInsets.only(bottom: 16),
                itemBuilder: (context, index) {
                  final user = filteredUsers[index];
                  final bool isEnabled =
                      user.additionalData['isEnabled'] ?? true;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    color: theme.colorScheme.surface.withAlpha(
                      (255 * 0.2).round(),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: theme.colorScheme.onSurface.withAlpha(
                          (255 * 0.1).round(),
                        ),
                        width: 0.5,
                      ),
                    ),
                    child: InkWell(
                      onTap: () => _navigateToUserDetailPage(user),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor:
                                      user.role == UserRole.admin
                                          ? theme.colorScheme.secondary
                                              .withAlpha((255 * 0.1).round())
                                          : theme.colorScheme.primary.withAlpha(
                                            (255 * 0.1).round(),
                                          ),
                                  child: Text(
                                    (user.displayName?.isNotEmpty == true
                                            ? user.displayName![0]
                                            : user.email[0])
                                        .toUpperCase(),
                                    style: TextStyle(
                                      color:
                                          user.role == UserRole.admin
                                              ? theme.colorScheme.secondary
                                              : theme.colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    user.displayName ?? user.email,
                                    style: theme.textTheme.titleMedium,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.more_vert),
                                  onPressed:
                                      () => _showUserActionMenu(context, user),
                                  tooltip: 'Mais',
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Role: ${user.role.name.capitalize()}'),
                                Text(
                                  isEnabled ? 'Ativo' : 'Inativo',
                                  style: TextStyle(
                                    color:
                                        isEnabled ? Colors.green : Colors.red,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Último Login: ${_formatDate(user.additionalData['lastLoginAt'] ?? 'N/A')}',
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
        } else {
          return SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                showCheckboxColumn: false,
                columnSpacing: 20,
                headingRowColor: MaterialStateProperty.resolveWith<Color?>((
                  Set<MaterialState> states,
                ) {
                  return theme.colorScheme.surfaceVariant.withAlpha(
                    (255 * 0.5).round(),
                  );
                }),
                border: TableBorder.all(
                  color: theme.dividerColor.withAlpha((255 * 0.1).round()),
                  width: 1,
                  borderRadius: BorderRadius.circular(8),
                ),
                columns: [
                  const DataColumn(label: Text('Nome')),
                  const DataColumn(label: Text('Email')),
                  const DataColumn(label: Text('Role')),
                  const DataColumn(label: Text('Último Login')),
                  const DataColumn(label: Text('Salesforce ID')),
                  const DataColumn(label: Text('Estado')),
                  const DataColumn(label: Text('Ações')),
                ],
                rows:
                    filteredUsers.map((user) {
                      final bool isEnabled =
                          user.additionalData['isEnabled'] ?? true;
                      return DataRow(
                        onSelectChanged: (selected) {
                          if (selected ?? false) {
                            _navigateToUserDetailPage(user);
                          }
                        },
                        cells: [
                          DataCell(Text(user.displayName ?? '-')),
                          DataCell(Text(user.email)),
                          DataCell(Text(user.role.name.capitalize())),
                          DataCell(
                            Text(
                              _formatDate(
                                user.additionalData['lastLoginAt'] ?? 'N/A',
                              ),
                            ),
                          ),
                          DataCell(Text(user.salesforceId ?? 'N/A')),
                          DataCell(
                            Text(
                              isEnabled ? 'Ativo' : 'Inativo',
                              style: TextStyle(
                                color: isEnabled ? Colors.green : Colors.red,
                              ),
                            ),
                          ),
                          DataCell(
                            IconButton(
                              icon: const Icon(Icons.more_vert),
                              onPressed:
                                  () => _showUserActionMenu(context, user),
                              tooltip: 'Mais',
                            ),
                          ),
                        ],
                      );
                    }).toList(),
              ),
            ),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    ref.listen<UserCreationState>(userCreationProvider, (previous, next) {
      if (kDebugMode) {
        print("--- UserManagementPage Listener Triggered ---");
        print("  Current _isDialogShowing: $_isDialogShowing");
        print("  Previous State: ${previous?.toString()}");
        print("  Next State    : ${next.toString()}");
      }

      bool shouldProceed = true;
      if (_isDialogShowing &&
          (next.showVerificationDialog ||
              next.showSuccessDialog ||
              next.showErrorDialog)) {
        if (kDebugMode) {
          print(
            "  Listener SKIPPING: Dialog already showing and new dialog requested.",
          );
        }
        shouldProceed = false;
      }

      if (!next.showVerificationDialog &&
          !next.showSuccessDialog &&
          !next.showErrorDialog &&
          _isDialogShowing) {
        if (kDebugMode) {
          print(
            "  Listener Action: Resetting _isDialogShowing flag because no dialogs are active in next state.",
          );
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() => _isDialogShowing = false);
          }
        });
        shouldProceed = false;
      }

      if (shouldProceed && mounted) {
        if (next.showVerificationDialog && next.verificationData != null) {
          if (kDebugMode)
            print("  Listener Condition MET: showVerificationDialog");
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              if (!_isDialogShowing) {
                setState(() => _isDialogShowing = true);
                try {
                  if (kDebugMode)
                    print(
                      "  Listener Action: Calling _showVerificationDialogFromState",
                    );
                  _showVerificationDialogFromState(
                    next.verificationData!,
                  ).then((_) {
                    if (kDebugMode)
                      print(
                        "  Listener Callback: _showVerificationDialogFromState finished.",
                      );
                  });
                } catch (e, s) {
                  if (kDebugMode)
                    print(
                      "  Listener ERROR: Failed to show verification dialog: $e\n$s",
                    );
                  if (mounted) setState(() => _isDialogShowing = false);
                }
              } else {
                if (kDebugMode)
                  print(
                    " Listener race condition: verification dialog requested but another dialog seems active.",
                  );
              }
            } else {
              if (kDebugMode)
                print(
                  "  Listener Warning: Page unmounted before showing verification dialog.",
                );
              _isDialogShowing = false;
            }
          });
        } else if (next.showSuccessDialog && next.successData != null) {
          if (kDebugMode) print("  Listener Condition MET: showSuccessDialog");
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              if (!_isDialogShowing) {
                setState(() => _isDialogShowing = true);
                try {
                  if (kDebugMode)
                    print(
                      "  Listener Action: Calling _showSuccessDialogFromState",
                    );
                  _showSuccessDialogFromState(next.successData!).then((_) {
                    if (kDebugMode)
                      print(
                        "  Listener Callback: _showSuccessDialogFromState finished.",
                      );
                  });
                } catch (e, s) {
                  if (kDebugMode)
                    print(
                      "  Listener ERROR: Failed to show success dialog: $e\n$s",
                    );
                  if (mounted) setState(() => _isDialogShowing = false);
                }
              } else {
                if (kDebugMode)
                  print(
                    " Listener race condition: success dialog requested but another dialog seems active.",
                  );
              }
            } else {
              if (kDebugMode)
                print(
                  "  Listener Warning: Page unmounted before showing success dialog.",
                );
              _isDialogShowing = false;
            }
          });
        } else if (next.showErrorDialog && next.errorMessage != null) {
          if (kDebugMode) print("  Listener Condition MET: showErrorDialog");
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              if (!_isDialogShowing) {
                setState(() => _isDialogShowing = true);
                try {
                  if (kDebugMode)
                    print(
                      "  Listener Action: Calling _showErrorDialogFromState",
                    );
                  _showErrorDialogFromState(next.errorMessage!).then((_) {
                    if (kDebugMode)
                      print(
                        "  Listener Callback: _showErrorDialogFromState finished.",
                      );
                  });
                } catch (e, s) {
                  if (kDebugMode)
                    print(
                      "  Listener ERROR: Failed to show error dialog: $e\n$s",
                    );
                  if (mounted) setState(() => _isDialogShowing = false);
                }
              } else {
                if (kDebugMode)
                  print(
                    " Listener race condition: error dialog requested but another dialog seems active.",
                  );
              }
            } else {
              if (kDebugMode)
                print(
                  "  Listener Warning: Page unmounted before showing error dialog.",
                );
              _isDialogShowing = false;
            }
          });
        } else {
          if (kDebugMode)
            print(
              "  Listener Condition NOT MET: No dialog to show based on state.",
            );
        }
      } else if (!mounted) {
        if (kDebugMode) print("  Listener SKIPPING: Page not mounted.");
      }
      if (kDebugMode) print("--- UserManagementPage Listener Finished ---");
    });

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gestão de Utilizadores',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: 'Pesquisar...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 12,
                      ),
                      suffixIcon:
                          searchQuery.isNotEmpty
                              ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  searchController.clear();
                                  setState(() {
                                    searchQuery = '';
                                  });
                                },
                                splashRadius: 18,
                                tooltip: 'Limpar',
                              )
                              : null,
                    ),
                    onChanged: (value) {
                      setState(() {
                        searchQuery = value.trim();
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Row(
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.refresh, size: 16),
                      label: Text('Atualizar'),
                      onPressed: _isLoading ? null : _loadUsers,
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      icon: const Icon(Icons.add, size: 16),
                      label: Text('Novo Revendedor'),
                      onPressed: _isLoading ? null : _showCreateUserDialog,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            Expanded(
              child:
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _errorMessage != null
                      ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(color: theme.colorScheme.error),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                      : _buildUserTable(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCreateUserDialog() async {
    if (_isDialogShowing) {
      if (kDebugMode) {
        print("_showCreateUserDialog: Dialog already showing. Aborting.");
      }
      return;
    }

    _salesforceIdController.clear();

    setState(() => _isDialogShowing = true);

    if (kDebugMode) {
      print("_showCreateUserDialog: Setting _isDialogShowing to true.");
    }

    try {
      final String? salesforceId = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          final theme = Theme.of(dialogContext);
          return AlertDialog(
            title: Text('Novo Revendedor'),
            content: Form(
              key: _createUserFormKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Introduza o ID Salesforce para obter detalhes e criar uma nova conta de revendedor.',
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _salesforceIdController,
                    decoration: InputDecoration(
                      labelText: 'ID Salesforce',
                      hintText: 'Introduza o ID Salesforce',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'ID Salesforce é obrigatório';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  if (mounted) {
                    if (kDebugMode)
                      print(
                        "Create Dialog: Cancel pressed. Resetting _isDialogShowing.",
                      );
                    setState(() => _isDialogShowing = false);
                  }
                  Navigator.of(dialogContext).pop(null);
                },
                child: Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () {
                  if (_createUserFormKey.currentState!.validate()) {
                    final id = _salesforceIdController.text.trim();
                    if (mounted) {
                      if (kDebugMode)
                        print(
                          "Create Dialog: Create pressed. Resetting _isDialogShowing.",
                        );
                      setState(() => _isDialogShowing = false);
                    }
                    Navigator.of(dialogContext).pop(id);
                  }
                },
                child: Text('Criar'),
              ),
            ],
          );
        },
      );

      if (salesforceId != null) {
        await _initiateUserCreation(salesforceId);
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error showing/handling create user dialog: $e");
      }
      if (mounted) {
        if (kDebugMode) {
          print("Create Dialog: Error caught. Resetting _isDialogShowing.");
        }
        setState(() => _isDialogShowing = false);
      }
    }
  }

  Future<void> _initiateUserCreation(String salesforceId) async {
    await ref
        .read(userCreationProvider.notifier)
        .verifySalesforceUser(salesforceId);
  }

  Future<void> _showVerificationDialogFromState(
    Map<String, dynamic> data,
  ) async {
    final String? name = data['name'] as String?;
    final String? email = data['email'] as String?;
    final String password = data['password'] as String;

    if (!mounted) return;

    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return AlertDialog(
          title: Text('Verificar Utilizador Salesforce'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Utilizador Salesforce encontrado:'),
                const SizedBox(height: 8),
                _buildDialogInfoRow('Nome:', name ?? 'Não fornecido'),
                _buildDialogInfoRow('Email:', email ?? 'Não fornecido'),
                const Divider(height: 24),
                Text('Criar conta Twogether com estas credenciais?'),
                const SizedBox(height: 8),
                _buildDialogInfoRow('Email:', email ?? 'N/A'),
                _buildDialogInfoRow('Role:', 'Revendedor'),
                _buildDialogInfoRow('Senha Inicial:', password),
                const SizedBox(height: 8),
                Text(
                  'Utilizador deve alterar senha no primeiro login.',
                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (mounted) {
                  if (kDebugMode)
                    print(
                      "Verification Dialog: Cancel pressed. Resetting _isDialogShowing.",
                    );
                  setState(() => _isDialogShowing = false);
                }
                Navigator.of(dialogContext).pop(false);
              },
              child: Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (kDebugMode) print("Verification Dialog: Confirm pressed.");
                Navigator.of(dialogContext).pop(true);
              },
              child: Text('Confirmar e Criar'),
            ),
          ],
        );
      },
    ).then((confirmed) async {
      if (confirmed == true) {
        await ref.read(userCreationProvider.notifier).confirmAndCreateUser();
      }
    });
  }

  Future<void> _showSuccessDialogFromState(Map<String, dynamic> data) async {
    final String displayName = data['displayName'] as String;
    final String email = data['email'] as String;
    final String password = data['password'] as String;

    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return AlertDialog(
          title: Text('Utilizador Criado com Sucesso'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Nova conta de revendedor criada:'),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      'Email: ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Expanded(
                      child: SelectableText(
                        email,
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      'Senha Temp: ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Expanded(
                      child: SelectableText(
                        password,
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 18),
                      tooltip: 'Copiar Senha',
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: password));
                        if (!dialogContext.mounted) return;
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          const SnackBar(
                            content: Text('Senha copiada'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Utilizador deve alterar senha no primeiro login.',
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: () {
                      if (mounted) {
                        if (kDebugMode)
                          print(
                            "Success Dialog: Close button pressed. Resetting _isDialogShowing.",
                          );
                        setState(() => _isDialogShowing = false);
                      }
                      Navigator.of(dialogContext).pop();
                    },
                    child: Text('Fechar'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    _loadUsers();
  }

  Future<void> _showErrorDialogFromState(String errorMessage) async {
    if (!mounted) return;
    if (_isDialogShowing) {
      if (kDebugMode) {
        print("_showErrorDialogFromState: Dialog already showing. Aborting.");
      }
      return;
    }
    setState(() => _isDialogShowing = true);
    if (kDebugMode) {
      print("_showErrorDialogFromState: Setting _isDialogShowing to true.");
    }

    await showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Erro'),
            content: Text(errorMessage),
            actions: [
              TextButton(
                onPressed: () {
                  if (mounted) {
                    if (kDebugMode) {
                      print(
                        "Error Dialog: Close pressed. Resetting _isDialogShowing.",
                      );
                    }
                    setState(() => _isDialogShowing = false);
                  }
                  Navigator.of(dialogContext).pop();
                },
                child: const Text('Fechar'),
              ),
            ],
          ),
    );
  }

  Widget _buildDialogInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _navigateToUserDetailPage(AppUser user) {
    if (kDebugMode) {
      print('Navigating to user detail page for user ID: ${user.uid}');
    }
    context.push('/admin/users/${user.uid}', extra: user);
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) {
      return this;
    }
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}
