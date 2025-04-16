import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;
  final String? imageName; // Optional name for context

  const FullScreenImageViewer({
    super.key,
    required this.imageUrl,
    this.imageName,
  });

  // --- Action Handlers ---

  Future<void> _onDownload(BuildContext context) async {
    // For now, just launch the URL. Browsers often handle downloads.
    // Native download would require more packages (dio, path_provider, etc.)
    final Uri url = Uri.parse(imageUrl);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $imageUrl';
      }
    } catch (e) {
      print('Error launching URL for download: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open image link: $e')),
        );
      }
    }
  }

  Future<void> _onShare(BuildContext context) async {
    try {
      // Share the image URL
      await Share.share('Check out this image: $imageUrl');
    } catch (e) {
      print('Error sharing image link: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not share image link: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Use a dark background for better contrast
      backgroundColor: Colors.black.withOpacity(0.85),
      appBar: AppBar(
        // Make AppBar transparent
        backgroundColor: Colors.transparent,
        elevation: 0,
        // Use white icon color for contrast
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.close), // Use close icon
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share Image Link',
            onPressed: () => _onShare(context),
          ),
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Open Image Link',
            onPressed: () => _onDownload(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: InteractiveViewer(
            panEnabled: true,
            minScale: 0.5,
            maxScale: 4.0,
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
              // Loading indicator
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Center(
                  child: CircularProgressIndicator(
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.white,
                    ),
                    value:
                        loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                  ),
                );
              },
              // Error display
              errorBuilder: (context, error, stackTrace) {
                print('Error loading full screen image: $error');
                return const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline, color: Colors.red, size: 50),
                      SizedBox(height: 16),
                      Text(
                        'Could not load image',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
