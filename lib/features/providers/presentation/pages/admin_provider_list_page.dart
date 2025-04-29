import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../providers/provider_providers.dart';
import '../../domain/models/provider_info.dart';
import '../../../../core/services/loading_service.dart';
import '../../../../core/widgets/message_display.dart';
import '../../domain/models/provider_file.dart';

class AdminProviderListPage extends ConsumerStatefulWidget {
  const AdminProviderListPage({super.key});

  @override
  ConsumerState<AdminProviderListPage> createState() =>
      _AdminProviderListPageState();
}

class _AdminProviderListPageState extends ConsumerState<AdminProviderListPage> {
  String? _pageError;

  @override
  Widget build(BuildContext context) {
    final providersAsyncValue = ref.watch(providersStreamProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Providers'), // TODO: l10n
        centerTitle: false,
        elevation: 1,
        shadowColor: theme.shadowColor.withOpacity(0.1),
      ),
      body: Column(
        children: [
          if (_pageError != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ErrorMessageWidget(message: _pageError!),
            ),
          Expanded(
            child: providersAsyncValue.when(
              data: (providers) {
                if (providers.isEmpty) {
                  return const Center(
                    child: Text('No providers found. Add one!'), // TODO: l10n
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: providers.length,
                  separatorBuilder:
                      (context, index) => const SizedBox(height: 12),
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
                        'Error loading providers: $error', // TODO: Improve error display
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          context.push('/admin/providers/create');
        },
        icon: const Icon(CupertinoIcons.add),
        label: const Text('Add Provider'), // TODO: l10n
      ),
    );
  }

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
          context.push('/admin/providers/${provider.id}');
        },
        child: Padding(
          padding: const EdgeInsets.only(
            left: 12.0,
            top: 12.0,
            bottom: 12.0,
            right: 4.0,
          ),
          child: Row(
            children: [
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
              IconButton(
                icon: Icon(
                  CupertinoIcons.delete,
                  color: theme.colorScheme.error,
                  size: 20,
                ),
                onPressed: () {
                  _confirmAndDeleteProvider(context, ref, provider);
                },
                tooltip: 'Delete Provider',
                visualDensity: VisualDensity.compact,
              ),
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

  Future<void> _confirmAndDeleteProvider(
    BuildContext context,
    WidgetRef ref,
    ProviderInfo provider,
  ) async {
    setState(() {
      _pageError = null;
    });

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Provider?'),
            content: Text(
              'Are you sure you want to delete the provider "${provider.name}"?\n\nTHIS WILL DELETE ALL ASSOCIATED FILES AND CANNOT BE UNDONE.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('DELETE'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      setState(() {
        _pageError = null;
      });
      final loadingService = ref.read(loadingServiceProvider);
      loadingService.show(context, message: 'Deleting Provider and Files...');
      bool deletionSuccess = false;
      String errorMessage = '';

      try {
        final firestore = FirebaseFirestore.instance;
        final storage = FirebaseStorage.instance;
        final providerRef = firestore.collection('providers').doc(provider.id);
        final filesRef = providerRef.collection('files');

        // 1. Get all file documents
        final filesSnapshot = await filesRef.get();
        final List<ProviderFile> filesToDelete =
            filesSnapshot.docs
                .map((doc) => ProviderFile.fromFirestore(doc))
                .toList();

        // 2. Delete files from Storage (best effort, log errors)
        List<Future> storageDeleteFutures = [];
        for (final file in filesToDelete) {
          if (file.storagePath.isNotEmpty) {
            print('Deleting from storage: ${file.storagePath}');
            storageDeleteFutures.add(
              storage.ref(file.storagePath).delete().catchError((e) {
                // Log error but don't stop the whole process
                print('Error deleting ${file.storagePath} from Storage: $e');
              }),
            );
          }
        }
        await Future.wait(
          storageDeleteFutures,
        ); // Wait for all storage deletions
        print('Finished attempting storage deletions.');

        // 3. Delete Firestore file documents using Batched Write
        WriteBatch batch = firestore.batch();
        for (final doc in filesSnapshot.docs) {
          print('Adding file doc to batch delete: ${doc.id}');
          batch.delete(doc.reference);
        }
        await batch.commit(); // Commit file document deletions
        print('Finished Firestore file document batch delete.');

        // 4. Delete Provider Image from Storage (if path exists)
        if (provider.storagePath.isNotEmpty) {
          print(
            'Deleting provider image from storage: ${provider.storagePath}',
          );
          try {
            await storage.ref(provider.storagePath).delete();
          } catch (e) {
            // Log error but continue
            print(
              'Error deleting provider image ${provider.storagePath} from Storage: $e',
            );
          }
        }

        // 5. Delete main Provider Firestore document
        print('Deleting main provider doc: ${provider.id}');
        await providerRef.delete();

        deletionSuccess = true;
        print('Provider deletion process completed successfully.');
      } catch (e) {
        print('Error during provider deletion process: $e');
        errorMessage = 'Failed to delete provider: $e';
        // Try to show error via page state
        if (mounted) {
          setState(() {
            _pageError = errorMessage;
          });
        }
      } finally {
        if (mounted) loadingService.hide();
        // Show snackbar regardless of page error state
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                deletionSuccess
                    ? 'Provider "${provider.name}" deleted successfully.'
                    : errorMessage.isNotEmpty
                    ? errorMessage
                    : 'Failed to delete provider.',
              ),
              backgroundColor:
                  deletionSuccess
                      ? Colors.green
                      : Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }
}
