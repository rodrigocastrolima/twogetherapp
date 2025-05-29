import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/provider_providers.dart';
import '../../domain/models/provider_file.dart';
import '../../../../core/theme/theme.dart';
// Import the viewers
import '../../../../presentation/widgets/full_screen_image_viewer.dart';
import '../../../../presentation/widgets/full_screen_pdf_viewer.dart';
import '../../../../presentation/widgets/logo.dart'; // Import LogoWidget for AppBar
import '../../../../presentation/widgets/simple_list_item.dart';
import '../../../../core/services/file_icon_service.dart';

class ResellerProviderFilesPage extends ConsumerWidget {
  final String providerId;
  final String providerName;

  const ResellerProviderFilesPage({
    super.key, 
    required this.providerId,
    required this.providerName,
  });

  // --- File Tap Handler ---
  Future<void> _handleFileTap(BuildContext context, ProviderFile file) async {
    final fileType = file.fileType.toLowerCase();
    final url = Uri.parse(file.downloadUrl);

    if (['jpg', 'jpeg', 'png', 'gif', 'bmp'].contains(fileType)) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => FullScreenImageViewer(imageUrl: file.downloadUrl, imageName: file.fileName), fullscreenDialog: true));
    } else if (fileType == 'pdf') {
      Navigator.push(context, MaterialPageRoute(builder: (context) => FullScreenPdfViewer(pdfUrl: file.downloadUrl, pdfName: file.fileName), fullscreenDialog: true));
    } else {
      try {
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        } else {
          throw 'Could not launch $url';
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não foi possível abrir o link do ficheiro: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filesAsyncValue = ref.watch(providerFilesStreamProvider(providerId));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark; // For LogoWidget in AppBar

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(CupertinoIcons.chevron_left, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: LogoWidget(height: 60, darkMode: isDark),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.0,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 24, left: 24, right: 24, bottom: 16),
                child: Text(
                  providerName, // Display the provider name
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.left,
                ),
              ),
              Expanded(
                child: filesAsyncValue.when(
        data: (files) {
          if (files.isEmpty) {
            return const Center(
                        child: Text('Nenhuns ficheiros disponíveis para este fornecedor.'),
            );
          }
          return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            itemCount: files.length,
            itemBuilder: (context, index) {
              final file = files[index];
                        return _buildFileListItem(context, file, theme);
            },
          );
        },
        loading: () => const Center(child: CupertinoActivityIndicator()),
                  error: (error, stack) => Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                      child: Text('Erro ao carregar ficheiros: $error', textAlign: TextAlign.center),
                    ),
                  ),
                ),
                ),
            ],
              ),
            ),
      ),
    );
  }

  Widget _buildFileListItem(BuildContext context, ProviderFile file, ThemeData theme) {
    final iconAsset = FileIconService.getIconAssetPath(file.fileType);
    return SimpleListItem(
      leading: Image.asset(
        iconAsset,
        width: 40,
        height: 40,
        fit: BoxFit.contain,
      ),
      title: file.fileName,
      subtitle: file.description.isNotEmpty ? file.description : null,
      trailing: Icon(
        CupertinoIcons.chevron_forward,
        color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
        size: 20,
      ),
      onTap: () => _handleFileTap(context, file),
    );
  }
}




