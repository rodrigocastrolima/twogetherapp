// dart format width=80
// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'salesforce_proposal.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SalesforceProposal {

@JsonKey(name: 'Id') String get id;@JsonKey(name: 'Name') String get name;@JsonKey(name: 'Valor_Investimento_Solar__c') double? get valorInvestimentoSolar;@JsonKey(name: 'Data_de_Criacao__c') String get dataDeCriacao;// Keep as String for initial parsing
@JsonKey(name: 'Data_de_Validade__c') String get dataDeValidade;// Keep as String for initial parsing
@JsonKey(name: 'Status__c') String get status;// Matches the aggregated commission field from the Cloud Function
 double? get totalComissaoRetail;
/// Create a copy of SalesforceProposal
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SalesforceProposalCopyWith<SalesforceProposal> get copyWith => _$SalesforceProposalCopyWithImpl<SalesforceProposal>(this as SalesforceProposal, _$identity);

  /// Serializes this SalesforceProposal to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SalesforceProposal&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.valorInvestimentoSolar, valorInvestimentoSolar) || other.valorInvestimentoSolar == valorInvestimentoSolar)&&(identical(other.dataDeCriacao, dataDeCriacao) || other.dataDeCriacao == dataDeCriacao)&&(identical(other.dataDeValidade, dataDeValidade) || other.dataDeValidade == dataDeValidade)&&(identical(other.status, status) || other.status == status)&&(identical(other.totalComissaoRetail, totalComissaoRetail) || other.totalComissaoRetail == totalComissaoRetail));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,valorInvestimentoSolar,dataDeCriacao,dataDeValidade,status,totalComissaoRetail);

@override
String toString() {
  return 'SalesforceProposal(id: $id, name: $name, valorInvestimentoSolar: $valorInvestimentoSolar, dataDeCriacao: $dataDeCriacao, dataDeValidade: $dataDeValidade, status: $status, totalComissaoRetail: $totalComissaoRetail)';
}


}

/// @nodoc
abstract mixin class $SalesforceProposalCopyWith<$Res>  {
  factory $SalesforceProposalCopyWith(SalesforceProposal value, $Res Function(SalesforceProposal) _then) = _$SalesforceProposalCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'Id') String id,@JsonKey(name: 'Name') String name,@JsonKey(name: 'Valor_Investimento_Solar__c') double? valorInvestimentoSolar,@JsonKey(name: 'Data_de_Criacao__c') String dataDeCriacao,@JsonKey(name: 'Data_de_Validade__c') String dataDeValidade,@JsonKey(name: 'Status__c') String status, double? totalComissaoRetail
});




}
/// @nodoc
class _$SalesforceProposalCopyWithImpl<$Res>
    implements $SalesforceProposalCopyWith<$Res> {
  _$SalesforceProposalCopyWithImpl(this._self, this._then);

  final SalesforceProposal _self;
  final $Res Function(SalesforceProposal) _then;

/// Create a copy of SalesforceProposal
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? valorInvestimentoSolar = freezed,Object? dataDeCriacao = null,Object? dataDeValidade = null,Object? status = null,Object? totalComissaoRetail = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,valorInvestimentoSolar: freezed == valorInvestimentoSolar ? _self.valorInvestimentoSolar : valorInvestimentoSolar // ignore: cast_nullable_to_non_nullable
as double?,dataDeCriacao: null == dataDeCriacao ? _self.dataDeCriacao : dataDeCriacao // ignore: cast_nullable_to_non_nullable
as String,dataDeValidade: null == dataDeValidade ? _self.dataDeValidade : dataDeValidade // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,totalComissaoRetail: freezed == totalComissaoRetail ? _self.totalComissaoRetail : totalComissaoRetail // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}

}


/// @nodoc
@JsonSerializable()

class _SalesforceProposal implements SalesforceProposal {
  const _SalesforceProposal({@JsonKey(name: 'Id') required this.id, @JsonKey(name: 'Name') required this.name, @JsonKey(name: 'Valor_Investimento_Solar__c') this.valorInvestimentoSolar, @JsonKey(name: 'Data_de_Criacao__c') required this.dataDeCriacao, @JsonKey(name: 'Data_de_Validade__c') required this.dataDeValidade, @JsonKey(name: 'Status__c') required this.status, this.totalComissaoRetail});
  factory _SalesforceProposal.fromJson(Map<String, dynamic> json) => _$SalesforceProposalFromJson(json);

@override@JsonKey(name: 'Id') final  String id;
@override@JsonKey(name: 'Name') final  String name;
@override@JsonKey(name: 'Valor_Investimento_Solar__c') final  double? valorInvestimentoSolar;
@override@JsonKey(name: 'Data_de_Criacao__c') final  String dataDeCriacao;
// Keep as String for initial parsing
@override@JsonKey(name: 'Data_de_Validade__c') final  String dataDeValidade;
// Keep as String for initial parsing
@override@JsonKey(name: 'Status__c') final  String status;
// Matches the aggregated commission field from the Cloud Function
@override final  double? totalComissaoRetail;

/// Create a copy of SalesforceProposal
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SalesforceProposalCopyWith<_SalesforceProposal> get copyWith => __$SalesforceProposalCopyWithImpl<_SalesforceProposal>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SalesforceProposalToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SalesforceProposal&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.valorInvestimentoSolar, valorInvestimentoSolar) || other.valorInvestimentoSolar == valorInvestimentoSolar)&&(identical(other.dataDeCriacao, dataDeCriacao) || other.dataDeCriacao == dataDeCriacao)&&(identical(other.dataDeValidade, dataDeValidade) || other.dataDeValidade == dataDeValidade)&&(identical(other.status, status) || other.status == status)&&(identical(other.totalComissaoRetail, totalComissaoRetail) || other.totalComissaoRetail == totalComissaoRetail));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,valorInvestimentoSolar,dataDeCriacao,dataDeValidade,status,totalComissaoRetail);

@override
String toString() {
  return 'SalesforceProposal(id: $id, name: $name, valorInvestimentoSolar: $valorInvestimentoSolar, dataDeCriacao: $dataDeCriacao, dataDeValidade: $dataDeValidade, status: $status, totalComissaoRetail: $totalComissaoRetail)';
}


}

/// @nodoc
abstract mixin class _$SalesforceProposalCopyWith<$Res> implements $SalesforceProposalCopyWith<$Res> {
  factory _$SalesforceProposalCopyWith(_SalesforceProposal value, $Res Function(_SalesforceProposal) _then) = __$SalesforceProposalCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'Id') String id,@JsonKey(name: 'Name') String name,@JsonKey(name: 'Valor_Investimento_Solar__c') double? valorInvestimentoSolar,@JsonKey(name: 'Data_de_Criacao__c') String dataDeCriacao,@JsonKey(name: 'Data_de_Validade__c') String dataDeValidade,@JsonKey(name: 'Status__c') String status, double? totalComissaoRetail
});




}
/// @nodoc
class __$SalesforceProposalCopyWithImpl<$Res>
    implements _$SalesforceProposalCopyWith<$Res> {
  __$SalesforceProposalCopyWithImpl(this._self, this._then);

  final _SalesforceProposal _self;
  final $Res Function(_SalesforceProposal) _then;

/// Create a copy of SalesforceProposal
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? valorInvestimentoSolar = freezed,Object? dataDeCriacao = null,Object? dataDeValidade = null,Object? status = null,Object? totalComissaoRetail = freezed,}) {
  return _then(_SalesforceProposal(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,valorInvestimentoSolar: freezed == valorInvestimentoSolar ? _self.valorInvestimentoSolar : valorInvestimentoSolar // ignore: cast_nullable_to_non_nullable
as double?,dataDeCriacao: null == dataDeCriacao ? _self.dataDeCriacao : dataDeCriacao // ignore: cast_nullable_to_non_nullable
as String,dataDeValidade: null == dataDeValidade ? _self.dataDeValidade : dataDeValidade // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,totalComissaoRetail: freezed == totalComissaoRetail ? _self.totalComissaoRetail : totalComissaoRetail // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}


}

// dart format on
