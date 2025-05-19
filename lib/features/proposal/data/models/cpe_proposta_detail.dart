class CpePropostaDetail {
  final String? id;
  final String? name;
  final String? statusC;
  final String? consumoOuPotenciaPicoC;
  final String? fidelizacaoAnosC;
  final String? margemComercialC;
  final String? agenteRetailC;
  final String? agenteRetailName;
  final String? responsavelNegocioRetailC;
  final String? responsavelNegocioExclusivoC;
  final String? gestorDeRevendaC;
  final String? cicloDeAtivacaoC;
  final String? cicloDeAtivacaoName;
  final String? comissaoRetailC;
  final String? notaInformativaC;
  final String? pagamentoDaFacturaRetailC;
  final String? facturaRetailC;
  final String? visitaTecnicaC;
  final CpeInfo? cpe;
  final List<CpePropostaFile> files;

  CpePropostaDetail({
    this.id,
    this.name,
    this.statusC,
    this.consumoOuPotenciaPicoC,
    this.fidelizacaoAnosC,
    this.margemComercialC,
    this.agenteRetailC,
    this.agenteRetailName,
    this.responsavelNegocioRetailC,
    this.responsavelNegocioExclusivoC,
    this.gestorDeRevendaC,
    this.cicloDeAtivacaoC,
    this.cicloDeAtivacaoName,
    this.comissaoRetailC,
    this.notaInformativaC,
    this.pagamentoDaFacturaRetailC,
    this.facturaRetailC,
    this.visitaTecnicaC,
    this.cpe,
    this.files = const [],
  });

  factory CpePropostaDetail.fromJson(Map<String, dynamic> json) {
    return CpePropostaDetail(
      id: json['id'] as String?,
      name: json['name'] as String?,
      statusC: json['statusC'] as String?,
      consumoOuPotenciaPicoC: json['consumoOuPotenciaPicoC']?.toString(),
      fidelizacaoAnosC: json['fidelizacaoAnosC']?.toString(),
      margemComercialC: json['margemComercialC']?.toString(),
      agenteRetailC: json['agenteRetailC'] as String?,
      agenteRetailName: json['agenteRetailName'] as String?,
      responsavelNegocioRetailC: json['responsavelNegocioRetailC'] as String?,
      responsavelNegocioExclusivoC: json['responsavelNegocioExclusivoC'] as String?,
      gestorDeRevendaC: json['gestorDeRevendaC'] as String?,
      cicloDeAtivacaoC: json['cicloDeAtivacaoC'] as String?,
      cicloDeAtivacaoName: json['cicloDeAtivacaoName'] as String?,
      comissaoRetailC: json['comissaoRetailC']?.toString(),
      notaInformativaC: json['notaInformativaC'] as String?,
      pagamentoDaFacturaRetailC: json['pagamentoDaFacturaRetailC']?.toString(),
      facturaRetailC: json['facturaRetailC'] as String?,
      visitaTecnicaC: json['visitaTecnicaC'] as String?,
      cpe: json['cpe'] != null ? CpeInfo.fromJson(json['cpe'] as Map<String, dynamic>) : null,
      files: (json['files'] as List<dynamic>? ?? []).map((f) => CpePropostaFile.fromJson(f as Map<String, dynamic>)).toList(),
    );
  }
}

class CpeInfo {
  final String? id;
  final String? name;
  final String? entidadeC;
  final String? entidadeName;
  final String? nifC;
  final String? consumoAnualEsperadoKwhC;
  final String? fidelizacaoAnosC;
  final String? solucaoC;

  CpeInfo({
    this.id,
    this.name,
    this.entidadeC,
    this.entidadeName,
    this.nifC,
    this.consumoAnualEsperadoKwhC,
    this.fidelizacaoAnosC,
    this.solucaoC,
  });

  factory CpeInfo.fromJson(Map<String, dynamic> json) {
    return CpeInfo(
      id: json['id'] as String?,
      name: json['name'] as String?,
      entidadeC: json['entidadeC'] as String?,
      entidadeName: json['entidadeName'] as String?,
      nifC: json['nifC'] as String?,
      consumoAnualEsperadoKwhC: json['consumoAnualEsperadoKwhC']?.toString(),
      fidelizacaoAnosC: json['fidelizacaoAnosC']?.toString(),
      solucaoC: json['solucaoC'] as String?,
    );
  }
}

class CpePropostaFile {
  final String? id;
  final String? title;
  final String? fileExtension;
  final String? fileType;
  final String? contentVersionId;

  CpePropostaFile({
    this.id,
    this.title,
    this.fileExtension,
    this.fileType,
    this.contentVersionId,
  });

  factory CpePropostaFile.fromJson(Map<String, dynamic> json) {
    return CpePropostaFile(
      id: json['id'] as String?,
      title: json['title'] as String?,
      fileExtension: json['fileExtension'] as String?,
      fileType: json['fileType'] as String?,
      contentVersionId: json['contentVersionId'] as String?,
    );
  }
} 