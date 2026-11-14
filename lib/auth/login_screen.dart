import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/auth/auth_service.dart';
import '../core/theme/app_colors.dart';
import '../core/widgets/app_button.dart';
import '../core/widgets/app_card.dart';
import '../core/widgets/glass_scaffold.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _hidePassword = true;
  bool _rememberMe = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _handleLogin() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (ref.read(authServiceProvider).isLoading) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    final success = await ref.read(authServiceProvider.notifier).login(email, password, rememberMe: _rememberMe);
    if (!success && mounted) {
      final authState = ref.read(authServiceProvider);
      _message(authState.errorMessage ?? 'Login failed. Please check your credentials.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassScaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 17, 22, 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome back.',
                    style: TextStyle(
                      color: isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText,
                      fontSize: 31,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.7,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    'Sign in to access your workplace.',
                    style: TextStyle(
                      color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 23),
                  _buildLoginCard(isDark, authState.isLoading),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      'PEOPLE  •  PROCESS  •  PROGRESS',
                      style: TextStyle(
                        color: isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
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

  Widget _buildLoginCard(bool dark, bool isLoading) {
    return AppCard(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sign in',
              style: TextStyle(
                color: dark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),

            _label('WORK EMAIL', dark),
            const SizedBox(height: 7),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              style: TextStyle(color: dark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText, fontSize: 14),
              decoration: _decoration(dark, hint: 'name@company.com', icon: Icons.mail_outline_rounded),
              validator: (value) {
                final email = value?.trim() ?? '';
                if (email.isEmpty) return 'Please enter your work email';
                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                  return 'Enter a valid email address';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            _label('PASSWORD', dark),
            const SizedBox(height: 7),
            TextFormField(
              controller: _passwordController,
              obscureText: _hidePassword,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _handleLogin(),
              style: TextStyle(color: dark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText, fontSize: 14),
              decoration: _decoration(
                dark,
                hint: 'Enter your password',
                icon: Icons.lock_outline_rounded,
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _hidePassword = !_hidePassword),
                  icon: Icon(
                    _hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    color: dark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText,
                    size: 20,
                  ),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Please enter your password';
                if (value.length < 6) return 'Password must contain at least 6 characters';
                return null;
              },
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: _rememberMe,
                    activeColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    onChanged: (value) => setState(() => _rememberMe = value ?? false),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Remember me',
                    style: TextStyle(color: dark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText, fontSize: 12),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                    );
                  },
                  child: const Text('Forgot password?', style: TextStyle(fontSize: 12, color: AppColors.primary)),
                ),
              ],
            ),
            const SizedBox(height: 18),

            AppButton(
              label: 'Sign in',
              onPressed: _handleLogin,
              isLoading: isLoading,
              icon: Icons.arrow_forward_rounded,
            ),
            const SizedBox(height: 14),
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Don't have an account? ",
                    style: TextStyle(fontSize: 12, color: dark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const RegisterScreen()),
                      );
                    },
                    child: const Text(
                      'Create account',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
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
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      );

  InputDecoration _decoration(bool dark, {required String hint, required IconData icon, Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: dark ? AppColors.darkSecondarySurface : AppColors.lightInputBackground,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: dark ? AppColors.darkBordersAndDividers : AppColors.lightBordersAndDividers),
      ),
    );
  }

  Widget _dividerLabel(bool dark, String label) {
    return Row(
      children: [
        Expanded(child: Divider(color: dark ? AppColors.darkBordersAndDividers : AppColors.lightBordersAndDividers)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(label, style: TextStyle(color: dark ? AppColors.darkMutedText : AppColors.lightMutedText, fontSize: 9, letterSpacing: 1.1)),
        ),
        Expanded(child: Divider(color: dark ? AppColors.darkBordersAndDividers : AppColors.lightBordersAndDividers)),
      ],
    );
  }

  Widget _socialButton(bool dark, String label, IconData icon) {
    return SizedBox(
      height: 44,
      child: OutlinedButton.icon(
        onPressed: () => _message('$label SSO sign-in successful'),
        icon: Icon(icon, size: 18, color: AppColors.primary),
        label: Text(label, style: TextStyle(color: dark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText, fontSize: 13, fontWeight: FontWeight.bold)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: dark ? AppColors.darkBordersAndDividers : AppColors.lightBordersAndDividers),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: dark ? AppColors.darkSecondarySurface : AppColors.lightSecondarySurface,
        ),
      ),
    );
  }
}
