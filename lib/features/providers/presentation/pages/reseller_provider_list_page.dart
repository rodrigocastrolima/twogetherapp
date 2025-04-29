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
        title: const Text('Resources'), // TODO: l10n (or different title?)
        centerTitle: false,
        elevation: 1,
        shadowColor: theme.shadowColor.withOpacity(0.1),
      ),
      body: providersAsyncValue.when(
        data: (providers) {
          if (providers.isEmpty) {
            return const Center(
              child: Text('No resources available yet.'), // TODO: l10n
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16.0),
            itemCount: providers.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final provider = providers[index];
              return _buildProviderCard(context, provider, theme);
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
      // No FAB for resellers
    );
  }

  // Reusable card, slightly modified for reseller view (no delete button)
  Widget _buildProviderCard(
    BuildContext context,
    ProviderInfo provider,
    ThemeData theme,
  ) {
    return Card(
      elevation: 2,
      shadowColor: theme.shadowColor.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // Navigate to reseller file list page (Step 12)
          context.push('/providers/${provider.id}'); // Use reseller path
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              // Provider Image/Logo
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: provider.imageUrl,
                  height: 50,
                  width: 50,
                  fit: BoxFit.cover,
                  placeholder:
                      (context, url) => Container(
                        height: 50,
                        width: 50,
                        color: theme.colorScheme.secondaryContainer.withOpacity(
                          0.3,
                        ),
                        child: const CupertinoActivityIndicator(),
                      ),
                  errorWidget:
                      (context, url, error) => Container(
                        height: 50,
                        width: 50,
                        color: theme.colorScheme.errorContainer.withOpacity(
                          0.3,
                        ),
                        child: Icon(
                          CupertinoIcons.exclamationmark_triangle,
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                ),
              ),
              const SizedBox(width: 16),
              // Provider Name
              Expanded(
                child: Text(
                  provider.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              // Chevron only
              Icon(
                CupertinoIcons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
