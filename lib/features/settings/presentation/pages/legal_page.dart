import 'package:flutter/material.dart';

class LegalPage extends StatelessWidget {
  final String title;
  final String content;

  const LegalPage({Key? key, required this.title, required this.content}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: TextStyle(color: theme.colorScheme.onSurface)),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          content,
          style: theme.textTheme.bodyLarge,
        ),
      ),
    );
  }
} 