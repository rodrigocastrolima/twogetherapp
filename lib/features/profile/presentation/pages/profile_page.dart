import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../presentation/layout/main_layout.dart';
import '../controllers/profile_controller.dart';
import '../../domain/entities/profile.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(profileControllerProvider);
    final revenueState = ref.watch(revenueControllerProvider);

    return MainLayout(
      showNavigation: true,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Profile', style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 32),
              profileState.when(
                data: (profile) => _buildProfileCard(context, profile),
                loading: () => const Center(child: CircularProgressIndicator()),
                error:
                    (error, stackTrace) =>
                        Center(child: Text('Error: ${error.toString()}')),
              ),
              const SizedBox(height: 32),
              Text(
                'Revenue',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 16),
              revenueState.when(
                data: (revenues) => _buildRevenueList(context, revenues),
                loading: () => const Center(child: CircularProgressIndicator()),
                error:
                    (error, stackTrace) =>
                        Center(child: Text('Error: ${error.toString()}')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context, Profile profile) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(profile.name),
              subtitle: Text(profile.email),
            ),
            const Divider(),
            _buildInfoRow('Phone', profile.phone),
            _buildInfoRow(
              'Registration Date',
              '${profile.registrationDate.day}/${profile.registrationDate.month}/${profile.registrationDate.year}',
            ),
            _buildInfoRow('Total Clients', profile.totalClients.toString()),
            _buildInfoRow('Active Clients', profile.activeClients.toString()),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueList(BuildContext context, List<Revenue> revenues) {
    return Card(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: revenues.length,
        separatorBuilder: (context, index) => const Divider(),
        itemBuilder: (context, index) {
          final revenue = revenues[index];
          return ListTile(
            title: Text(revenue.clientName),
            subtitle: Text('${revenue.type} - CEP: ${revenue.cep}'),
            trailing: Text(
              'R\$ ${revenue.amount.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }
}
