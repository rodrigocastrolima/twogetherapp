import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/theme.dart';
import '../../../features/services/data/repositories/service_submission_repository.dart';
import '../../../features/services/presentation/providers/service_submission_provider.dart';
import '../../../core/models/service_submission.dart';
import '../../../core/models/service_types.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';

class ClientsPage extends ConsumerStatefulWidget {
  const ClientsPage({super.key});

  @override
  ConsumerState<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends ConsumerState<ClientsPage> {
  final _searchController = TextEditingController();
  String _selectedView = 'pending_review';
  String _searchQuery = '';

  // Status constants
  static const String STATUS_PENDING_REVIEW = 'pending_review';
  static const String STATUS_APPROVED = 'approved';
  static const String STATUS_REJECTED = 'rejected';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final submissionsStream = ref.watch(userSubmissionsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: true,
        top: false,
        child: Column(
          children: [
            // Header area
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    'Minhas Submissões',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: _buildSearchBar()),
                ],
              ),
            ),

            // Tab selector - full width, themed
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildSegmentedControl(),
            ),

            // Add a bit more space
            const SizedBox(height: 12),

            // Divider
            Container(
              height: 0.5,
              color: CupertinoColors.systemGrey4.withAlpha(128),
            ),

            // Submissions list
            Expanded(
              child: submissionsStream.when(
                data: (submissions) {
                  final filteredSubmissions = _filterSubmissions(
                    submissions,
                    _selectedView,
                    _searchQuery,
                  );

                  if (filteredSubmissions.isEmpty) {
                    return _buildEmptyState();
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.only(top: 6),
                    itemCount: filteredSubmissions.length,
                    separatorBuilder:
                        (context, index) => Container(
                          margin: const EdgeInsets.only(left: 72),
                          height: 0.5,
                          color: CupertinoColors.systemGrey5.withAlpha(128),
                        ),
                    itemBuilder: (context, index) {
                      final submission = filteredSubmissions[index];
                      return _buildSubmissionCard(
                        submission,
                        key: ValueKey(submission.id),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error:
                    (error, stackTrace) => Center(
                      child: Text(
                        'Erro ao carregar submissões: $error',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () {
          context.push('/services');
        },
      ),
    );
  }

  List<ServiceSubmission> _filterSubmissions(
    List<ServiceSubmission> submissions,
    String selectedView,
    String searchQuery,
  ) {
    return submissions.where((submission) {
      // Filter by search (check client name or email)
      if (searchQuery.isNotEmpty) {
        final nameMatch = submission.responsibleName.toLowerCase().contains(
          searchQuery,
        );
        final emailMatch = submission.email.toLowerCase().contains(searchQuery);
        final nifMatch = submission.nif.toLowerCase().contains(searchQuery);

        if (!nameMatch && !emailMatch && !nifMatch) {
          return false;
        }
      }

      // Filter by selected view/status
      switch (selectedView) {
        case STATUS_PENDING_REVIEW:
          return submission.status == STATUS_PENDING_REVIEW;
        case STATUS_APPROVED:
          return submission.status == STATUS_APPROVED;
        case STATUS_REJECTED:
          return submission.status == STATUS_REJECTED;
        default:
          return true;
      }
    }).toList();
  }

  Widget _buildSearchBar() {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6.withAlpha(204),
        borderRadius: BorderRadius.circular(10),
      ),
      child: CupertinoTextField(
        controller: _searchController,
        placeholder: 'Buscar por nome, email ou NIF',
        placeholderStyle: const TextStyle(
          color: CupertinoColors.systemGrey,
          fontSize: 14,
        ),
        prefix: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Icon(
            CupertinoIcons.search,
            color: CupertinoColors.systemGrey,
            size: 16,
          ),
        ),
        suffix:
            _searchQuery.isNotEmpty
                ? GestureDetector(
                  onTap: () => _searchController.clear(),
                  child: const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(
                      CupertinoIcons.clear_circled_solid,
                      color: CupertinoColors.systemGrey,
                      size: 16,
                    ),
                  ),
                )
                : null,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        style: const TextStyle(fontSize: 14),
      ),
    );
  }

  Widget _buildSegmentedControl() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: 44,
          child: Row(
            children: [
              Expanded(
                child: _buildCustomSegment(STATUS_PENDING_REVIEW, 'Em Revisão'),
              ),
              Container(
                width: 1,
                height: 44,
                color: Colors.white.withAlpha(26),
              ),
              Expanded(
                child: _buildCustomSegment(STATUS_APPROVED, 'Aprovados'),
              ),
              Container(
                width: 1,
                height: 44,
                color: Colors.white.withAlpha(26),
              ),
              Expanded(
                child: _buildCustomSegment(STATUS_REJECTED, 'Rejeitados'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomSegment(String value, String label, [int? count]) {
    final isSelected = _selectedView == value;

    return GestureDetector(
      onTap: () => setState(() => _selectedView = value),
      child: Container(
        alignment: Alignment.center,
        color: isSelected ? AppTheme.primary.withAlpha(51) : Colors.transparent,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color:
                    isSelected ? AppTheme.primary : Colors.white.withAlpha(204),
              ),
            ),
            if (count != null && count > 0) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color:
                      isSelected
                          ? AppTheme.primary
                          : Colors.white.withAlpha(26),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color:
                        isSelected ? Colors.white : Colors.white.withAlpha(204),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    String message;

    switch (_selectedView) {
      case STATUS_PENDING_REVIEW:
        message = 'Nenhuma submissão em revisão';
        break;
      case STATUS_APPROVED:
        message = 'Nenhuma submissão aprovada';
        break;
      case STATUS_REJECTED:
        message = 'Nenhuma submissão rejeitada';
        break;
      default:
        message = 'Nenhuma submissão encontrada';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.doc_text,
            size: 48,
            color: CupertinoColors.systemGrey,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: CupertinoColors.systemGrey,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Crie uma nova submissão usando o botão +',
            style: TextStyle(fontSize: 15, color: CupertinoColors.systemGrey),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmissionCard(ServiceSubmission submission, {Key? key}) {
    // Format date
    final formattedDate = DateFormat(
      'dd/MM/yyyy',
    ).format(submission.submissionDate);

    return GestureDetector(
      key: key,
      onTap: () => _showSubmissionDetails(submission),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            _buildSubmissionIcon(submission),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    submission.responsibleName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: CupertinoColors.label,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        '${submission.serviceCategory.displayName} • $formattedDate',
                        style: const TextStyle(
                          fontSize: 13,
                          color: CupertinoColors.systemGrey,
                        ),
                      ),
                      const SizedBox(width: 6),
                      _buildStatusIndicator(submission.status),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(
              CupertinoIcons.chevron_right,
              size: 14,
              color: CupertinoColors.systemGrey3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(String status) {
    Color color;
    String displayStatus;

    switch (status) {
      case STATUS_PENDING_REVIEW:
        color = CupertinoColors.systemOrange;
        displayStatus = 'Em Revisão';
        break;
      case STATUS_APPROVED:
        color = CupertinoColors.systemGreen;
        displayStatus = 'Aprovado';
        break;
      case STATUS_REJECTED:
        color = CupertinoColors.systemRed;
        displayStatus = 'Rejeitado';
        break;
      default:
        color = CupertinoColors.systemGrey;
        displayStatus = status;
    }

    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          displayStatus,
          style: TextStyle(
            fontSize: 13,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildSubmissionIcon(ServiceSubmission submission) {
    final bool isResidential = submission.clientType == ClientType.residential;

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color:
            isResidential
                ? CupertinoColors.systemGreen.withAlpha(26)
                : CupertinoColors.systemIndigo.withAlpha(26),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Icon(
          isResidential
              ? CupertinoIcons.person_fill
              : CupertinoIcons.building_2_fill,
          size: 20,
          color:
              isResidential
                  ? CupertinoColors.systemGreen
                  : CupertinoColors.systemIndigo,
        ),
      ),
    );
  }

  void _showSubmissionDetails(ServiceSubmission submission) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SubmissionDetailsSheet(submission: submission),
    );
  }
}

class _SubmissionDetailsSheet extends StatelessWidget {
  final ServiceSubmission submission;

  const _SubmissionDetailsSheet({required this.submission});

  @override
  Widget build(BuildContext context) {
    // Format date
    final formattedDate = DateFormat(
      'dd/MM/yyyy HH:mm',
    ).format(submission.submissionDate);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Detalhes da Submissão',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.foreground,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Enviado em $formattedDate',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.foreground.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(submission.status),
              ],
            ),
          ),

          // Content - Scrollable
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Client Information Section
                  _buildSectionTitle('Informações do Cliente'),
                  _buildInfoItem('Nome', submission.responsibleName),
                  if (submission.clientType == ClientType.commercial &&
                      submission.companyName != null)
                    _buildInfoItem('Empresa', submission.companyName!),
                  _buildInfoItem(
                    'Tipo de Cliente',
                    submission.clientType.displayName,
                  ),
                  _buildInfoItem('NIF', submission.nif),
                  _buildInfoItem('Email', submission.email),
                  _buildInfoItem('Telefone', submission.phone),
                  const SizedBox(height: 20),

                  // Service Information Section
                  _buildSectionTitle('Informações do Serviço'),
                  _buildInfoItem(
                    'Categoria',
                    submission.serviceCategory.displayName,
                  ),
                  if (submission.energyType != null)
                    _buildInfoItem(
                      'Tipo de Energia',
                      submission.energyType!.displayName,
                    ),
                  _buildInfoItem('Fornecedor', submission.provider.displayName),
                  const SizedBox(height: 20),

                  // Invoice Section
                  _buildSectionTitle('Fatura'),
                  if (submission.invoicePhoto != null)
                    _buildInvoiceImage(submission.invoicePhoto!.storagePath),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // Close button
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Fechar'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppTheme.foreground,
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label + ':',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.foreground.withOpacity(0.7),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 14, color: AppTheme.foreground),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String displayStatus;

    switch (status) {
      case 'pending_review':
        color = Colors.orange;
        displayStatus = 'Em Revisão';
        break;
      case 'approved':
        color = Colors.green;
        displayStatus = 'Aprovado';
        break;
      case 'rejected':
        color = Colors.red;
        displayStatus = 'Rejeitado';
        break;
      default:
        color = Colors.grey;
        displayStatus = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color),
      ),
      child: Text(
        displayStatus,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildInvoiceImage(String storagePath) {
    return GestureDetector(
      onTap: () {
        // TODO: Show fullscreen image viewer
      },
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        clipBehavior: Clip.antiAlias,
        child: FutureBuilder<String>(
          future: FirebaseStorage.instance.ref(storagePath).getDownloadURL(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError || !snapshot.hasData) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, color: Colors.red[300], size: 40),
                    const SizedBox(height: 8),
                    Text(
                      'Erro ao carregar imagem',
                      style: TextStyle(color: Colors.red[300]),
                    ),
                  ],
                ),
              );
            }

            return CachedNetworkImage(
              imageUrl: snapshot.data!,
              fit: BoxFit.cover,
              width: double.infinity,
              placeholder:
                  (context, url) =>
                      const Center(child: CircularProgressIndicator()),
              errorWidget:
                  (context, url, error) =>
                      const Center(child: Icon(Icons.error)),
            );
          },
        ),
      ),
    );
  }
}
