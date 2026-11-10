import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages solo student authentication, setup/onboarding status, profile identity,
/// dynamic avatar initials, and master vault PIN.
class AuthController extends ChangeNotifier {
  static const _keyOnboarded = 'isOnboarded';
  static const _keySetupComplete = 'is_setup_complete';
  static const _keyUserName = 'userName';
  static const _keyUniversity = 'userUniversity';
  static const _keyEmail = 'userEmail';
  static const _keyStanding = 'userStanding';
  static const _keyWorkStudy = 'userWorkStudy';
  static const _keyBiometric = 'userBiometric';
  static const _keyMasterPin = 'masterVaultPin';
  static const _keyBudgetCap = 'userBudgetCap';
  static const _keySafeBuffer = 'userSafeBuffer';

  bool _isOnboarded = false;
  String _userName = '';
  String _university = '';
  String _email = '';
  String _standing = '';
  bool _hasWorkStudy = true;
  bool _isBiometricEnabled = true;
  String _masterPin = '';
  double _monthlyBudgetCap = 0.0;
  double _safeBufferTarget = 0.0;
  bool _isInitialized = false;

  bool get isOnboarded => _isOnboarded;
  bool get isSetupComplete => _isOnboarded;
  String get userName => _userName;
  String get studentName => _userName;
  String get university => _university;
  String get email => _email;
  String get standing => _standing;
  bool get hasWorkStudy => _hasWorkStudy;
  bool get isBiometricEnabled => _isBiometricEnabled;
  String get masterPin => _masterPin;
  double get monthlyBudgetCap => _monthlyBudgetCap;
  double get safeBufferTarget => _safeBufferTarget;
  bool get isInitialized => _isInitialized;

  /// Dynamic 2-letter uppercase initials derived from setup name for the header badge.
  String get avatarInitials {
    final trimmed = _userName.trim();
    if (trimmed.isEmpty) return 'ST';
    final parts =
        trimmed.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    if (trimmed.length >= 2) {
      return trimmed.substring(0, 2).toUpperCase();
    }
    return trimmed.substring(0, 1).toUpperCase();
  }

  /// Compatibility getter for legacy flatName references
  String get flatName =>
      _university.isNotEmpty ? _university : 'StudentHub Studio';

  /// Loads persisted onboarding state and student profile from SharedPreferences.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _isOnboarded = (prefs.getBool(_keySetupComplete) ?? false) ||
        (prefs.getBool(_keyOnboarded) ?? false);
    _userName = prefs.getString(_keyUserName) ?? '';
    _university = prefs.getString(_keyUniversity) ??
        prefs.getString('userFlatName') ??
        '';
    _email = prefs.getString(_keyEmail) ?? '';
    _standing = prefs.getString(_keyStanding) ?? '';
    _hasWorkStudy = prefs.getBool(_keyWorkStudy) ?? true;
    _isBiometricEnabled = prefs.getBool(_keyBiometric) ?? true;
    _masterPin = prefs.getString(_keyMasterPin) ?? '';
    _monthlyBudgetCap = prefs.getDouble(_keyBudgetCap) ?? 0.0;
    _safeBufferTarget = prefs.getDouble(_keySafeBuffer) ?? 0.0;
    _isInitialized = true;
    notifyListeners();
  }

  /// Completes solo student onboarding/setup, saving profile and budget cap to SharedPreferences.
  Future<void> completeOnboarding({
    required String name,
    required String pin,
    String university = '',
    String flatName = '',
    String standing = 'Junior',
    bool hasWorkStudy = true,
    bool isBiometricEnabled = true,
    double budgetCap = 250.0,
    double safeBuffer = 50.0,
    String email = '',
  }) async {
    final resolvedUni = university.isNotEmpty ? university : flatName;
    final sanitizedCap =
        (budgetCap.isFinite ? budgetCap : 0.0).clamp(0.0, double.infinity);
    final sanitizedBuffer =
        (safeBuffer.isFinite ? safeBuffer : 0.0).clamp(0.0, double.infinity);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserName, name);
    await prefs.setString(_keyUniversity, resolvedUni);
    await prefs.setString(_keyEmail, email);
    await prefs.setString(_keyStanding, standing);
    await prefs.setBool(_keyWorkStudy, hasWorkStudy);
    await prefs.setBool(_keyBiometric, isBiometricEnabled);
    await prefs.setString(_keyMasterPin, pin);
    await prefs.setDouble(_keyBudgetCap, sanitizedCap);
    await prefs.setDouble(_keySafeBuffer, sanitizedBuffer);
    await prefs.setBool(_keyOnboarded, true);
    await prefs.setBool(_keySetupComplete, true);

    _userName = name;
    _university = resolvedUni;
    _email = email;
    _standing = standing;
    _hasWorkStudy = hasWorkStudy;
    _isBiometricEnabled = isBiometricEnabled;
    _masterPin = pin;
    _monthlyBudgetCap = sanitizedCap;
    _safeBufferTarget = sanitizedBuffer;
    _isOnboarded = true;
    notifyListeners();
  }

  /// Updates personal profile information (name, university, email).
  Future<void> updateProfile({
    required String name,
    String? university,
    String? email,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    _userName = name.trim();
    await prefs.setString(_keyUserName, _userName);

    if (university != null) {
      _university = university.trim();
      await prefs.setString(_keyUniversity, _university);
    }
    if (email != null) {
      _email = email.trim();
      await prefs.setString(_keyEmail, _email);
    }
    notifyListeners();
  }

  /// Updates personal budget allowance cap and safe buffer target.
  Future<void> updateBudgetCap(double cap, double buffer) async {
    final sanitizedCap = (cap.isFinite ? cap : 0.0).clamp(0.0, double.infinity);
    final sanitizedBuffer =
        (buffer.isFinite ? buffer : 0.0).clamp(0.0, double.infinity);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyBudgetCap, sanitizedCap);
    await prefs.setDouble(_keySafeBuffer, sanitizedBuffer);
    _monthlyBudgetCap = sanitizedCap;
    _safeBufferTarget = sanitizedBuffer;
    notifyListeners();
  }

  /// Verifies a 4-digit input PIN against the stored master vault passcode.
  bool verifyPin(String inputPin) {
    if (_masterPin.isEmpty) return true;
    return _masterPin == inputPin.trim();
  }

  /// Resets onboarding for testing / clean zero-base demonstration.
  Future<void> resetOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _isOnboarded = false;
    _userName = '';
    _university = '';
    _email = '';
    _standing = '';
    _hasWorkStudy = true;
    _isBiometricEnabled = true;
    _masterPin = '';
    _monthlyBudgetCap = 0.0;
    _safeBufferTarget = 0.0;
    notifyListeners();
  }

  /// Completely resets all app auth credentials and persisted data.
  Future<void> resetApp() async {
    await resetOnboarding();
  }
}
