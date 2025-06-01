import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui';
import '../../../../features/auth/domain/models/app_user.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../providers/user_creation_provider.dart';
import '../../../../core/theme/ui_styles.dart';
import '../../../../presentation/widgets/simple_list_item.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../../../presentation/widgets/success_dialog.dart';

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

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    _loadUsers();
  }

  @override
  void dispose() {
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
      
      if (mounted) {
        _users = resellers.where((user) => user.uid != _currentUserId).toList();
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

  Future<void> _deleteUser(String uid) async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('deleteUserAndFirestore');
      await callable.call({'uid': uid});

      if (!mounted) return;
      await showSuccessDialog(
        context: context,
        message: 'Utilizador eliminado',
        onDismissed: () {},
      );

      if (!mounted) return;
      await _loadUsers();
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Falha ao eliminar utilizador: ${e.message ?? e.toString()}';
        _isLoading = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro: ${e.message ?? e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
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
          if (kDebugMode) {
            print("  Listener Condition MET: showVerificationDialog");
          }
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              if (!_isDialogShowing) {
                setState(() => _isDialogShowing = true);
                try {
                  if (kDebugMode) {
                    print(
                      "  Listener Action: Calling _showVerificationDialogFromState",
                    );
                  }
                  _showVerificationDialogFromState(
                    next.verificationData!,
                  ).then((_) {
                    if (kDebugMode) {
                      print(
                        "  Listener Callback: _showVerificationDialogFromState finished.",
                      );
                    }
                  });
                } catch (e, s) {
                  if (kDebugMode) {
                    print(
                      "  Listener ERROR: Failed to show verification dialog: $e\n$s",
                    );
                  }
                  if (mounted) setState(() => _isDialogShowing = false);
                }
              } else {
                if (kDebugMode) {
                  print(
                    " Listener race condition: verification dialog requested but another dialog seems active.",
                  );
                }
              }
            } else {
              if (kDebugMode) {
                print(
                  "  Listener Warning: Page unmounted before showing verification dialog.",
                );
              }
              _isDialogShowing = false;
            }
          });
        } else if (next.showSuccessDialog && next.successData != null) {
          if (kDebugMode) {
            print("  Listener Condition MET: showSuccessDialog");
          }
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              if (!_isDialogShowing) {
                setState(() => _isDialogShowing = true);
                try {
                  if (kDebugMode) {
                    print(
                      "  Listener Action: Calling _showSuccessDialogFromState",
                    );
                  }
                  _showSuccessDialogFromState(next.successData!).then((_) {
                    if (kDebugMode) {
                      print(
                        "  Listener Callback: _showSuccessDialogFromState finished.",
                      );
                    }
                  });
                } catch (e, s) {
                  if (kDebugMode) {
                    print(
                      "  Listener ERROR: Failed to show success dialog: $e\n$s",
                    );
                  }
                  if (mounted) setState(() => _isDialogShowing = false);
                }
              } else {
                if (kDebugMode) {
                  print(
                    " Listener race condition: success dialog requested but another dialog seems active.",
                  );
                }
              }
            } else {
              if (kDebugMode) {
                print(
                  "  Listener Warning: Page unmounted before showing success dialog.",
                );
              }
              _isDialogShowing = false;
            }
          });
        } else if (next.showErrorDialog && next.errorMessage != null) {
          if (kDebugMode) {
            print("  Listener Condition MET: showErrorDialog");
          }
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              if (!_isDialogShowing) {
                setState(() => _isDialogShowing = true);
                try {
                  if (kDebugMode) {
                    print(
                      "  Listener Action: Calling _showErrorDialogFromState",
                    );
                  }
                  _showErrorDialogFromState(next.errorMessage!).then((_) {
                    if (kDebugMode) {
                      print(
                        "  Listener Callback: _showErrorDialogFromState finished.",
                      );
                    }
                  });
                } catch (e, s) {
                  if (kDebugMode) {
                    print(
                      "  Listener ERROR: Failed to show error dialog: $e\n$s",
                    );
                  }
                  if (mounted) setState(() => _isDialogShowing = false);
                }
              } else {
                if (kDebugMode) {
                  print(
                    " Listener race condition: error dialog requested but another dialog seems active.",
                  );
                }
              }
            } else {
              if (kDebugMode) {
                print(
                  "  Listener Warning: Page unmounted before showing error dialog.",
                );
              }
              _isDialogShowing = false;
            }
          });
        } else {
          if (kDebugMode) {
            print(
              "  Listener Condition NOT MET: No dialog to show based on state.",
            );
          }
        }
      } else if (!mounted) {
        if (kDebugMode) {
          print("  Listener SKIPPING: Page not mounted.");
      }
      }
      if (kDebugMode) {
        print("--- UserManagementPage Listener Finished ---");
      }
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
            child: Row(
              children: [
                Expanded(
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
                const SizedBox(width: 12),
                SizedBox(
                  height: 40,
                  child: Builder(
                    builder: (context) {
                      final isDark = Theme.of(context).brightness == Brightness.dark;
                      final bgColor = isDark ? theme.colorScheme.surface : Colors.white;
                      final borderRadius = BorderRadius.circular(12);
                      final borderColor = theme.dividerColor.withAlpha((255 * 0.18).round());
                      return FilledButton.icon(
                        icon: Icon(
                          Icons.add,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                        label: Text(
                          'Novo Utilizador',
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        onPressed: () {
                          context.push('/admin/users/create');
                        },
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          backgroundColor: bgColor,
                          foregroundColor: theme.colorScheme.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: borderRadius,
                            side: BorderSide(color: borderColor, width: 1),
                          ),
                          elevation: 0,
                        ),
                      );
                    },
                  ),
                ),
              ],
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
                    : (() {
                        final filteredUsers = searchQuery.isEmpty
                            ? _users
                            : _users.where((user) {
                                final name = user.displayName?.toLowerCase() ?? '';
                                final email = user.email.toLowerCase();
                                final query = searchQuery.toLowerCase();
                                return name.contains(query) || email.contains(query);
                              }).toList();
                        return ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          itemCount: filteredUsers.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 0),
                          itemBuilder: (context, index) {
                            final user = filteredUsers[index];
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
                        );
                      })(),
          ),
        ],
      ),
    );
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
                  if (kDebugMode) {
                    print(
                      "Verification Dialog: Cancel pressed. Resetting _isDialogShowing.",
                    );
                  }
                  setState(() => _isDialogShowing = false);
                }
                Navigator.of(dialogContext).pop(false);
              },
              child: Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (kDebugMode) {
                  print("Verification Dialog: Confirm pressed.");
                }
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
                        if (kDebugMode) {
                          print(
                            "Success Dialog: Close button pressed. Resetting _isDialogShowing.",
                          );
                        }
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
    final navigator = GoRouter.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    try {
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('conversations')
          .where('resellerId', isEqualTo: user.uid)
          .limit(1)
          .get();
      
      if (snapshot.docs.isEmpty) {
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
        await FirebaseFirestore.instance
            .collection('conversations')
            .add(conversationData);
      }
      
      navigator.go('/admin/messages', extra: {'userId': user.uid});
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Erro ao abrir chat: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showDeleteConfirmation(BuildContext context, AppUser user) {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
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
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) {
      return this;
    }
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}
