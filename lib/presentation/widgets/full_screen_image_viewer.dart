import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:typed_data'; // Added for Uint8List

class FullScreenImageViewer extends StatelessWidget {
  final String? imageUrl; // Made nullable
  final String? imageName; // Optional name for context
  final Uint8List? imageBytes;

  const FullScreenImageViewer({
    super.key,
    this.imageUrl,
    this.imageName,
    this.imageBytes,
  }) : assert(
         imageUrl != null || imageBytes != null,
         'Either imageUrl or imageBytes must be provided',
       ); // Ensure one is provided

  // --- Action Handlers ---

  Future<void> _onDownload(BuildContext context) async {
    // Only allow download if imageUrl exists
    if (imageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Download not available for local data')),
      );
      return;
    }
    final Uri url = Uri.parse(imageUrl!);
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
    // Only allow sharing URL if imageUrl exists
    if (imageUrl == null) {
      // TODO: Implement sharing bytes (requires saving to temp file first)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sharing local data not implemented yet')),
      );
      return;
    }
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
    // Determine if actions requiring a URL should be enabled
    final bool urlActionsEnabled = imageUrl != null;

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
            tooltip: 'Share Image',
            // Disable if showing bytes and URL sharing is not appropriate
            onPressed: urlActionsEnabled ? () => _onShare(context) : null,
          ),
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Open Image Link',
            // Disable if showing bytes
            onPressed: urlActionsEnabled ? () => _onDownload(context) : null,
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: InteractiveViewer(
            panEnabled: true,
            minScale: 0.5,
            maxScale: 4.0,
            // --- MODIFIED: Conditionally use Image.memory or Image.network --- //
            child:
                imageBytes != null
                    ? Image.memory(
                      imageBytes!,
                      fit: BoxFit.contain,
                      // Optional: Add error builder for memory image if needed
                      errorBuilder: (context, error, stackTrace) {
                        print('Error loading image from memory: $error');
                        return _buildErrorWidget();
                      },
                    )
                    : Image.network(
                      imageUrl!, // Known to be non-null if imageBytes is null
                      fit: BoxFit.contain,
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
                      errorBuilder: (context, error, stackTrace) {
                        print('Error loading image from network: $error');
                        return _buildErrorWidget();
                      },
                    ),
            // --- END MODIFICATION --- //
          ),
        ),
      ),
    );
  }

  // Helper for error display
  Widget _buildErrorWidget() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: Colors.red, size: 50),
          SizedBox(height: 16),
          Text('Could not load image', style: TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }
}
