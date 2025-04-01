import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/salesforce_repository.dart';
import '../../domain/models/account.dart';

// Provider for SalesforceRepository
final salesforceRepositoryProvider = Provider<SalesforceRepository>((ref) {
  return SalesforceRepository();
});

// Connection status provider
final salesforceConnectionProvider = FutureProvider<bool>((ref) async {
  final repository = ref.watch(salesforceRepositoryProvider);
  return repository.initialize();
});

// Accounts provider
final salesforceAccountsProvider =
    FutureProvider.family<List<Account>, String?>((ref, filter) async {
      final repository = ref.watch(salesforceRepositoryProvider);
      return repository.getAccounts(filter: filter);
    });

// Account by ID provider
final salesforceAccountProvider = FutureProvider.family<Account?, String>((
  ref,
  accountId,
) async {
  final repository = ref.watch(salesforceRepositoryProvider);
  return repository.getAccountById(accountId);
});

// Active account provider - to track currently selected account
final activeAccountIdProvider = StateProvider<String?>((ref) => null);

// Connection state notifier
class SalesforceConnectionNotifier extends StateNotifier<AsyncValue<bool>> {
  final SalesforceRepository _repository;

  SalesforceConnectionNotifier(this._repository)
    : super(const AsyncValue.loading()) {
    // Initialize when created
    _initialize();
  }

  Future<void> _initialize() async {
    state = const AsyncValue.loading();
    try {
      final result = await _repository.initialize();
      state = AsyncValue.data(result);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<bool> connect(
    String username,
    String password, {
    bool isSandbox = false,
  }) async {
    state = const AsyncValue.loading();
    try {
      final result = await _repository.connect(
        username,
        password,
        isSandbox: isSandbox,
      );
      state = AsyncValue.data(result);
      return result;
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      return false;
    }
  }

  Future<void> disconnect() async {
    try {
      await _repository.disconnect();
      state = const AsyncValue.data(false);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }
}

final salesforceConnectionNotifierProvider =
    StateNotifierProvider<SalesforceConnectionNotifier, AsyncValue<bool>>((
      ref,
    ) {
      final repository = ref.watch(salesforceRepositoryProvider);
      return SalesforceConnectionNotifier(repository);
    });
