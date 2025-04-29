// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'salesforce_proposal.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

SalesforceProposal _$SalesforceProposalFromJson(Map<String, dynamic> json) {
  return _SalesforceProposal.fromJson(json);
}

/// @nodoc
mixin _$SalesforceProposal {
  @JsonKey(name: 'Id')
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'Name')
  String get name => throw _privateConstructorUsedError;
  @JsonKey(name: 'Valor_Investimento_Solar__c')
  double? get valorInvestimentoSolar => throw _privateConstructorUsedError;
  @JsonKey(name: 'Data_de_Validade__c')
  String get dataDeValidade => throw _privateConstructorUsedError; // Keep as String for initial parsing
  @JsonKey(name: 'Status__c')
  String get status => throw _privateConstructorUsedError; // Matches the aggregated commission field from the Cloud Function
  double? get totalComissaoRetail => throw _privateConstructorUsedError;

  /// Serializes this SalesforceProposal to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SalesforceProposal
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SalesforceProposalCopyWith<SalesforceProposal> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SalesforceProposalCopyWith<$Res> {
  factory $SalesforceProposalCopyWith(
    SalesforceProposal value,
    $Res Function(SalesforceProposal) then,
  ) = _$SalesforceProposalCopyWithImpl<$Res, SalesforceProposal>;
  @useResult
  $Res call({
    @JsonKey(name: 'Id') String id,
    @JsonKey(name: 'Name') String name,
    @JsonKey(name: 'Valor_Investimento_Solar__c')
    double? valorInvestimentoSolar,
    @JsonKey(name: 'Data_de_Validade__c') String dataDeValidade,
    @JsonKey(name: 'Status__c') String status,
    double? totalComissaoRetail,
  });
}

/// @nodoc
class _$SalesforceProposalCopyWithImpl<$Res, $Val extends SalesforceProposal>
    implements $SalesforceProposalCopyWith<$Res> {
  _$SalesforceProposalCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SalesforceProposal
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? valorInvestimentoSolar = freezed,
    Object? dataDeValidade = null,
    Object? status = null,
    Object? totalComissaoRetail = freezed,
  }) {
    return _then(
      _value.copyWith(
            id:
                null == id
                    ? _value.id
                    : id // ignore: cast_nullable_to_non_nullable
                        as String,
            name:
                null == name
                    ? _value.name
                    : name // ignore: cast_nullable_to_non_nullable
                        as String,
            valorInvestimentoSolar:
                freezed == valorInvestimentoSolar
                    ? _value.valorInvestimentoSolar
                    : valorInvestimentoSolar // ignore: cast_nullable_to_non_nullable
                        as double?,
            dataDeValidade:
                null == dataDeValidade
                    ? _value.dataDeValidade
                    : dataDeValidade // ignore: cast_nullable_to_non_nullable
                        as String,
            status:
                null == status
                    ? _value.status
                    : status // ignore: cast_nullable_to_non_nullable
                        as String,
            totalComissaoRetail:
                freezed == totalComissaoRetail
                    ? _value.totalComissaoRetail
                    : totalComissaoRetail // ignore: cast_nullable_to_non_nullable
                        as double?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$SalesforceProposalImplCopyWith<$Res>
    implements $SalesforceProposalCopyWith<$Res> {
  factory _$$SalesforceProposalImplCopyWith(
    _$SalesforceProposalImpl value,
    $Res Function(_$SalesforceProposalImpl) then,
  ) = __$$SalesforceProposalImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(name: 'Id') String id,
    @JsonKey(name: 'Name') String name,
    @JsonKey(name: 'Valor_Investimento_Solar__c')
    double? valorInvestimentoSolar,
    @JsonKey(name: 'Data_de_Validade__c') String dataDeValidade,
    @JsonKey(name: 'Status__c') String status,
    double? totalComissaoRetail,
  });
}

/// @nodoc
class __$$SalesforceProposalImplCopyWithImpl<$Res>
    extends _$SalesforceProposalCopyWithImpl<$Res, _$SalesforceProposalImpl>
    implements _$$SalesforceProposalImplCopyWith<$Res> {
  __$$SalesforceProposalImplCopyWithImpl(
    _$SalesforceProposalImpl _value,
    $Res Function(_$SalesforceProposalImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SalesforceProposal
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? valorInvestimentoSolar = freezed,
    Object? dataDeValidade = null,
    Object? status = null,
    Object? totalComissaoRetail = freezed,
  }) {
    return _then(
      _$SalesforceProposalImpl(
        id:
            null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                    as String,
        name:
            null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                    as String,
        valorInvestimentoSolar:
            freezed == valorInvestimentoSolar
                ? _value.valorInvestimentoSolar
                : valorInvestimentoSolar // ignore: cast_nullable_to_non_nullable
                    as double?,
        dataDeValidade:
            null == dataDeValidade
                ? _value.dataDeValidade
                : dataDeValidade // ignore: cast_nullable_to_non_nullable
                    as String,
        status:
            null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                    as String,
        totalComissaoRetail:
            freezed == totalComissaoRetail
                ? _value.totalComissaoRetail
                : totalComissaoRetail // ignore: cast_nullable_to_non_nullable
                    as double?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$SalesforceProposalImpl implements _SalesforceProposal {
  const _$SalesforceProposalImpl({
    @JsonKey(name: 'Id') required this.id,
    @JsonKey(name: 'Name') required this.name,
    @JsonKey(name: 'Valor_Investimento_Solar__c') this.valorInvestimentoSolar,
    @JsonKey(name: 'Data_de_Validade__c') required this.dataDeValidade,
    @JsonKey(name: 'Status__c') required this.status,
    this.totalComissaoRetail,
  });

  factory _$SalesforceProposalImpl.fromJson(Map<String, dynamic> json) =>
      _$$SalesforceProposalImplFromJson(json);

  @override
  @JsonKey(name: 'Id')
  final String id;
  @override
  @JsonKey(name: 'Name')
  final String name;
  @override
  @JsonKey(name: 'Valor_Investimento_Solar__c')
  final double? valorInvestimentoSolar;
  @override
  @JsonKey(name: 'Data_de_Validade__c')
  final String dataDeValidade;
  // Keep as String for initial parsing
  @override
  @JsonKey(name: 'Status__c')
  final String status;
  // Matches the aggregated commission field from the Cloud Function
  @override
  final double? totalComissaoRetail;

  @override
  String toString() {
    return 'SalesforceProposal(id: $id, name: $name, valorInvestimentoSolar: $valorInvestimentoSolar, dataDeValidade: $dataDeValidade, status: $status, totalComissaoRetail: $totalComissaoRetail)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SalesforceProposalImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.valorInvestimentoSolar, valorInvestimentoSolar) ||
                other.valorInvestimentoSolar == valorInvestimentoSolar) &&
            (identical(other.dataDeValidade, dataDeValidade) ||
                other.dataDeValidade == dataDeValidade) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.totalComissaoRetail, totalComissaoRetail) ||
                other.totalComissaoRetail == totalComissaoRetail));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    name,
    valorInvestimentoSolar,
    dataDeValidade,
    status,
    totalComissaoRetail,
  );

  /// Create a copy of SalesforceProposal
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SalesforceProposalImplCopyWith<_$SalesforceProposalImpl> get copyWith =>
      __$$SalesforceProposalImplCopyWithImpl<_$SalesforceProposalImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$SalesforceProposalImplToJson(this);
  }
}

abstract class _SalesforceProposal implements SalesforceProposal {
  const factory _SalesforceProposal({
    @JsonKey(name: 'Id') required final String id,
    @JsonKey(name: 'Name') required final String name,
    @JsonKey(name: 'Valor_Investimento_Solar__c')
    final double? valorInvestimentoSolar,
    @JsonKey(name: 'Data_de_Validade__c') required final String dataDeValidade,
    @JsonKey(name: 'Status__c') required final String status,
    final double? totalComissaoRetail,
  }) = _$SalesforceProposalImpl;

  factory _SalesforceProposal.fromJson(Map<String, dynamic> json) =
      _$SalesforceProposalImpl.fromJson;

  @override
  @JsonKey(name: 'Id')
  String get id;
  @override
  @JsonKey(name: 'Name')
  String get name;
  @override
  @JsonKey(name: 'Valor_Investimento_Solar__c')
  double? get valorInvestimentoSolar;
  @override
  @JsonKey(name: 'Data_de_Validade__c')
  String get dataDeValidade; // Keep as String for initial parsing
  @override
  @JsonKey(name: 'Status__c')
  String get status; // Matches the aggregated commission field from the Cloud Function
  @override
  double? get totalComissaoRetail;

  /// Create a copy of SalesforceProposal
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SalesforceProposalImplCopyWith<_$SalesforceProposalImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
