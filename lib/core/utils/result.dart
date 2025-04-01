import 'package:equatable/equatable.dart';

import '../error/failures.dart';

sealed class Result<T> extends Equatable {
  const Result();

  @override
  List<Object?> get props => [];

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Error<T>;

  T? get data => isSuccess ? (this as Success<T>).data : null;
  Failure? get error => isFailure ? (this as Error<T>).failure : null;

  R fold<R>(R Function(T) onSuccess, R Function(Failure) onFailure) {
    return switch (this) {
      Success<T>(data: final d) => onSuccess(d),
      Error<T>(failure: final f) => onFailure(f),
    };
  }

  static Result<T> fromException<T>(Exception exception) {
    return Error(UnknownFailure(exception.toString()));
  }
}

final class Success<T> extends Result<T> {
  @override
  final T data;

  const Success(this.data);

  @override
  List<Object?> get props => [data];
}

final class Error<T> extends Result<T> {
  final Failure failure;

  const Error(this.failure);

  @override
  List<Object?> get props => [failure];
}
