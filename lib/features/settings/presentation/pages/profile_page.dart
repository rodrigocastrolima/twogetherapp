import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/theme/theme.dart';
import 'package:go_router/go_router.dart';
import '../../../../presentation/widgets/logo.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  bool _isLoading = true;
  Map<String, dynamic>? _userData;
  String? _errorMessage;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Usuário não autenticado';
        });
        return;
      }

      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .get();

      if (!userDoc.exists) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Dados do usuário não encontrados';
        });
        return;
      }

      setState(() {
        _userData = userDoc.data();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erro ao carregar dados: ${e.toString()}';
      });
    }
  }

  Future<void> _changePassword() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Send password reset email to current user's email
      await FirebaseAuth.instance.sendPasswordResetEmail(email: user.email!);
    } catch (e) {
      // Handle error if needed
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.0,
        leading: IconButton(
          icon: Icon(
            CupertinoIcons.chevron_left,
            color: theme.colorScheme.onSurface,
          ),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            }
          },
        ),
        title: LogoWidget(
          height: 60,
          darkMode: isDark,
        ),
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  'Perfil',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildProfileHeader(theme),
                      const SizedBox(height: 20),
                      _buildProfileContent(theme),
                      if (_isLoading)
                        const Center(child: CircularProgressIndicator())
                      else if (_errorMessage != null)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(color: AppTheme.destructive),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      const SizedBox(height: 32), // Bottom padding
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(ThemeData theme) {
    final userData = _userData ?? {};
    String getField(String key, [String fallback = 'Não informado']) {
      final additional = userData['additionalData'] as Map<String, dynamic>? ?? {};
      final value = userData[key] ?? additional[key];
      if (value == null || (value is String && value.trim().isEmpty)) return fallback;
      return value.toString();
    }
    return Center(
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: theme.colorScheme.primary.withAlpha((255 * 0.2).round()),
            child: Text(
              getField('displayName', getField('email', '?')).isNotEmpty
                  ? getField('displayName', getField('email', '?'))[0].toUpperCase()
                  : '?',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            getField('displayName', getField('email', 'Usuário')),
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            getField('email'),
            style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface.withAlpha((255 * 0.7).round())),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildActionButton(
                context,
                icon: Icons.monetization_on_outlined,
                label: 'Comissões',
                route: '/dashboard',
              ),
              const SizedBox(width: 16),
              _buildActionButton(
                context,
                icon: Icons.lock_outline,
                label: 'Alterar Senha',
                route: '/change-password',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileContent(ThemeData theme) {
    final userData = _userData ?? {};
    final additional = userData['additionalData'] as Map<String, dynamic>? ?? {};

    String getField(String key, [String fallback = 'Não informado']) {
      final value = userData[key] ?? additional[key];
      if (value == null || (value is String && value.trim().isEmpty)) return fallback;
      return value.toString();
    }

    String formatDate(dynamic timestamp) {
      if (timestamp == null) return 'Não disponível';
      if (timestamp is Timestamp) {
        final date = timestamp.toDate();
        return '${date.day}/${date.month}/${date.year}';
      }
      if (timestamp is String && timestamp.length >= 10) {
        try {
          final date = DateTime.parse(timestamp);
          return '${date.day}/${date.month}/${date.year}';
        } catch (_) {}
      }
      return timestamp.toString();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Personal Info
        _buildTwoColumnSection(
          theme,
          'Informação Pessoal',
          [
            _infoItem('Nome do Colaborador', getField('displayName')),
            _infoItem('Email Principal', getField('email')),
            _infoItem('Telefone Principal', getField('phoneNumber', getField('mobilePhone'))),
            _infoItem('Email Secundário', getField('emailSecondary')),
          ],
          [
            _infoItem('Data de Nascimento', formatDate(additional['birthDate'])),
            _infoItem('Nome do Revendedor', getField('resellerName', getField('revendedorRetail'))),
            _infoItem('Data de Registo', formatDate(additional['joinedDate'])),
            _infoItem('Telefone Secundário', getField('phoneSecondary')),
          ],
        ),
        const SizedBox(height: 16),
        // Legal Info
        _buildTwoColumnSection(
          theme,
          'Informação Legal',
          [
            _infoItem('NIF (Pessoal)', getField('collaboratorNif')),
            _infoItem('CC', getField('ccNumber')),
            _infoItem('SS', getField('ssNumber')),
          ],
          [
            _infoItem('NIF (Empresa)', getField('companyNif')),
            _infoItem('Código Comercial', getField('commercialCode')),
            _infoItem('IBAN', getField('iban')),
          ],
        ),
        const SizedBox(height: 16),
        // Location Info
        _buildTwoColumnSection(
          theme,
          'Localização',
          [
            _infoItem('Morada', getField('address')),
            _infoItem('Código Postal', getField('postalCode')),
            _infoItem('Localidade', getField('city')),
          ],
          [
            _infoItem('Distrito', getField('district')),
            _infoItem('Tipologia', getField('tipologia')),
            _infoItem('Atividade Comercial', getField('atividadeComercial')),
          ],
        ),
      ],
    );
  }

  Widget _infoItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 180,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              textAlign: TextAlign.left,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : 'N/D',
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
              textAlign: TextAlign.left,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTwoColumnSection(ThemeData theme, String title, List<Widget> left, List<Widget> right) {
    final isWide = MediaQuery.of(context).size.width > 900;
    final textTheme = theme.textTheme;
    final int maxLen = left.length > right.length ? left.length : right.length;
    final paddedLeft = List<Widget>.from(left)..addAll(List.generate(maxLen - left.length, (_) => const SizedBox.shrink()));
    final paddedRight = List<Widget>.from(right)..addAll(List.generate(maxLen - right.length, (_) => const SizedBox.shrink()));
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: theme.dividerColor.withAlpha(25)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
            const SizedBox(height: 4),
            isWide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          children: paddedLeft.map((w) => Padding(padding: const EdgeInsets.only(bottom: 4), child: w)).toList(),
                        ),
                      ),
                      const SizedBox(width: 32),
                      Expanded(
                        child: Column(
                          children: paddedRight.map((w) => Padding(padding: const EdgeInsets.only(bottom: 4), child: w)).toList(),
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      ...left.map((w) => Padding(padding: const EdgeInsets.only(bottom: 4), child: w)),
                      ...right.map((w) => Padding(padding: const EdgeInsets.only(bottom: 4), child: w)),
                    ],
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, {required IconData icon, required String label, required String route}) {
    final theme = Theme.of(context);
    return ElevatedButton.icon(
      icon: Icon(icon, color: theme.colorScheme.primary),
      label: Text(label, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 1,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: () => context.push(route),
    );
  }
}
