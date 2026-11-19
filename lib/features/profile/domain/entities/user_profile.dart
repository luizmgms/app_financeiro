import 'package:equatable/equatable.dart';
import '../../../../core/constants/app_constants.dart';

/// Perfil e preferências financeiras do usuário armazenadas no Cloud Firestore.
class UserProfile extends Equatable {
  const UserProfile({
    required this.uid,
    required this.displayName,
    required this.email,
    this.photoUrl,
    this.defaultCurrency = AppConstants.defaultCurrency,
    this.localeCode = AppConstants.defaultLocale,
    this.monthStartDay = AppConstants.defaultMonthStartDay,
    this.reminderDaysBefore = 3,
    this.notificationsEnabled = true,
    this.pushNotificationsEnabled = false,
    required this.createdAt,
    required this.updatedAt,
  });

  final String uid;
  final String displayName;
  final String email;
  final String? photoUrl;
  final String defaultCurrency;
  final String localeCode;
  final int monthStartDay;
  final int reminderDaysBefore;
  final bool notificationsEnabled;
  final bool pushNotificationsEnabled;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserProfile copyWith({
    String? displayName,
    String? email,
    String? photoUrl,
    String? defaultCurrency,
    String? localeCode,
    int? monthStartDay,
    int? reminderDaysBefore,
    bool? notificationsEnabled,
    bool? pushNotificationsEnabled,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      uid: uid,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      defaultCurrency: defaultCurrency ?? this.defaultCurrency,
      localeCode: localeCode ?? this.localeCode,
      monthStartDay: monthStartDay ?? this.monthStartDay,
      reminderDaysBefore: reminderDaysBefore ?? this.reminderDaysBefore,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      pushNotificationsEnabled:
          pushNotificationsEnabled ?? this.pushNotificationsEnabled,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        uid,
        displayName,
        email,
        photoUrl,
        defaultCurrency,
        localeCode,
        monthStartDay,
        reminderDaysBefore,
        notificationsEnabled,
        pushNotificationsEnabled,
        createdAt,
        updatedAt,
      ];
}
