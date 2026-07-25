import 'dart:async';
import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../services/profile_service.dart';
import '../models/wallet_model.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isLoginMode = true;
  
  bool _isCheckingUsername = false;
  bool _isUsernameAvailable = true;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _checkUsernameAvailability(String username) {
    if (username.isEmpty || !username.toUpperCase().contains('OFFPAY')) {
      setState(() {
        _isUsernameAvailable = false;
        _isCheckingUsername = false;
      });
      return;
    }

    setState(() {
      _isCheckingUsername = true;
    });

    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), () async {
      final exists = await FirebaseService.checkUsernameExists(username);
      if (mounted) {
        setState(() {
          _isUsernameAvailable = !exists;
          _isCheckingUsername = false;
        });
      }
    });
  }

  Future<void> _submit() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      _showError('Please enter both username and password.');
      return;
    }

    if (!username.toUpperCase().contains('OFFPAY')) {
      _showError('Username must contain "OFFPAY" (e.g., Alex OFFPAY).');
      return;
    }

    if (password.length < 6) {
      _showError('Password must be at least 6 characters.');
      return;
    }

    if (!_isLoginMode && !_isUsernameAvailable) {
      _showError('Please choose an available username.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isLoginMode) {
        // Login
        final result = await FirebaseService.loginAccount(username, password);
        if (result['success'] == true) {
          await ProfileService.setLoggedIn(true);
          await ProfileService.saveProfile(
            name: username,
            deviceId: result['deviceId'],
            avatarIndex: 0,
            isDeviceIdChanged: false,
          );

          // Restore wallet
          final wallet = Provider.of<WalletModel>(context, listen: false);
          
          List<dynamic> rawHistory = result['history'] ?? [];
          final box = await Hive.openBox('walletBox');
          await box.put('currentBalance', result['balance']);
          await box.put('history_v2', rawHistory);
          
          await wallet.refreshBalance();
        } else {
          _showError(result['message'] ?? 'Login failed.');
          setState(() => _isLoading = false);
          return;
        }
      } else {
        // Create Account
        final result = await FirebaseService.createAccount(username, password);
        if (result['success'] == true) {
          await ProfileService.setLoggedIn(true);
          await ProfileService.saveProfile(
            name: username,
            deviceId: result['deviceId'],
            avatarIndex: 0,
            isDeviceIdChanged: false,
          );
          
          final box = await Hive.openBox('walletBox');
          await box.put('currentBalance', 500.0);
          await box.put('history_v2', []);
          final wallet = Provider.of<WalletModel>(context, listen: false);
          await wallet.refreshBalance();
        } else {
          _showError(result['message'] ?? 'Account creation failed.');
          setState(() => _isLoading = false);
          return;
        }
      }

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      _showError('Network error occurred.');
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.wifi_tethering, size: 80, color: theme.primaryColor),
                const SizedBox(height: 16),
                Text(
                  'OFFPAY',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isLoginMode ? 'Welcome back!' : 'Create your account',
                  style: TextStyle(fontSize: 16, color: theme.hintColor),
                ),
                const SizedBox(height: 40),

                TextField(
                  controller: _usernameController,
                  onChanged: (val) {
                    if (!_isLoginMode) {
                      _checkUsernameAvailability(val);
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'Username (must contain OFFPAY)',
                    hintText: 'e.g. John OFFPAY',
                    prefixIcon: const Icon(Icons.person),
                    suffixIcon: _isLoginMode 
                        ? null 
                        : (_isCheckingUsername 
                            ? const Padding(
                                padding: EdgeInsets.all(14.0),
                                child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                              )
                            : Icon(
                                _isUsernameAvailable ? Icons.check_circle : Icons.cancel,
                                color: _isUsernameAvailable ? Colors.green : Colors.red,
                              )),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                  ),
                ),
                if (!_isLoginMode && !_isUsernameAvailable && _usernameController.text.isNotEmpty && !_isCheckingUsername)
                  const Padding(
                    padding: EdgeInsets.only(top: 8.0, left: 12.0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Username is already taken', style: TextStyle(color: Colors.red, fontSize: 12)),
                    ),
                  ),
                const SizedBox(height: 16),

                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                  ),
                ),
                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            _isLoginMode ? 'Login' : 'Create Account',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
                const SizedBox(height: 16),

                TextButton(
                  onPressed: () {
                    setState(() {
                      _isLoginMode = !_isLoginMode;
                    });
                  },
                  child: Text(
                    _isLoginMode
                        ? "Don't have an account? Create one"
                        : "Already have an account? Login",
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
