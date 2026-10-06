import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';
import 'package:local_auth/local_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _pwdCtrl = TextEditingController();
  final LocalAuthentication _localAuth = LocalAuthentication();

  bool _isLoading = false;
  bool _isBiometricLoading = false;
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();

    // تشغيل البصمة تلقائيًا عند فتح البرنامج
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startBiometricLogin();
    });
  }

  /// التحقق من توفر البصمة
  Future<bool> _checkBiometricAvailability() async {
    try {
      final bool canCheckBiometrics =
          await _localAuth.canCheckBiometrics;

      final bool isDeviceSupported =
          await _localAuth.isDeviceSupported();

      if (!mounted) return false;

      setState(() {
        _biometricAvailable =
            canCheckBiometrics || isDeviceSupported;
      });

      return canCheckBiometrics || isDeviceSupported;
    } catch (e) {
      debugPrint('Biometric availability error: $e');

      if (mounted) {
        setState(() {
          _biometricAvailable = false;
        });
      }

      return false;
    }
  }

  /// محاولة الدخول بالبصمة تلقائيًا
  Future<void> _startBiometricLogin() async {
    if (!mounted) return;

    setState(() {
      _isBiometricLoading = true;
    });

    try {
      final available = await _checkBiometricAvailability();

      if (!available) {
        return;
      }

      final bool authenticated = await _localAuth.authenticate(
        localizedReason:
            'يرجى استخدام البصمة لفتح برنامج حسابات علاء ابو شادي',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      if (!mounted) return;

      if (authenticated) {
        _openHome();
      }
    } catch (e) {
      debugPrint('Biometric login error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isBiometricLoading = false;
        });
      }
    }
  }

  /// الدخول بالبصمة عند الضغط على الزر
  Future<void> _loginWithBiometric() async {
    if (_isBiometricLoading || _isLoading) return;

    setState(() {
      _isBiometricLoading = true;
    });

    try {
      final available = await _checkBiometricAvailability();

      if (!available) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'البصمة غير متاحة على هذا الجهاز',
              ),
              backgroundColor: AppColors.warningOrange,
            ),
          );
        }
        return;
      }

      final bool authenticated = await _localAuth.authenticate(
        localizedReason:
            'يرجى استخدام البصمة لفتح برنامج حسابات علاء ابو شادي',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      if (!mounted) return;

      if (authenticated) {
        _openHome();
      }
    } catch (e) {
      debugPrint('Biometric authentication error: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تعذر استخدام البصمة: $e',
            ),
            backgroundColor: AppColors.warningOrange,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBiometricLoading = false;
        });
      }
    }
  }

  /// تسجيل الدخول بكلمة المرور
  Future<void> _login() async {
    if (_pwdCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إدخال كلمة المرور'),
          backgroundColor: AppColors.payableRed,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final supabase = Supabase.instance.client;

      final row = await supabase
          .from('settings')
          .select()
          .eq('key', 'password_hash');

      final storedHash = row.isNotEmpty
          ? row.first['value'] as String
          : sha256
              .convert(utf8.encode('1234'))
              .toString();

      final enteredHash = sha256
          .convert(
            utf8.encode(_pwdCtrl.text.trim()),
          )
          .toString();

      if (enteredHash == storedHash) {
        _openHome();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('كلمة المرور غير صحيحة!'),
              backgroundColor: AppColors.payableRed,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'حدث خطأ في الاتصال: $e',
            ),
            backgroundColor: AppColors.warningOrange,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// فتح الصفحة الرئيسية
  void _openHome() {
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const HomeScreen(),
      ),
    );
  }

  @override
  void dispose() {
    _pwdCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey.shade100,
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.lock_person_outlined,
                  size: 80,
                  color: AppColors.primary,
                ),

                const SizedBox(height: 16),

                const Text(
                  'حسابات علاء ابو شادي',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDark,
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  'استخدم البصمة لفتح البرنامج',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),

                const SizedBox(height: 32),

                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        // زر البصمة
                        if (_biometricAvailable ||
                            _isBiometricLoading)
                          Column(
                            children: [
                              SizedBox(
                                width: double.infinity,
                                height: 70,
                                child: ElevatedButton.icon(
                                  onPressed:
                                      (_isBiometricLoading ||
                                              _isLoading)
                                          ? null
                                          : _loginWithBiometric,
                                  icon: _isBiometricLoading
                                      ? const SizedBox(
                                          height: 24,
                                          width: 24,
                                          child:
                                              CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.fingerprint,
                                          size: 34,
                                        ),
                                  label: Text(
                                    _isBiometricLoading
                                        ? 'جاري التحقق...'
                                        : 'الدخول بالبصمة',
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 20),

                              Row(
                                children: [
                                  Expanded(
                                    child: Divider(
                                      color: Colors.grey.shade400,
                                    ),
                                  ),
                                  Padding(
                                    padding:
                                        const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    child: Text(
                                      'أو كلمة المرور',
                                      style: TextStyle(
                                        color:
                                            Colors.grey.shade600,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Divider(
                                      color: Colors.grey.shade400,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 20),
                            ],
                          ),

                        // كلمة المرور
                        TextField(
                          controller: _pwdCtrl,
                          obscureText: true,
                          keyboardType:
                              TextInputType.visiblePassword,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _login(),
                          decoration: InputDecoration(
                            labelText: 'كلمة المرور',
                            prefixIcon:
                                const Icon(Icons.password),
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(12),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed:
                                (_isLoading ||
                                        _isBiometricLoading)
                                    ? null
                                    : _login,
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(12),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child:
                                        CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'دخول بكلمة المرور',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight:
                                          FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
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
