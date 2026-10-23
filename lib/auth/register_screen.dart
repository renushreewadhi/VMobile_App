import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/auth/auth_service.dart';
import '../core/theme/app_colors.dart';
import '../core/widgets/app_button.dart';
import '../core/widgets/app_card.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _hidePassword = true;
  bool _hideConfirmPassword = true;
  bool _isRegistering = false;
  bool _acceptedTerms = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _message(String value) {
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(value)));
  }

  Future<void> _register() async {
    FocusScope.of(context).unfocus();
    if (_isRegistering || !(_formKey.currentState?.validate() ?? false)) return;
    if (!_acceptedTerms) {
      _message('Please accept the Terms & Conditions to continue.');
      return;
    }

    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();

    setState(() => _isRegistering = true);
    try {
      await ref.read(authServiceProvider.notifier).register(
            firstName: firstName,
            lastName: lastName,
            email: _emailController.text.trim(),
            password: _passwordController.text,
            role: 'EMPLOYEE',
          );
      if (!mounted) return;
      _message('Registration successful. Please sign in with your new account.');
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      _message(error.toString().replaceFirst('Exception: ', '').trim());
    } finally {
      if (mounted) setState(() => _isRegistering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkAppBackground : AppColors.lightAppBackground,
      appBar: AppBar(title: const Text('Register Account')),
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(22, 15, 22, 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Create your account',
                    style: TextStyle(
                      color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    'Register for access to your workplace.',
                    style: TextStyle(
                      color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _formCard(isDark),
                  const SizedBox(height: 14),
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'Already have an account? Sign in',
                        style: TextStyle(
                          color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _formCard(bool dark) {
    return AppCard(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('FIRST NAME', dark),
                      const SizedBox(height: 7),
                      TextFormField(
                        controller: _firstNameController,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        style: TextStyle(color: dark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText),
                        decoration: _decoration(dark, 'First name', Icons.person_outline_rounded),
                        validator: (value) => value == null || value.trim().isEmpty ? 'Enter first name' : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('LAST NAME', dark),
                      const SizedBox(height: 7),
                      TextFormField(
                        controller: _lastNameController,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        style: TextStyle(color: dark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText),
                        decoration: _decoration(dark, 'Last name', Icons.person_outline_rounded),
                        validator: (value) => value == null || value.trim().isEmpty ? 'Enter last name' : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            _label('EMAIL ADDRESS', dark),
            const SizedBox(height: 7),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              style: TextStyle(color: dark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText),
              decoration: _decoration(dark, 'you@company.com', Icons.mail_outline_rounded),
              validator: (value) {
                final email = value?.trim() ?? '';
                if (email.isEmpty) return 'Enter your email address';
                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                  return 'Enter a valid email address';
                }
                return null;
              },
            ),
            const SizedBox(height: 15),
            _label('PASSWORD', dark),
            const SizedBox(height: 7),
            TextFormField(
              controller: _passwordController,
              obscureText: _hidePassword,
              textInputAction: TextInputAction.next,
              style: TextStyle(color: dark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText),
              decoration: _decoration(
                dark,
                'Create a password',
                Icons.lock_outline_rounded,
                suffix: IconButton(
                  onPressed: () => setState(() => _hidePassword = !_hidePassword),
                  icon: Icon(_hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: dark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Create a password';
                if (value.length < 6) return 'Use at least 6 characters';
                return null;
              },
            ),
            const SizedBox(height: 15),
            _label('CONFIRM PASSWORD', dark),
            const SizedBox(height: 7),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: _hideConfirmPassword,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _register(),
              style: TextStyle(color: dark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText),
              decoration: _decoration(
                dark,
                'Re-enter your password',
                Icons.lock_outline_rounded,
                suffix: IconButton(
                  onPressed: () => setState(() => _hideConfirmPassword = !_hideConfirmPassword),
                  icon: Icon(_hideConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: dark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Confirm your password';
                if (value != _passwordController.text) return 'Passwords do not match';
                return null;
              },
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: _acceptedTerms,
                    onChanged: _isRegistering ? null : (value) => setState(() => _acceptedTerms = value ?? false),
                    activeColor: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: GestureDetector(
                    onTap: _isRegistering ? null : () => setState(() => _acceptedTerms = !_acceptedTerms),
                    child: Text('I accept Terms & Conditions', style: TextStyle(color: dark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText, fontSize: 13)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            AppButton(
              label: 'Create account',
              onPressed: _isRegistering ? null : _register,
              isLoading: _isRegistering,
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text, bool dark) => Text(
        text,
        style: TextStyle(
          color: dark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      );

  InputDecoration _decoration(bool dark, String hint, IconData icon, {Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: dark ? AppColors.darkMutedText : AppColors.lightMutedText, fontSize: 13),
      prefixIcon: Icon(icon, color: AppColors.primary, size: 21),
      suffixIcon: suffix,
      filled: true,
      fillColor: dark ? AppColors.darkSecondarySurface : AppColors.lightInputBackground,
      contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 15),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: dark ? AppColors.darkBordersAndDividers : AppColors.lightBordersAndDividers)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: dark ? AppColors.darkBordersAndDividers : AppColors.lightBordersAndDividers)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primary, width: 1.4)),
    );
  }
}
