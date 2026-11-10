import 'package:flutter/material.dart';
import '../services/storage_service.dart';

/// Holds the current user's profile data and onboarding state.
class UserProfileController extends ChangeNotifier {
  final StorageService _storage;

  UserProfileController(this._storage);

  String _name = '';
  String _email = '';
  String _vaultPin = '';
  bool _isOnboarded = false;

  String get name => _name;
  String get email => _email;
  String get vaultPin => _vaultPin;
  bool get isOnboarded => _isOnboarded;

  /// Load persisted values on startup.
  Future<void> init() async {
    _isOnboarded = await _storage.isOnboarded();
    if (_isOnboarded) {
      _name = await _storage.getUserName() ?? 'Alex';
      _email = await _storage.getUserEmail() ?? '';
      _vaultPin = await _storage.getVaultPin() ?? '';
    }
    notifyListeners();
  }

  /// Persist the profile, mark onboarding complete, and notify.
  Future<void> completeOnboarding({
    required String name,
    required String email,
    required String pin,
  }) async {
    await _storage.saveProfile(name: name, email: email, pin: pin);
    _name = name;
    _email = email;
    _vaultPin = pin;
    _isOnboarded = true;
    notifyListeners();
  }

  /// Reset for testing / dev.
  Future<void> resetOnboarding() async {
    await _storage.clearAll();
    _name = '';
    _email = '';
    _vaultPin = '';
    _isOnboarded = false;
    notifyListeners();
  }
}
