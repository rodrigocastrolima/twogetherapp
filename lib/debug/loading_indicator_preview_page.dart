import 'package:flutter/material.dart';
import 'package:twogether/presentation/widgets/app_loading_indicator.dart'; // Adjust import path if needed

class LoadingIndicatorPreviewPage extends StatelessWidget {
  const LoadingIndicatorPreviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: AppLoadingIndicator());
  }
}
