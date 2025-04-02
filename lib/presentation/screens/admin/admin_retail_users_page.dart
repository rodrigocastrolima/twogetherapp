import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../../core/theme/theme.dart';
import '../../../presentation/layout/admin_layout.dart';

class AdminRetailUsersPage extends StatelessWidget {
  const AdminRetailUsersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AdminLayout(
      pageTitle: l10n.adminRetailUsers,
      child: Center(
        child: Text(
          l10n.adminRetailUsers,
          style: TextStyle(
            color: AppTheme.foreground,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
