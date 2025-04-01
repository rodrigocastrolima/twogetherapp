import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/client.dart';
import '../../domain/repositories/client_repository.dart';

final clientRepositoryProvider = Provider<ClientRepository>((ref) {
  return ClientRepositoryImpl();
});

class ClientRepositoryImpl implements ClientRepository {
  @override
  Future<List<Client>> getClients() async {
    // TODO: Implement actual API call
    await Future.delayed(const Duration(seconds: 1)); // Simulate network delay

    // Create dummy data - normally these would be constructed from API responses
    return _dummyClients;
  }

  @override
  Future<Client> getClientById(String clientId) async {
    // TODO: Implement actual API call
    await Future.delayed(const Duration(seconds: 1)); // Simulate network delay

    // Return a dummy client or find one from our list
    return _dummyClients.firstWhere(
      (client) => getClientId(client) == clientId,
      orElse:
          () => _createDummyClient(
            id: clientId,
            name: 'John Doe',
            email: 'john@example.com',
            phone: '+1 234 567 890',
            address: '123 Main St, New York, NY',
            status: ClientStatus.active,
            createdAt: DateTime.now().subtract(const Duration(days: 30)),
            notes: 'Premium customer',
          ),
    );
  }

  @override
  Future<Client> createClient(Client client) async {
    // TODO: Implement actual API call
    await Future.delayed(const Duration(seconds: 1)); // Simulate network delay

    // Create a new client with a generated ID
    return _createDummyClient(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: getClientName(client),
      email: getClientEmail(client),
      phone: getClientPhone(client),
      address: getClientAddress(client),
      status: getClientStatus(client),
      createdAt: getClientCreatedAt(client),
      notes: getClientNotes(client),
    );
  }

  @override
  Future<Client> updateClient(Client client) async {
    // TODO: Implement actual API call
    await Future.delayed(const Duration(seconds: 1)); // Simulate network delay

    // In a real implementation, we would update the client in the database
    return client;
  }

  @override
  Future<void> deleteClient(String clientId) async {
    // TODO: Implement actual API call
    await Future.delayed(const Duration(seconds: 1)); // Simulate network delay

    // In a real implementation, we would delete the client from the database
  }

  @override
  Future<List<Client>> searchClients(String query) async {
    // TODO: Implement actual API call
    await Future.delayed(const Duration(seconds: 1)); // Simulate network delay

    final allClients = await getClients();
    final queryLower = query.toLowerCase();

    return allClients.where((client) {
      final name = getClientName(client).toLowerCase();
      final email = getClientEmail(client).toLowerCase();
      return name.contains(queryLower) || email.contains(queryLower);
    }).toList();
  }

  @override
  Future<List<Client>> filterClientsByStatus(ClientStatus status) async {
    // TODO: Implement actual API call
    await Future.delayed(const Duration(seconds: 1)); // Simulate network delay

    final allClients = await getClients();
    return allClients
        .where((client) => getClientStatus(client) == status)
        .toList();
  }

  // Helper methods to access Client properties until freezed generation is complete
  String getClientId(Client client) => (client as dynamic).id as String;
  String getClientName(Client client) => (client as dynamic).name as String;
  String getClientEmail(Client client) => (client as dynamic).email as String;
  String getClientPhone(Client client) => (client as dynamic).phone as String;
  String getClientAddress(Client client) =>
      (client as dynamic).address as String;
  ClientStatus getClientStatus(Client client) =>
      (client as dynamic).status as ClientStatus;
  DateTime getClientCreatedAt(Client client) =>
      (client as dynamic).createdAt as DateTime;
  String? getClientNotes(Client client) => (client as dynamic).notes as String?;

  // Helper method to create a Client instance until freezed generation is complete
  Client _createDummyClient({
    required String id,
    required String name,
    required String email,
    required String phone,
    required String address,
    required ClientStatus status,
    required DateTime createdAt,
    String? notes,
  }) {
    return Client(
      id: id,
      name: name,
      email: email,
      phone: phone,
      address: address,
      status: status,
      createdAt: createdAt,
      notes: notes,
    );
  }

  // Dummy data
  final List<Client> _dummyClients = [
    Client(
      id: '1',
      name: 'John Doe',
      email: 'john@example.com',
      phone: '+1 234 567 890',
      address: '123 Main St, New York, NY',
      status: ClientStatus.active,
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
      notes: 'Premium customer',
    ),
    Client(
      id: '2',
      name: 'Jane Smith',
      email: 'jane@example.com',
      phone: '+1 987 654 321',
      address: '456 Elm St, Boston, MA',
      status: ClientStatus.pending,
      createdAt: DateTime.now().subtract(const Duration(days: 15)),
    ),
  ];
}
