import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

/// User profile for personalized calorie calculation.
class UserProfile {
  final double weightKg;
  final int age;
  final bool isMale;
  final int maxHR;

  const UserProfile({
    this.weightKg = 70.0,
    this.age = 25,
    this.isMale = true,
    this.maxHR = 190,
  });

  UserProfile copyWith({
    double? weightKg,
    int? age,
    bool? isMale,
    int? maxHR,
  }) {
    return UserProfile(
      weightKg: weightKg ?? this.weightKg,
      age: age ?? this.age,
      isMale: isMale ?? this.isMale,
      maxHR: maxHR ?? this.maxHR,
    );
  }

  Map<String, dynamic> toJson() => {
        'weightKg': weightKg,
        'age': age,
        'isMale': isMale,
        'maxHR': maxHR,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      weightKg: (json['weightKg'] as num?)?.toDouble() ?? 70.0,
      age: json['age'] as int? ?? 25,
      isMale: json['isMale'] as bool? ?? true,
      maxHR: json['maxHR'] as int? ?? 190,
    );
  }
}

/// Hive-backed persistence for user profile.
class UserProfileRepository {
  static const String _boxName = 'user_profile';
  static const String _key = 'profile';
  static const String _onboardedKey = 'onboarded';
  late Box<String> _box;

  Future<void> init() async {
    _box = await Hive.openBox<String>(_boxName);
  }

  UserProfile getProfile() {
    final json = _box.get(_key);
    if (json == null) return const UserProfile();
    try {
      return UserProfile.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } catch (_) {
      return const UserProfile();
    }
  }

  Future<void> saveProfile(UserProfile profile) async {
    await _box.put(_key, jsonEncode(profile.toJson()));
  }

  bool get isOnboarded => _box.get(_onboardedKey) == 'true';

  Future<void> setOnboarded() async {
    await _box.put(_onboardedKey, 'true');
  }
}
