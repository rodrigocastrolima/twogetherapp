import 'package:flutter/foundation.dart';
import 'salesforce_proposal.dart'; // Import the proposal model
import 'salesforce_file.dart'; // Import the new File model

@immutable
class DetailedSalesforceOpportunity {
  final String id;
  final String name;
  final String? accountName;
  final String? accountId;
  final String? resellerName;
  final String? resellerSalesforceId;
  final String? nifC;
  final String? faseC;
  final String? createdDate;
  final String? tipoDeOportunidadeC;
  final String? segmentoDeClienteC;
  final String? soluOC;
  final String? dataDePrevisaoDeFechoC;
  final String? dataDeCriacaoDaOportunidadeC;
  final List<SalesforceProposal> proposals; // List of related proposals

  // --- Added Fields ---
  final String? ownerName;
  final String? observacoes;
  final String? motivoDaPerda;
  final bool? qualificacaoConcluida;
  final String? redFlag;
  final String? faseLDF;
  final String? ultimaListaCicloName;
  final String? dataContacto;
  final String? dataReuniao;
  final String? dataProposta;
  final String? dataFecho; // Actual Close Date
  final String? dataUltimaAtualizacaoFase;
  final String? backOffice;
  final String? cicloDoGanhoName;
  final List<SalesforceFile> files; // List of related files
  // --- End Added Fields ---

  const DetailedSalesforceOpportunity({
    required this.id,
    required this.name,
    this.accountName,
    this.accountId,
    this.resellerName,
    this.resellerSalesforceId,
    this.nifC,
    this.faseC,
    this.createdDate,
    this.tipoDeOportunidadeC,
    this.segmentoDeClienteC,
    this.soluOC,
    this.dataDePrevisaoDeFechoC,
    this.dataDeCriacaoDaOportunidadeC,
    required this.proposals,
    // -- Added to constructor --
    this.ownerName,
    this.observacoes,
    this.motivoDaPerda,
    this.qualificacaoConcluida,
    this.redFlag,
    this.faseLDF,
    this.ultimaListaCicloName,
    this.dataContacto,
    this.dataReuniao,
    this.dataProposta,
    this.dataFecho,
    this.dataUltimaAtualizacaoFase,
    this.backOffice,
    this.cicloDoGanhoName,
    required this.files,
    // -- End Added --
  });

  factory DetailedSalesforceOpportunity.fromJson(Map<String, dynamic> json) {
    // Nested structure from Cloud Function: json['data'] contains details
    final Map<String, dynamic> details =
        json; // Assume input is already the 'data' object

    final Map<String, dynamic> oppDetails =
        details['opportunityDetails'] as Map<String, dynamic>? ?? {};
    final List<dynamic> proposalList =
        details['proposals'] as List<dynamic>? ?? [];
    final List<dynamic> fileList =
        details['files'] as List<dynamic>? ?? []; // Parse files list

    // Helper to safely get values from oppDetails map
    T? safeGet<T>(String key) => oppDetails[key] as T?;

    return DetailedSalesforceOpportunity(
      id: safeGet<String>('id') ?? (throw const FormatException('Missing id')),
      name:
          safeGet<String>('name') ??
          (throw const FormatException('Missing name')),
      accountId: safeGet<String>('accountId'), // Adjust key if needed from CF
      accountName: safeGet<String>('accountName'),
      resellerSalesforceId: safeGet<String>(
        'resellerSalesforceId',
      ), // Adjust key if needed from CF
      resellerName: safeGet<String>('resellerName'),
      nifC: safeGet<String>('nifC'),
      faseC: safeGet<String>('faseC'),
      createdDate: safeGet<String>('createdDate'),
      dataDePrevisaoDeFechoC: safeGet<String>('dataDePrevisaoDeFechoC'),
      dataDeCriacaoDaOportunidadeC: safeGet<String>(
        'dataDeCriacaoDaOportunidadeC',
      ),
      tipoDeOportunidadeC: safeGet<String>('tipoDeOportunidadeC'),
      segmentoDeClienteC: safeGet<String>('segmentoDeClienteC'),
      soluOC: safeGet<String>('soluOC'),

      // Parse Proposals (Keep existing logic)
      proposals:
          proposalList
              .map(
                (p) => SalesforceProposal.fromJson(p as Map<String, dynamic>),
              )
              .toList(),

      // --- Parse Added Fields ---
      ownerName: safeGet<String>('ownerName'),
      observacoes: safeGet<String>('observacoes'),
      motivoDaPerda: safeGet<String>('motivoDaPerda'),
      qualificacaoConcluida: safeGet<bool>('qualificacaoConcluida'),
      redFlag: safeGet<String>('redFlag'),
      faseLDF: safeGet<String>('faseLDF'),
      ultimaListaCicloName: safeGet<String>('ultimaListaCicloName'),
      dataContacto: safeGet<String>('dataContacto'),
      dataReuniao: safeGet<String>('dataReuniao'),
      dataProposta: safeGet<String>('dataProposta'),
      dataFecho: safeGet<String>('dataFecho'),
      dataUltimaAtualizacaoFase: safeGet<String>('dataUltimaAtualizacaoFase'),
      backOffice: safeGet<String>('backOffice'),
      cicloDoGanhoName: safeGet<String>('cicloDoGanhoName'),
      // --- End Parse Added Fields ---

      // Parse Files
      files:
          fileList
              .map((f) => SalesforceFile.fromJson(f as Map<String, dynamic>))
              .toList(),
    );
  }

  // Add equality and hashCode (Optional but recommended)
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DetailedSalesforceOpportunity &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          accountId == other.accountId &&
          accountName == other.accountName &&
          resellerSalesforceId == other.resellerSalesforceId &&
          resellerName == other.resellerName &&
          nifC == other.nifC &&
          faseC == other.faseC &&
          createdDate == other.createdDate &&
          dataDePrevisaoDeFechoC == other.dataDePrevisaoDeFechoC &&
          dataDeCriacaoDaOportunidadeC == other.dataDeCriacaoDaOportunidadeC &&
          tipoDeOportunidadeC == other.tipoDeOportunidadeC &&
          segmentoDeClienteC == other.segmentoDeClienteC &&
          soluOC == other.soluOC &&
          listEquals(proposals, other.proposals) && // Use listEquals
          // -- Added --
          ownerName == other.ownerName &&
          observacoes == other.observacoes &&
          motivoDaPerda == other.motivoDaPerda &&
          qualificacaoConcluida == other.qualificacaoConcluida &&
          redFlag == other.redFlag &&
          faseLDF == other.faseLDF &&
          ultimaListaCicloName == other.ultimaListaCicloName &&
          dataContacto == other.dataContacto &&
          dataReuniao == other.dataReuniao &&
          dataProposta == other.dataProposta &&
          dataFecho == other.dataFecho &&
          dataUltimaAtualizacaoFase == other.dataUltimaAtualizacaoFase &&
          backOffice == other.backOffice &&
          cicloDoGanhoName == other.cicloDoGanhoName &&
          listEquals(files, other.files); // Use listEquals
  // -- End Added --

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      accountId.hashCode ^
      accountName.hashCode ^
      resellerSalesforceId.hashCode ^
      resellerName.hashCode ^
      nifC.hashCode ^
      faseC.hashCode ^
      createdDate.hashCode ^
      dataDePrevisaoDeFechoC.hashCode ^
      dataDeCriacaoDaOportunidadeC.hashCode ^
      tipoDeOportunidadeC.hashCode ^
      segmentoDeClienteC.hashCode ^
      soluOC.hashCode ^
      Object.hashAll(proposals) ^ // Use Object.hashAll
      // -- Added --
      ownerName.hashCode ^
      observacoes.hashCode ^
      motivoDaPerda.hashCode ^
      qualificacaoConcluida.hashCode ^
      redFlag.hashCode ^
      faseLDF.hashCode ^
      ultimaListaCicloName.hashCode ^
      dataContacto.hashCode ^
      dataReuniao.hashCode ^
      dataProposta.hashCode ^
      dataFecho.hashCode ^
      dataUltimaAtualizacaoFase.hashCode ^
      backOffice.hashCode ^
      cicloDoGanhoName.hashCode ^
      Object.hashAll(files); // Use Object.hashAll
  // -- End Added --

  // Add toString for debugging
  @override
  String toString() {
    // Truncate long lists for brevity
    final proposalsString =
        proposals.length > 3
            ? '${proposals.sublist(0, 3)}...'
            : proposals.toString();
    final filesString =
        files.length > 3 ? '${files.sublist(0, 3)}...' : files.toString();
    return 'DetailedSalesforceOpportunity{\n'
        '  id: $id, name: $name,\n'
        '  accountId: $accountId, accountName: $accountName,\n'
        '  resellerSalesforceId: $resellerSalesforceId, resellerName: $resellerName,\n'
        '  nifC: $nifC, faseC: $faseC, createdDate: $createdDate,\n'
        '  dataDePrevisaoDeFechoC: $dataDePrevisaoDeFechoC, dataDeCriacaoDaOportunidadeC: $dataDeCriacaoDaOportunidadeC,\n'
        '  tipoDeOportunidadeC: $tipoDeOportunidadeC, segmentoDeClienteC: $segmentoDeClienteC, soluOC: $soluOC,\n'
        '  ownerName: $ownerName, observacoes: ${observacoes?.substring(0, (observacoes?.length ?? 0) > 50 ? 50 : observacoes?.length ?? 0)}..., motivoDaPerda: $motivoDaPerda,\n' // Truncate observations
        '  qualificacaoConcluida: $qualificacaoConcluida, redFlag: $redFlag, faseLDF: $faseLDF,\n'
        '  ultimaListaCicloName: $ultimaListaCicloName, dataContacto: $dataContacto, dataReuniao: $dataReuniao,\n'
        '  dataProposta: $dataProposta, dataFecho: $dataFecho, dataUltimaAtualizacaoFase: $dataUltimaAtualizacaoFase,\n'
        '  backOffice: $backOffice, cicloDoGanhoName: $cicloDoGanhoName,\n'
        '  proposals: $proposalsString,\n'
        '  files: $filesString\n'
        '}';
  }

  // Add toJson method
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'accountName': accountName,
      'accountId': accountId,
      'resellerName': resellerName,
      'resellerSalesforceId': resellerSalesforceId,
      'nifC': nifC,
      'faseC': faseC,
      'createdDate': createdDate,
      'tipoDeOportunidadeC': tipoDeOportunidadeC,
      'segmentoDeClienteC': segmentoDeClienteC,
      'soluOC': soluOC,
      'dataDePrevisaoDeFechoC': dataDePrevisaoDeFechoC,
      'dataDeCriacaoDaOportunidadeC': dataDeCriacaoDaOportunidadeC,
      'proposals':
          proposals
              .map((p) => p.toJson())
              .toList(), // Assuming Proposal has toJson
      'ownerName': ownerName,
      'observacoes': observacoes,
      'motivoDaPerda': motivoDaPerda,
      'qualificacaoConcluida': qualificacaoConcluida,
      'redFlag': redFlag,
      'faseLDF': faseLDF,
      'ultimaListaCicloName': ultimaListaCicloName,
      'dataContacto': dataContacto,
      'dataReuniao': dataReuniao,
      'dataProposta': dataProposta,
      'dataFecho': dataFecho,
      'dataUltimaAtualizacaoFase': dataUltimaAtualizacaoFase,
      'backOffice': backOffice,
      'cicloDoGanhoName': cicloDoGanhoName,
      'files':
          files.map((f) => f.toJson()).toList(), // Assuming File has toJson
    };
  }

  // Add copyWith method
  DetailedSalesforceOpportunity copyWith({
    String? id,
    String? name,
    String? accountName,
    String? accountId,
    String? resellerName,
    String? resellerSalesforceId,
    String? nifC,
    String? faseC,
    String? createdDate,
    String? tipoDeOportunidadeC,
    String? segmentoDeClienteC,
    String? soluOC,
    String? dataDePrevisaoDeFechoC,
    String? dataDeCriacaoDaOportunidadeC,
    List<SalesforceProposal>? proposals,
    String? ownerName,
    String? observacoes,
    String? motivoDaPerda,
    bool? qualificacaoConcluida,
    String? redFlag,
    String? faseLDF,
    String? ultimaListaCicloName,
    String? dataContacto,
    String? dataReuniao,
    String? dataProposta,
    String? dataFecho,
    String? dataUltimaAtualizacaoFase,
    String? backOffice,
    String? cicloDoGanhoName,
    List<SalesforceFile>? files,
  }) {
    return DetailedSalesforceOpportunity(
      id: id ?? this.id,
      name: name ?? this.name,
      accountName: accountName ?? this.accountName,
      accountId: accountId ?? this.accountId,
      resellerName: resellerName ?? this.resellerName,
      resellerSalesforceId: resellerSalesforceId ?? this.resellerSalesforceId,
      nifC: nifC ?? this.nifC,
      faseC: faseC ?? this.faseC,
      createdDate: createdDate ?? this.createdDate,
      tipoDeOportunidadeC: tipoDeOportunidadeC ?? this.tipoDeOportunidadeC,
      segmentoDeClienteC: segmentoDeClienteC ?? this.segmentoDeClienteC,
      soluOC: soluOC ?? this.soluOC,
      dataDePrevisaoDeFechoC:
          dataDePrevisaoDeFechoC ?? this.dataDePrevisaoDeFechoC,
      dataDeCriacaoDaOportunidadeC:
          dataDeCriacaoDaOportunidadeC ?? this.dataDeCriacaoDaOportunidadeC,
      proposals: proposals ?? this.proposals,
      ownerName: ownerName ?? this.ownerName,
      observacoes: observacoes ?? this.observacoes,
      motivoDaPerda: motivoDaPerda ?? this.motivoDaPerda,
      qualificacaoConcluida:
          qualificacaoConcluida ?? this.qualificacaoConcluida,
      redFlag: redFlag ?? this.redFlag,
      faseLDF: faseLDF ?? this.faseLDF,
      ultimaListaCicloName: ultimaListaCicloName ?? this.ultimaListaCicloName,
      dataContacto: dataContacto ?? this.dataContacto,
      dataReuniao: dataReuniao ?? this.dataReuniao,
      dataProposta: dataProposta ?? this.dataProposta,
      dataFecho: dataFecho ?? this.dataFecho,
      dataUltimaAtualizacaoFase:
          dataUltimaAtualizacaoFase ?? this.dataUltimaAtualizacaoFase,
      backOffice: backOffice ?? this.backOffice,
      cicloDoGanhoName: cicloDoGanhoName ?? this.cicloDoGanhoName,
      files: files ?? this.files,
    );
  }
}
