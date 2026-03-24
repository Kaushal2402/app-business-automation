import 'package:flutter/material.dart';
import 'package:business_automation/core/theme/app_colors.dart';
import 'package:business_automation/core/utils/local_auth_service.dart';
import 'package:business_automation/features/auth/domain/repositories/auth_repository.dart';
import 'package:business_automation/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:business_automation/features/dashboard/presentation/cubit/settings_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:business_automation/injection_container.dart';
import 'profile_setup_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final List<int> _pin = [];
  final List<int> _confirmPin = [];
  String? _firstPin;
  bool _isSettingPin = false;
  bool _isPinSet = false;
  final LocalAuthService _authService = LocalAuthService();
  final AuthRepository _authRepo = sl<AuthRepository>();

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final pinSet = await _authRepo.isPinSet();
    setState(() {
      _isPinSet = pinSet;
      _isSettingPin = !pinSet;
    });
  }

  void _onKeyPress(int value) {
    if (_pin.length < 4) {
      setState(() => _pin.add(value));
      if (_pin.length == 4) {
        if (_isSettingPin) {
          if (_firstPin == null) {
            final enteredString = _pin.join();
            // Restrict weak PINs like 1234 or repeating numbers
            final repeatingPattern = RegExp(r'^(.)\1{3}$');
            if (enteredString == '1234' || repeatingPattern.hasMatch(enteredString)) {
              _showError('Please choose a more secure PIN');
              setState(() => _pin.clear());
              return;
            }
            _firstPin = enteredString;
            _pin.clear();
            setState(() {});
          } else {
            _verifyAndSavePin();
          }
        } else {
          _verifyPin();
        }
      }
    }
  }

  void _onDelete() {
    if (_pin.isNotEmpty) {
      setState(() => _pin.removeLast());
    }
  }

  Future<void> _verifyPin() async {
    final enteredPin = _pin.join();
    final isValid = await _authRepo.verifyPin(enteredPin);
    if (isValid) {
      _onSuccess();
    } else {
      setState(() => _pin.clear());
      _showError('Incorrect PIN');
    }
  }

  Future<void> _verifyAndSavePin() async {
    final secondPin = _pin.join();
    if (_firstPin == secondPin) {
      await _authRepo.savePin(secondPin);
      _onSuccess();
    } else {
      setState(() {
        _pin.clear();
        _firstPin = null;
      });
      _showError('PINs do not match. Start over.');
    }
  }

  Future<void> _authenticateWithBiometrics() async {
    if (!_isPinSet) return;
    final success = await _authService.authenticate();
    if (success) {
      _onSuccess();
    }
  }

  Future<void> _onSuccess() async {
    if (!mounted) return;
    final settingsState = context.read<SettingsCubit>().state;
    
    if (settingsState is SettingsLoaded) {
      if (settingsState.settings.businessName.trim().isEmpty) {
        _navigateTo(const ProfileSetupPage());
      } else {
        _navigateTo(const DashboardPage());
      }
    } else {
      _navigateTo(const ProfileSetupPage());
    }
  }

  void _navigateTo(Widget page) {
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => page),
      );
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    String title = _isPinSet ? 'Enter Security PIN' : (_firstPin == null ? 'Create Security PIN' : 'Confirm New PIN');
    String subtitle = _isPinSet ? 'Keep your business data safe' : 'Choose a 4-digit PIN to secure your app';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            Icon(_isPinSet ? Icons.lock_person_rounded : Icons.security_rounded, size: 64, color: AppColors.primary),
            const SizedBox(height: 24),
            Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Text(subtitle, style: const TextStyle(color: AppColors.neutral500)),
            const SizedBox(height: 48),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                final isFilled = index < _pin.length;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: isFilled ? AppColors.primary : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary, width: 2),
                  ),
                );
              }),
            ),
            const Spacer(),
            _buildNumericPad(),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildNumericPad() {
    return Column(
      children: [
        for (var i = 0; i < 3; i++)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (var j = 1; j <= 3; j++) _buildKey(i * 3 + j),
            ],
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              onPressed: _authenticateWithBiometrics,
              icon: Icon(Icons.face_unlock_rounded, size: 32, color: _isPinSet ? AppColors.primary : AppColors.neutral100),
            ),
            _buildKey(0),
            IconButton(
              onPressed: _onDelete,
              icon: const Icon(Icons.backspace_rounded, size: 32, color: AppColors.neutral500),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKey(int value) {
    return TextButton(
      onPressed: () => _onKeyPress(value),
      style: TextButton.styleFrom(
        shape: const CircleBorder(),
        padding: const EdgeInsets.all(24),
      ),
      child: Text(
        '$value',
        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.neutral900),
      ),
    );
  }
}
