import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'; // Reverted to standard import
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart'; // Keep standard import for CarouselSlider and CarouselOptions
import '../providers/provider_providers.dart';
import '../../domain/models/provider_info.dart';
import '../../../../presentation/widgets/logo.dart'; // Import LogoWidget

class ResellerProviderListPage extends ConsumerStatefulWidget { // Changed to ConsumerStatefulWidget
  const ResellerProviderListPage({super.key});

  @override
  ConsumerState<ResellerProviderListPage> createState() => _ResellerProviderListPageState();
}

class _ResellerProviderListPageState extends ConsumerState<ResellerProviderListPage> { // New State class
  int _currentCarouselIndex = 0;
  final CarouselSliderController _carouselController = CarouselSliderController();

  @override
  Widget build(BuildContext context) {
    final providersAsyncValue = ref.watch(providersStreamProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(CupertinoIcons.chevron_left, color: Theme.of(context).colorScheme.onSurface),
          onPressed: () => context.pop(),
        ),
        title: LogoWidget(height: 60, darkMode: Theme.of(context).brightness == Brightness.dark),
        centerTitle: true, 
        elevation: 0, 
        backgroundColor: Colors.transparent, 
        scrolledUnderElevation: 0.0, 
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
                        Padding(
                          padding: const EdgeInsets.only(top: 24, left: 24, right: 24, bottom: 16),
                          child: Text(
                            'Dropbox',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                            textAlign: TextAlign.left,
                          ),
                        ),
                        Expanded(
                          child: GridView.builder(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              mainAxisSpacing: 24,
                              crossAxisSpacing: 24,
                              childAspectRatio: 1,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
            itemCount: providers.length,
            itemBuilder: (context, index) {
              final provider = providers[index];
                              return _buildProviderSquare(context, provider, theme);
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
    return Material(
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
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CachedNetworkImage(
                imageUrl: provider.imageUrl,
                width: 80,
                height: 80,
                fit: BoxFit.contain,
                placeholder: (context, url) => const CupertinoActivityIndicator(),
                errorWidget: (context, url, error) {
                  print('CachedNetworkImage error for ${provider.name} ($url): $error');
                  return Icon(
                    CupertinoIcons.photo,
                    size: 40,
                    color: theme.colorScheme.onSurfaceVariant.withAlpha((255 * 0.5).round()),
                  );
                },
              ),
              const SizedBox(height: 18),
              Text(
                provider.name,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.black87 : Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
              ),
        ),
      ),
    );
  }
}
