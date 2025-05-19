import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/cupertino.dart';
import '../../../../presentation/widgets/logo.dart';
import '../../../../presentation/widgets/app_loading_indicator.dart';
import '../../../../presentation/widgets/simple_list_item.dart';
import '../../../../presentation/widgets/secure_file_viewer.dart';
import '../../../../presentation/widgets/success_dialog.dart';
import '../../data/models/cpe_proposta_detail.dart'; // To be created
import '../providers/cpe_proposta_providers.dart'; // To be created

class AdminCpePropostaDetailPage extends ConsumerStatefulWidget {
  final String cpePropostaId;
  const AdminCpePropostaDetailPage({required this.cpePropostaId, super.key});

  @override
  ConsumerState<AdminCpePropostaDetailPage> createState() => _AdminCpePropostaDetailPageState();
}

class _AdminCpePropostaDetailPageState extends ConsumerState<AdminCpePropostaDetailPage> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final detailsAsync = ref.watch(cpePropostaDetailProvider(widget.cpePropostaId));

    return detailsAsync.when(
      loading: () => const AppLoadingIndicator(),
      error: (error, stack) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Erro ao carregar detalhes da CPE-Proposta:\n$error',
              style: TextStyle(color: theme.colorScheme.error),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
      data: (detail) {
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: Icon(CupertinoIcons.chevron_left, color: theme.colorScheme.onSurface),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            title: LogoWidget(height: 60, darkMode: theme.brightness == Brightness.dark),
            centerTitle: true,
            elevation: 0,
            backgroundColor: Colors.transparent,
            scrolledUnderElevation: 0.0,
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 24, left: 24, right: 24, bottom: 16),
                    child: Text(
                      detail.name ?? 'Detalhes da CPE-Proposta',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                      textAlign: TextAlign.left,
                    ),
                  ),
                  _buildSectionCard(
                    context,
                    'Informação da Empresa',
                    [
                      _buildDetailRow('CPE', detail.cpe?.name),
                      _buildDetailRow('Entidade', detail.cpe?.entidadeName),
                      _buildDetailRow('NIF', detail.cpe?.nifC),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSectionCard(
                    context,
                    'Informação do Local',
                    [
                      _buildDetailRow('Consumo anual esperado (KWh)', detail.cpe?.consumoAnualEsperadoKwhC?.toString()),
                      _buildDetailRow('Fidelização (Anos)', detail.cpe?.fidelizacaoAnosC?.toString()),
                      _buildDetailRow('Solução', detail.cpe?.solucaoC),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSectionCard(
                    context,
                    'Informação da Proposta',
                    [
                      _buildDetailRow('Status', detail.statusC),
                      _buildDetailRow('Consumo ou Potência Pico', detail.consumoOuPotenciaPicoC?.toString()),
                      _buildDetailRow('Fidelização (Anos)', detail.fidelizacaoAnosC?.toString()),
                      _buildDetailRow('Margem Comercial', detail.margemComercialC?.toString()),
                      _buildDetailRow('Agente Retail', detail.agenteRetailName),
                      _buildDetailRow('Responsável de Negócio – Retail', detail.responsavelNegocioRetailC),
                      _buildDetailRow('Responsável de Negócio – Exclusivo', detail.responsavelNegocioExclusivoC),
                      _buildDetailRow('Gestor de Revenda', detail.gestorDeRevendaC),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSectionCard(
                    context,
                    'Faturação Retail',
                    [
                      _buildDetailRow('Ciclo de Ativação', detail.cicloDeAtivacaoName),
                      _buildDetailRow('Comissão Retail', detail.comissaoRetailC?.toString()),
                      _buildDetailRow('Nota Informativa', detail.notaInformativaC),
                      _buildDetailRow('Pagamento da Factura Retail', detail.pagamentoDaFacturaRetailC),
                      _buildDetailRow('Factura Retail', detail.facturaRetailC),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSectionCard(
                    context,
                    'Visita Técnica',
                    [
                      _buildDetailRow('Visita Técnica', detail.visitaTecnicaC),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildFilesSection(context, detail.files),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionCard(BuildContext context, String title, List<Widget> children) {
    final theme = Theme.of(context);
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: theme.dividerColor.withAlpha(25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 200,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value ?? 'N/A',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilesSection(BuildContext context, List<dynamic> files) {
    final theme = Theme.of(context);
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: theme.dividerColor.withAlpha(25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ficheiros',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            if (files.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20.0),
                  child: Text(
                    'Sem ficheiros associados a esta CPE-Proposta.',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              )
            else
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: files.map((file) {
                  return Container(
                    width: 70,
                    height: 70,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceVariant.withAlpha((255 * 0.7).round()),
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(
                        color: Colors.black.withAlpha((255 * 0.1).round()),
                        width: 0.5,
                      ),
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SecureFileViewer(
                                    contentVersionId: file.contentVersionId,
                                    title: file.title,
                                    fileType: file.fileType,
                                  ),
                                  fullscreenDialog: true,
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(8.0),
                            child: Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.insert_drive_file, color: theme.colorScheme.primary, size: 30),
                                  const SizedBox(height: 4),
                                  Text(
                                    file.title ?? '',
                                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 8),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
} 