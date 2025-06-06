import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'; // Reverted to standard import
import 'package:flutter/foundation.dart'; // Added for kDebugMode
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
// Keep standard import for CarouselSlider and CarouselOptions
import '../providers/provider_providers.dart';
import '../../domain/models/provider_info.dart';
import '../../../../presentation/widgets/standard_app_bar.dart';

class ResellerProviderListPage extends ConsumerStatefulWidget { // Changed to ConsumerStatefulWidget
  const ResellerProviderListPage({super.key});

  @override
  ConsumerState<ResellerProviderListPage> createState() => _ResellerProviderListPageState();
}

class _ResellerProviderListPageState extends ConsumerState<ResellerProviderListPage> { // New State class

  // Helper method for responsive font sizing
  double _getResponsiveFontSize(BuildContext context, double baseFontSize) {
    final width = MediaQuery.of(context).size.width;
    return width < 600 ? baseFontSize - 2 : baseFontSize;
  }

  @override
  Widget build(BuildContext context) {
    final providersAsyncValue = ref.watch(providersStreamProvider);

    return Scaffold(
      appBar: const StandardAppBar(
        showBackButton: true,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: providersAsyncValue.when(
        data: (providers) {
          if (providers.isEmpty) {
                  return const Center(child: Text('No resources available yet.'));
          }
                final double maxWidth = 1200;
                final theme = Theme.of(context);
                return Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Responsive spacing after SafeArea - no spacing for mobile, 24px for desktop
                        SizedBox(height: MediaQuery.of(context).size.width < 600 ? 0 : 24),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Text(
                            'Dropbox',
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
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              // Calculate responsive grid layout
                              final screenWidth = MediaQuery.of(context).size.width;
                              int crossAxisCount;
                              double childAspectRatio;
                              
                              if (screenWidth < 600) {
                                crossAxisCount = 2; // Mobile: 2 columns
                                childAspectRatio = 0.75; // Adjusted for smaller card + external title
                              } else if (screenWidth < 900) {
                                crossAxisCount = 3; // Tablet: 3 columns
                                childAspectRatio = 0.8;
                              } else {
                                crossAxisCount = 4; // Desktop: 4 columns
                                childAspectRatio = 0.85;
                              }
                              
                              return GridView.builder(
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  mainAxisSpacing: 16,
                                  crossAxisSpacing: 16,
                                  childAspectRatio: childAspectRatio,
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                                itemCount: providers.length,
                                itemBuilder: (context, index) {
                                  final provider = providers[index];
                                  return _buildProviderSquare(context, provider, theme);
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                );
        },
        loading: () => const Center(child: CupertinoActivityIndicator()),
              error: (error, stack) => Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                  child: Text('Error loading resources: $error', textAlign: TextAlign.center),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderSquare(BuildContext context, ProviderInfo provider, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    
    // Responsive sizing
    final imageSize = isMobile ? 50.0 : 70.0;
    final paddingSize = isMobile ? 16.0 : 20.0;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Card with just the image
        Material(
          color: theme.colorScheme.surface,
          elevation: 4,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              context.push('/providers/${provider.id}', extra: provider);
            },
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              padding: EdgeInsets.all(paddingSize),
              child: CachedNetworkImage(
                imageUrl: provider.imageUrl,
                width: imageSize,
                height: imageSize,
                fit: BoxFit.contain,
                placeholder: (context, url) => const CupertinoActivityIndicator(),
                errorWidget: (context, url, error) {
                  if (kDebugMode) {
                    print('CachedNetworkImage error for ${provider.name} ($url): $error');
                  }
                  return Icon(
                    CupertinoIcons.photo,
                    size: isMobile ? 30 : 40,
                    color: theme.colorScheme.onSurfaceVariant.withAlpha((255 * 0.5).round()),
                  );
                },
              ),
            ),
          ),
        ),
        // Provider name outside the card
        const SizedBox(height: 12),
        Text(
          provider.name,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
            fontSize: isMobile ? 14 : 16,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
