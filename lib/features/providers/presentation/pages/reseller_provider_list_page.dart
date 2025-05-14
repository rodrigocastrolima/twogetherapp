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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(CupertinoIcons.chevron_left, color: theme.colorScheme.onSurface),
          onPressed: () => context.pop(),
        ),
        title: LogoWidget(height: 60, darkMode: isDark),
        centerTitle: true, 
        elevation: 0, 
        backgroundColor: Colors.transparent, 
        scrolledUnderElevation: 0.0, 
      ),
      body: providersAsyncValue.when(
        data: (providers) {
          if (providers.isEmpty) {
            return const Center(child: Text('No resources available yet.'));
          }
          return Column(
            mainAxisAlignment: MainAxisAlignment.center, // Center carousel vertically
            children: [
              CarouselSlider.builder(
                carouselController: _carouselController,
            itemCount: providers.length,
                itemBuilder: (context, index, realIndex) {
              final provider = providers[index];
                  return _buildProviderCarouselItem(context, provider, theme);
                },
                options: CarouselOptions(
                  height: MediaQuery.of(context).size.height * 0.5, // Example height, adjust as needed
                  viewportFraction: 0.8, // To show parts of other cards
                  enlargeCenterPage: true,
                  enableInfiniteScroll: providers.length > 1, // Disable if only one item
                  onPageChanged: (index, reason) {
                    setState(() {
                      _currentCarouselIndex = index;
                    });
                  },
                ),
              ),
              if (providers.length > 1) // Only show indicator if more than one item
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: providers.asMap().entries.map((entry) {
                    return GestureDetector(
                      onTap: () => _carouselController.animateToPage(entry.key),
                      child: Container(
                        width: 8.0,
                        height: 8.0,
                        margin: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 4.0),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: (theme.brightness == Brightness.dark ? Colors.white : Colors.black)
                              .withOpacity(_currentCarouselIndex == entry.key ? 0.9 : 0.4),
                        ),
                      ),
              );
                  }).toList(),
                ),
            ],
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
    );
  }

  // New method to build carousel items (adapt from _buildProviderListItem)
  Widget _buildProviderCarouselItem(
    BuildContext context,
    ProviderInfo provider,
    ThemeData theme,
  ) {
    final isDark = theme.brightness == Brightness.dark;
    // Card styling similar to the example image
    return GestureDetector(
      onTap: () {
        context.push('/providers/${provider.id}', extra: provider);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 20.0), // Margin around card
        decoration: BoxDecoration(
          color: isDark ? theme.colorScheme.surfaceVariant.withOpacity(0.5) : Colors.white,
          borderRadius: BorderRadius.circular(16.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 8.0,
              spreadRadius: 2.0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect( // To ensure content respects border radius
            borderRadius: BorderRadius.circular(16.0),
            child: Column(
            mainAxisAlignment: MainAxisAlignment.center, // Center content vertically
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8.0), // Padding for the image
        child: CachedNetworkImage(
          imageUrl: provider.imageUrl,
                    fit: BoxFit.contain, // Contain to see full logo
                    placeholder: (context, url) => const CupertinoActivityIndicator(),
                    errorWidget: (context, url, error) => 
                        Icon(CupertinoIcons.photo, size: 50, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5)),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Text(
                  provider.name,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
              ),
        ),
      ),
    );
  }

  // _buildProviderListItem (original) can be removed or kept if used elsewhere
  // Widget _buildProviderListItem(...) { ... }
}
