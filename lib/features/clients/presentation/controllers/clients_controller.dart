import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/usecase/usecase.dart';
import '../../domain/entities/client.dart';
import '../../data/repositories/client_repository_impl.dart';
import '../../domain/usecases/get_clients_usecase.dart';

// Provider for use case
final getClientsUseCaseProvider = Provider<GetClientsUseCase>((ref) {
  return GetClientsUseCase(ref.watch(clientRepositoryProvider));
});

// Provider for clients controller
final clientsControllerProvider =
    StateNotifierProvider<ClientsController, AsyncValue<List<Client>>>((ref) {
      return ClientsController(ref.watch(getClientsUseCaseProvider));
    });

// Provider for repository access helper (temporary until freezed is generated)
final clientRepositoryHelperProvider = Provider<ClientRepositoryImpl>((ref) {
  return ref.watch(clientRepositoryProvider) as ClientRepositoryImpl;
});

// Provider for filtered clients by status
final filteredClientsProvider =
    Provider.family<AsyncValue<List<Client>>, ClientStatus?>((ref, status) {
      final clientsState = ref.watch(clientsControllerProvider);
      final repoHelper = ref.watch(clientRepositoryHelperProvider);

      return clientsState.whenData((clients) {
        if (status == null) return clients;
        return clients
            .where((client) => repoHelper.getClientStatus(client) == status)
            .toList();
      });
    });

class ClientsController extends StateNotifier<AsyncValue<List<Client>>> {
  final GetClientsUseCase _getClientsUseCase;

  ClientsController(this._getClientsUseCase)
    : super(const AsyncValue.loading()) {
    loadClients();
  }

  Future<void> loadClients() async {
    state = const AsyncValue.loading();
    try {
      final result = await _getClientsUseCase(const NoParams());
      result.fold(
        (clients) => state = AsyncValue.data(clients),
        (failure) => state = AsyncValue.error(failure, StackTrace.current),
      );
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> refreshClients() async {
    loadClients();
  }
}
