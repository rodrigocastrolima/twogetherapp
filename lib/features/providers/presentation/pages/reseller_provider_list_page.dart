import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/provider_providers.dart';
import '../../domain/models/provider_info.dart';

class ResellerProviderListPage extends ConsumerWidget {
  const ResellerProviderListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final providersAsyncValue = ref.watch(providersStreamProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Resources'), // TODO: l10n
        centerTitle: true, // Centered title
        elevation: 0, // Flat AppBar
        backgroundColor:
            theme.scaffoldBackgroundColor, // Match scaffold background
        foregroundColor:
            theme.colorScheme.onBackground, // Ensure text/icon contrast
      ),
      body: providersAsyncValue.when(
        data: (providers) {
          if (providers.isEmpty) {
            return const Center(
              child: Text('No resources available yet.'), // TODO: l10n
            );
          }
          // Use ListView.builder for potentially long lists
          return ListView.builder(
            padding: EdgeInsets.zero, // Let ListTile handle its own padding
            itemCount: providers.length,
            itemBuilder: (context, index) {
              final provider = providers[index];
              // Add a Divider if not the last item for separation
              return Column(
                children: [
                  _buildProviderListItem(context, provider, theme),
                  if (index < providers.length - 1)
                    const Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 0,
                    ), // Standard divider
                ],
              );
            },
          );
        },
        loading: () => const Center(child: CupertinoActivityIndicator()),
        error:
            (error, stack) => Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Error loading resources: $error', // TODO: Improve error display
                  textAlign: TextAlign.center,
                ),
              ),
            ),
      ),
    );
  }

  // Changed to _buildProviderListItem using ListTile
  Widget _buildProviderListItem(
    BuildContext context,
    ProviderInfo provider,
    ThemeData theme,
  ) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16.0,
        vertical: 8.0,
      ), // Adjust padding
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: provider.imageUrl,
          height: 44, // Adjusted size for ListTile
          width: 44, // Adjusted size for ListTile
          fit: BoxFit.cover,
          placeholder:
              (context, url) => Container(
                height: 44,
                width: 44,
                color: theme.colorScheme.secondaryContainer.withOpacity(0.3),
                child: const CupertinoActivityIndicator(radius: 12),
              ),
          errorWidget:
              (context, url, error) => Container(
                height: 44,
                width: 44,
                color: theme.colorScheme.errorContainer.withOpacity(0.3),
                child: Icon(
                  CupertinoIcons
                      .exclamationmark_triangle_fill, // Changed to filled icon
                  color: theme.colorScheme.onErrorContainer,
                  size: 22,
                ),
              ),
        ),
      ),
      title: Text(
        provider.name,
        style: theme.textTheme.titleMedium?.copyWith(
          // Using titleMedium, can adjust
          // fontWeight: FontWeight.w500, // Slightly less bold than w600
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Icon(
        CupertinoIcons.chevron_forward, // Standard iOS forward chevron
        color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
        size: 20,
      ),
      onTap: () {
        context.push('/providers/${provider.id}');
      },
    );
  }
}
