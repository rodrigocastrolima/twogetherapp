import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:twogether/features/providers/domain/models/provider_info.dart';
import 'package:twogether/features/providers/domain/models/provider_file.dart';

/// Provides a stream of the list of all providers.
final providersStreamProvider = StreamProvider<List<ProviderInfo>>((ref) {
  final firestore = FirebaseFirestore.instance;
  final stream =
      firestore
          .collection('providers')
          .orderBy('name') // Order alphabetically by name
          .snapshots();

  return stream.map((snapshot) {
    return snapshot.docs.map((doc) => ProviderInfo.fromFirestore(doc)).toList();
  });
});

/// Provides a stream of files for a specific provider.
final providerFilesStreamProvider =
    StreamProvider.family<List<ProviderFile>, String>((ref, providerId) {
      final firestore = FirebaseFirestore.instance;
      final stream =
          firestore
              .collection('providers')
              .doc(providerId)
              .collection('files')
              .orderBy('uploadedAt', descending: true) // Show newest first
              .snapshots();

      return stream.map((snapshot) {
        return snapshot.docs
            .map((doc) => ProviderFile.fromFirestore(doc))
            .toList();
      });
    });

// We will add more providers here later (e.g., for files within a provider)
