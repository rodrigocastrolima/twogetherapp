import 'package:firebase_auth/firebase_auth.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_user.freezed.dart';
part 'app_user.g.dart';

enum UserRole { admin, reseller, unknown }

@freezed
class AppUser with _$AppUser {
  const factory AppUser({
    required String uid,
    required String email,
    required UserRole role,
    String? displayName,
    String? photoURL,
    String? salesforceId,
    @Default(false) bool isFirstLogin,
    @Default(false) bool isEmailVerified,
    @Default({}) Map<String, dynamic> additionalData,
  }) = _AppUser;

  factory AppUser.fromJson(Map<String, dynamic> json) =>
      _$AppUserFromJson(json);

  /// Creates a basic [AppUser] from a Firebase [User] without role information.
  /// Role information needs to be added separately from Firestore data.
  factory AppUser.fromFirebaseUser(
    User user, {
    UserRole role = UserRole.unknown,
    String? salesforceId,
  }) {
    return AppUser(
      uid: user.uid,
      email: user.email ?? '',
      displayName: user.displayName,
      photoURL: user.photoURL,
      isEmailVerified: user.emailVerified,
      role: role,
      salesforceId: salesforceId,
    );
  }
}
