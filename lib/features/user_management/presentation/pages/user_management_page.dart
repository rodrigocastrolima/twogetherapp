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
import '../../../../features/chat/presentation/pages/admin_chat_page.dart';
import '../../../../core/theme/ui_styles.dart';
import '../../../../presentation/widgets/simple_list_item.dart';

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
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 0),
            child: Text(
              'Revendedores',
              style: theme.textTheme.headlineLarge?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: SizedBox(
              height: 40,
              child: TextField(
                controller: searchController,
                decoration: AppStyles.searchInputDecoration(context, 'Pesquisar...'),
                onChanged: (value) {
                  setState(() {
                    searchQuery = value.trim();
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _isLoading
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
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        itemCount: _users.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 0),
                        itemBuilder: (context, index) {
                          final user = _users[index];
                          return SimpleListItem(
                            leading: CircleAvatar(
                              radius: 20,
                              backgroundColor: theme.colorScheme.secondaryContainer,
                              child: Text(
                                (user.displayName?.isNotEmpty == true
                                        ? user.displayName![0]
                                        : user.email[0])
                                    .toUpperCase(),
                                style: TextStyle(
                                  color: theme.colorScheme.onSecondaryContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: user.displayName ?? user.email,
                            subtitle: user.email,
                            onTap: () => _navigateToUserDetailPage(user),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.message_outlined, color: theme.colorScheme.primary),
                                  tooltip: 'Mensagens',
                                  onPressed: () => _openOrCreateChat(context, user),
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                                  tooltip: 'Eliminar',
                                  onPressed: () => _showDeleteConfirmation(context, user),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
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

  void _openOrCreateChat(BuildContext context, AppUser user) async {
    try {
      String conversationId = '';
      bool isNewConversation = false;
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('conversations')
          .where('resellerId', isEqualTo: user.uid)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) {
        conversationId = snapshot.docs.first.id;
      } else {
        isNewConversation = true;
        final conversationData = {
          'resellerId': user.uid,
          'resellerName': user.displayName ?? user.email,
          'lastMessageContent': null,
          'lastMessageTime': FieldValue.serverTimestamp(),
          'lastMessageIsFromAdmin': null,
          'active': false,
          'unreadByAdmin': false,
          'unreadByReseller': false,
          'unreadCount': 0,
          'unreadCounts': {},
          'createdAt': FieldValue.serverTimestamp(),
          'participants': ['admin', user.uid],
          'activeUsers': ['admin', user.uid],
        };
        final docRef = await FirebaseFirestore.instance
            .collection('conversations')
            .add(conversationData);
        conversationId = docRef.id;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AdminChatPage(),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao abrir chat: $e'), backgroundColor: Colors.red),
        );
      }
    }
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
