import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/auth_service.dart';
import '../api/client.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  bool _isLoggedIn = false;
  bool _isLoading = false;
  Uint8List? _captchaImage;
  bool _needCaptcha = false;
  
  bool _rememberPassword = false;
  bool _autoLogin = false;
  String _savedUsername = "";
  String _savedPassword = "";
  String _currentUsername = "";
  bool _isOfflineMode = false;

  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;
  Uint8List? get captchaImage => _captchaImage;
  bool get needCaptcha => _needCaptcha;
  bool get rememberPassword => _rememberPassword;
  bool get autoLogin => _autoLogin;
  String get savedUsername => _savedUsername;
  String get savedPassword => _savedPassword;
  String get currentUsername => _currentUsername;
  bool get isOfflineMode => _isOfflineMode;

  Future<String?> init() async {
    await ApiClient().init();
    await _loadPreferences();
    if (_autoLogin && _savedUsername.isNotEmpty && _savedPassword.isNotEmpty) {
      return await login(_savedUsername, _savedPassword);
    }
    return null;
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _rememberPassword = prefs.getBool('remember_password') ?? false;
    _autoLogin = prefs.getBool('auto_login') ?? false;
    if (_rememberPassword) {
      _savedUsername = prefs.getString('username') ?? "";
      _savedPassword = prefs.getString('password') ?? "";
    }
    notifyListeners();
  }

  void setRememberPassword(bool value) {
    _rememberPassword = value;
    if (!value) {
      _autoLogin = false;
    }
    notifyListeners();
  }

  void setAutoLogin(bool value) {
    _autoLogin = value;
    if (value) {
      _rememberPassword = true;
    }
    notifyListeners();
  }

  Future<void> checkLoginStatus() async {
    // Kept for compatibility, but logic moved to init()
  }

  Future<void> loadCaptcha() async {
    _captchaImage = await _authService.getCaptchaImage();
    notifyListeners();
  }

  Future<String?> login(String username, String password, {String verifyCode = ""}) async {
    _isLoading = true;
    notifyListeners();

    // Ensure client is initialized
    await ApiClient().init();

    var result = await _authService.login(username, password, verifyCode: verifyCode);
    
    _isLoading = false;
    if (result['success']) {
      _isLoggedIn = true;
      _needCaptcha = false;
      _currentUsername = username;
      
      // Save preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('remember_password', _rememberPassword);
      await prefs.setBool('auto_login', _autoLogin);
      if (_rememberPassword) {
        await prefs.setString('username', username);
        await prefs.setString('password', password);
        _savedUsername = username;
        _savedPassword = password;
      } else {
        await prefs.remove('username');
        await prefs.remove('password');
        _savedUsername = "";
        _savedPassword = "";
      }

      notifyListeners();
      return null; // No error
    } else {
      // Check for offline login possibility
      String msg = result['message'].toString();
      if (msg.contains("网络错误") || msg.contains("SocketException") || msg.contains("DioException")) {
        if (_rememberPassword && _savedUsername == username && _savedPassword == password) {
          _isLoggedIn = true;
          _needCaptcha = false;
          _currentUsername = username;
          _isOfflineMode = true;
          notifyListeners();
          return null; // Treat as success
        }
      }

      if (result['needCaptcha'] == true) {
        _needCaptcha = true;
        await loadCaptcha();
      }
      notifyListeners();
      return result['message'];
    }
  }

  Future<void> logout() async {
    await ApiClient().clearCookies();
    _isLoggedIn = false;
    _needCaptcha = false;
    
    // Cancel auto login and clear saved password
    _autoLogin = false;
    _savedPassword = "";
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_login', false);
    await prefs.remove('password');
    
    notifyListeners();
  }
}
