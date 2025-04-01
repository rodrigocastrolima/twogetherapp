import '../entities/client.dart';

abstract class ClientRepository {
  Future<List<Client>> getClients();
  Future<Client> getClientById(String clientId);
  Future<Client> createClient(Client client);
  Future<Client> updateClient(Client client);
  Future<void> deleteClient(String clientId);
  Future<List<Client>> searchClients(String query);
  Future<List<Client>> filterClientsByStatus(ClientStatus status);
}
