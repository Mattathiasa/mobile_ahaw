import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/theme_provider.dart';
import '../widgets/custom_button.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.signIn(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
      // Navigation is handled by auth state listener in main.dart or wrapper
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        if (_errorMessage!.contains('firebase_auth')) {
           // Simplify/Clean up firebase error message if needed
           _errorMessage = _errorMessage!.split('] ').last;
        }
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Dynamic Background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark 
                  ? [
                      const Color(0xFF0D2440),
                      const Color(0xFF1A365D),
                      const Color(0xFF0F172A),
                    ]
                  : [
                      const Color(0xFFF0F7FF),
                      const Color(0xFFE0EBF5),
                      const Color(0xFFF8F9FA),
                    ],
              ),
            ),
          ),
          
          // Decorative Elements (Blobs)
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.2),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.2),
                    blurRadius: 100,
                    spreadRadius: 20,
                  ),
                ],
              ),
            ),
          ).animate(onPlay: (controller) => controller.repeat(reverse: true))
           .moveY(begin: 0, end: 50, duration: 4.seconds),
           
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                color: AppColors.secondary.withOpacity(0.15),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.secondary.withOpacity(0.15),
                    blurRadius: 80,
                    spreadRadius: 10,
                  ),
                ],
              ),
            ),
          ).animate(onPlay: (controller) => controller.repeat(reverse: true))
           .moveY(begin: 0, end: -30, duration: 5.seconds),

          // Main Content
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.all(32.0),
                    decoration: BoxDecoration(
                      color: isDark 
                          ? Colors.white.withOpacity(0.05) 
                          : Colors.white.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isDark 
                            ? Colors.white.withOpacity(0.1) 
                            : Colors.white.withOpacity(0.8),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Logo
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.asset(
                              'assets/logo.png',
                              height: 60,
                              width: 60,
                            ),
                          ),
                        )
                            .animate()
                            .fadeIn(duration: 500.ms)
                            .scale(delay: 200.ms, duration: 500.ms),
                        
                        const SizedBox(height: 24),
                        
                        // Title
                        Text(
                          'Ahaw Access',
                          style: GoogleFonts.notoSansEthiopic(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : AppColors.primary,
                            letterSpacing: -0.5,
                          ),
                        ).animate().fadeIn().moveY(begin: 10),
                        
                        Text(
                          'Church Management System',
                          style: GoogleFonts.notoSansEthiopic(
                            fontSize: 14,
                            color: isDark ? Colors.white60 : Colors.grey[600],
                            letterSpacing: 0.5,
                          ),
                        ).animate().fadeIn(delay: 200.ms).moveY(begin: 10),
                        
                        const SizedBox(height: 32),

                        // Error Message
                        if (_errorMessage != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: AppColors.error.withOpacity(0.1),
                              border: Border.all(color: AppColors.error.withOpacity(0.3)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline, color: AppColors.error, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: TextStyle(color: AppColors.error, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ).animate().fadeIn(),

                        // Email Field
                        _buildTextField(
                          controller: _emailController,
                          label: 'Email Address',
                          icon: Icons.email_outlined,
                          isDark: isDark,
                        ).animate().fadeIn(delay: 300.ms).moveX(begin: -20),
                        
                        const SizedBox(height: 16),

                        // Password Field
                        _buildTextField(
                          controller: _passwordController,
                          label: 'Password',
                          icon: Icons.lock_outline,
                          isObscure: true,
                          isLast: true,
                          isDark: isDark,
                          onSubmitted: (_) => _signIn(),
                        ).animate().fadeIn(delay: 400.ms).moveX(begin: -20),
                        
                        const SizedBox(height: 24),

                        // Sign In Button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _signIn,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 10,
                              shadowColor: AppColors.primary.withOpacity(0.4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: _isLoading 
                                ? const SizedBox(
                                    height: 24, 
                                    width: 24, 
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                                  )
                                : const Text(
                                    'Sign In',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                          ),
                        ).animate().fadeIn(delay: 500.ms).moveY(begin: 20),
                        
                        const SizedBox(height: 24),
                        
                        // Copyright / Footer
                        Text(
                          '© 2025 Mahibere Ahaw',
                          style: GoogleFonts.notoSansEthiopic(
                            fontSize: 12,
                            color: isDark ? Colors.white30 : Colors.grey[400],
                          ),
                        ).animate().fadeIn(delay: 600.ms),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isObscure = false,
    bool isLast = false,
    required bool isDark,
    Function(String)? onSubmitted,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.black.withOpacity(0.2) : Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.2),
        ),
      ),
      child: TextField(
        controller: controller,
        obscureText: isObscure,
        style: GoogleFonts.notoSansEthiopic(
          color: isDark ? Colors.white : AppColors.lightText,
        ),
        textInputAction: isLast ? TextInputAction.done : TextInputAction.next,
        onSubmitted: onSubmitted,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: isDark ? Colors.white60 : Colors.grey[600],
            fontSize: 14,
          ),
          prefixIcon: Icon(
            icon, 
            color: isDark ? Colors.white60 : Colors.grey[500],
            size: 20,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }
}
