import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:math' as math;
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
  final _phoneController = TextEditingController();
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
    _phoneController.dispose();
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

    if (!_isLoginMode) {
      final phone = _phoneController.text.trim();
      if (phone.isEmpty || phone.length < 10) {
        _showError('Please enter a valid 10-digit Phone Number for OTP verification.');
        return;
      }

      // Show OTP verification dialog before creating account
      _showPhoneOtpVerificationDialog(phone, () async {
        await _executeCreateAccount(username, password);
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
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
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      } else {
        _showError(result['message'] ?? 'Login failed.');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      _showError('Network error occurred.');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _executeCreateAccount(String username, String password) async {
    setState(() => _isLoading = true);
    try {
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
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      } else {
        _showError(result['message'] ?? 'Account creation failed.');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      _showError('Network error occurred.');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showPhoneOtpVerificationDialog(String phone, VoidCallback onVerified) async {
    setState(() => _isLoading = true);
    String phoneNumber = phone;
    if (!phoneNumber.startsWith('+')) {
      phoneNumber = '+91$phoneNumber';
    }

    try {
      final generatedOtp = (100000 + math.Random().nextInt(900000)).toString();
      await FirebaseService.storeOtpVerification(phoneNumber, generatedOtp);
      await FirebaseService.sendOtpViaSms(phoneNumber, generatedOtp);
      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Secure OTP verification code sent to $phone'),
            backgroundColor: Colors.indigo,
            duration: const Duration(seconds: 8),
          ),
        );
      }

      final otpController = TextEditingController();
      bool isVerifying = false;

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.lock_person_rounded, color: Colors.blueAccent),
                  SizedBox(width: 10),
                  Text('Phone OTP Verification'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('A secure 6-digit verification code has been sent to $phone.'),
                  const SizedBox(height: 12),
                  const Text('Enter the 6-digit code sent to your phone', style: TextStyle(fontSize: 12, color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: InputDecoration(
                      labelText: 'Enter 6-Digit OTP',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isVerifying ? null : () async {
                    setDialogState(() => isVerifying = true);
                    final generatedOtp = (100000 + math.Random().nextInt(900000)).toString();
                    await FirebaseService.storeOtpVerification(phoneNumber, generatedOtp);
                    await FirebaseService.sendOtpViaSms(phoneNumber, generatedOtp);
                    setDialogState(() => isVerifying = false);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('New 6-digit OTP code sent to $phone'),
                          backgroundColor: Colors.green,
                          duration: const Duration(seconds: 5),
                        ),
                      );
                    }
                  },
                  child: const Text('Resend OTP', style: TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold)),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isVerifying ? null : () async {
                    if (otpController.text.trim().length >= 4) {
                      setDialogState(() => isVerifying = true);
                      final isValid = await FirebaseService.verifyOtp(phoneNumber, otpController.text.trim());
                      if (isValid) {
                        Navigator.pop(ctx);
                        onVerified();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Invalid 6-digit OTP code entered. Please try again.')),
                        );
                        setDialogState(() => isVerifying = false);
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter valid 6-digit OTP.')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
                  child: isVerifying ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Verify & Complete'),
                ),
              ],
            );
          }
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed to send OTP: $e');
    }
  }

  void _showForgotCredentialsModal() {
    final userCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final otpCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    int step = 1;
    bool isSending = false;
    bool isVerifying = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.lock_reset_rounded, color: Colors.blueAccent, size: 28),
                  SizedBox(width: 12),
                  Text('Forgot Credentials', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 16),
              if (step == 1) ...[
                const Text('Enter your registered Username and Phone Number to receive a secure recovery OTP.'),
                const SizedBox(height: 16),
                TextField(
                  controller: userCtrl,
                  decoration: InputDecoration(
                    labelText: 'Username (containing OFFPAY)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Registered Phone Number',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.maxFinite,
                  child: ElevatedButton(
                    onPressed: isSending ? null : () async {
                      if (userCtrl.text.trim().isEmpty || !userCtrl.text.toUpperCase().contains('OFFPAY') || phoneCtrl.text.trim().length < 10) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter valid Username and 10-digit Phone Number.')),
                        );
                        return;
                      }
                      
                      setModalState(() => isSending = true);
                      
                      String phoneNumber = phoneCtrl.text.trim();
                      if (!phoneNumber.startsWith('+')) {
                        phoneNumber = '+91$phoneNumber';
                      }

                      final recoveryOtp = (100000 + math.Random().nextInt(900000)).toString();
                      await FirebaseService.storeOtpVerification(phoneNumber, recoveryOtp);
                      await FirebaseService.sendOtpViaSms(phoneNumber, recoveryOtp);
                      
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Recovery OTP sent to $phoneNumber'),
                            backgroundColor: Colors.indigo,
                            duration: const Duration(seconds: 8),
                          ),
                        );
                      }

                      setModalState(() {
                        isSending = false;
                        step = 2;
                      });
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: isSending ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Send Recovery OTP'),
                  ),
                ),
              ] else ...[
                const Text('Enter the OTP received on your phone and set your new password.', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                const Text('Enter the 6-digit code sent to your phone', style: TextStyle(fontSize: 12, color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                TextField(
                  controller: otpCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: InputDecoration(
                    labelText: '6-Digit OTP',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newPassCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'New Password (min 6 chars)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.maxFinite,
                  child: ElevatedButton(
                    onPressed: isVerifying ? null : () async {
                      if (otpCtrl.text.trim().length < 4 || newPassCtrl.text.trim().length < 6) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter valid OTP and password >= 6 chars.')),
                        );
                        return;
                      }
                      
                      setModalState(() => isVerifying = true);
                      
                      try {
                        String phoneNumber = phoneCtrl.text.trim();
                        if (!phoneNumber.startsWith('+')) {
                          phoneNumber = '+91$phoneNumber';
                        }
                        final isValid = await FirebaseService.verifyOtp(phoneNumber, otpCtrl.text.trim());
                        if (isValid) {
                          Navigator.pop(ctx);
                          await FirebaseService.createAccount(userCtrl.text.trim(), newPassCtrl.text.trim());
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Credentials reset successfully! Please login.'), backgroundColor: Colors.green),
                            );
                          }
                        } else {
                          setModalState(() => isVerifying = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Invalid OTP code entered. Please try again.')),
                          );
                        }
                      } catch (e) {
                        setModalState(() => isVerifying = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: isVerifying ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Verify & Update Password'),
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: TextButton.icon(
                    icon: const Icon(Icons.refresh, size: 18, color: Colors.indigo),
                    label: const Text('Resend Recovery OTP', style: TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold)),
                    onPressed: isVerifying ? null : () async {
                      setModalState(() => isVerifying = true);
                      String phoneNumber = phoneCtrl.text.trim();
                      if (!phoneNumber.startsWith('+')) {
                        phoneNumber = '+91$phoneNumber';
                      }
                      final newOtp = (100000 + math.Random().nextInt(900000)).toString();
                      await FirebaseService.storeOtpVerification(phoneNumber, newOtp);
                      await FirebaseService.sendOtpViaSms(phoneNumber, newOtp);
                      setModalState(() => isVerifying = false);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('New Recovery OTP resent to $phoneNumber'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
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

                if (!_isLoginMode) ...[
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Phone Number (for OTP Verification)',
                      hintText: '+91 98765 43210',
                      prefixIcon: const Icon(Icons.phone_android_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

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

                if (_isLoginMode)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _showForgotCredentialsModal,
                      child: const Text(
                        'Forgot Credentials?',
                        style: TextStyle(fontWeight: FontWeight.w600, color: Colors.blueAccent),
                      ),
                    ),
                  ),

                const SizedBox(height: 24),

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
