import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:typed_data';

class FullScreenImageViewer extends StatelessWidget {
  final String? imageUrl;
  final String? imageName;
  final Uint8List? imageBytes;

  const FullScreenImageViewer({
    super.key,
    this.imageUrl,
    this.imageName,
    this.imageBytes,
  }) : assert(
         imageUrl != null || imageBytes != null,
         'Either imageUrl or imageBytes must be provided',
       );

  Future<void> _onDownload(BuildContext context) async {
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
      if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open image link: $e')),
          );
      }
    }
  }

  Future<void> _onShare(BuildContext context) async {
    if (imageUrl == null && imageBytes == null) {
         ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No image data to share.')),
        );
        return;
    }
    
    if (imageUrl != null) {
        try {
            await Share.share('Check out this image: ${imageUrl!}');
        } catch (e) {
            if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Could not share image link: $e')),
                );
            }
        }
    } else {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sharing local image data not yet fully implemented.')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool urlActionsEnabled = imageUrl != null;
    final theme = Theme.of(context);
    
    return CupertinoPageScaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        middle: imageName != null 
          ? Text(
              imageName!,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
            )
          : null,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.clear, size: 28),
          onPressed: () => Navigator.of(context).pop(),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (imageUrl != null || imageBytes != null)
              CupertinoButton(
                padding: const EdgeInsets.all(8.0),
                child: const Icon(CupertinoIcons.share, size: 24),
                onPressed: () => _onShare(context),
              ),
            if (urlActionsEnabled)
              CupertinoButton(
                padding: const EdgeInsets.all(8.0),
                child: const Icon(CupertinoIcons.cloud_download, size: 24),
                onPressed: () => _onDownload(context),
              ),
          ],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: InteractiveViewer(
            panEnabled: true,
            minScale: 0.5,
            maxScale: 4.0,
            child: imageBytes != null
                ? Image.memory(
                    imageBytes!,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return _buildErrorWidget(context);
                    },
                  )
                : Image.network(
                    imageUrl!, 
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CupertinoActivityIndicator(
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return _buildErrorWidget(context);
                    },
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorWidget(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CupertinoIcons.exclamationmark_circle, color: CupertinoDynamicColor.resolve(CupertinoColors.systemRed, context), size: 50),
          const SizedBox(height: 16),
          Text(
            'Could not load image',
            style: TextStyle(color: CupertinoDynamicColor.resolve(CupertinoColors.secondaryLabel, context)),
          ),
        ],
      ),
    );
  }
}
