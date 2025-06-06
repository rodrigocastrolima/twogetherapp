import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/provider_providers.dart';
import '../../domain/models/provider_file.dart';
// Import the viewers
import '../../../../presentation/widgets/full_screen_image_viewer.dart';
import '../../../../presentation/widgets/full_screen_pdf_viewer.dart';
import '../../../../presentation/widgets/standard_app_bar.dart';
import '../../../../presentation/widgets/simple_list_item.dart';
import '../../../../core/services/file_icon_service.dart';

class ResellerProviderFilesPage extends ConsumerStatefulWidget {
  final String providerId;
  final String providerName;

  const ResellerProviderFilesPage({
    super.key, 
    required this.providerId,
    required this.providerName,
  });

  @override
  ConsumerState<ResellerProviderFilesPage> createState() => _ResellerProviderFilesPageState();
}

class _ResellerProviderFilesPageState extends ConsumerState<ResellerProviderFilesPage> {
  
  // Helper method for responsive font sizing
  double _getResponsiveFontSize(BuildContext context, double baseFontSize) {
    final width = MediaQuery.of(context).size.width;
    return width < 600 ? baseFontSize - 2 : baseFontSize;
  }

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
  Widget build(BuildContext context) {
    final filesAsyncValue = ref.watch(providerFilesStreamProvider(widget.providerId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: const StandardAppBar(
        showBackButton: true,
      ),
      body: SafeArea(
        bottom: false,
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Responsive spacing after SafeArea - no spacing for mobile, 24px for desktop
            SizedBox(height: MediaQuery.of(context).size.width < 600 ? 0 : 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(
                widget.providerName,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                  fontSize: _getResponsiveFontSize(context, 24),
                ),
              ),
            ),
            // Responsive spacing after title - 16px for mobile, 24px for desktop
            SizedBox(height: MediaQuery.of(context).size.width < 600 ? 16 : 24),
            Expanded(
              child: filesAsyncValue.when(
        data: (files) {
          if (files.isEmpty) {
            return const Center(
                        child: Text('Nenhuns ficheiros disponíveis para este fornecedor.'),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
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




