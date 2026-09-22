import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  
  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;
  bool _isLoading = false;
  
  String _passwordStrength = '';
  Color _strengthColor = Colors.grey;
  String? _errorMessage;

  void _checkPasswordStrength(String password) {
    if (password.isEmpty) {
      setState(() {
        _passwordStrength = '';
        _strengthColor = Colors.grey;
      });
      return;
    }

    int strength = 0;
    
    // Length check
    if (password.length >= 8) strength++;
    if (password.length >= 12) strength++;
    
    // Has uppercase
    if (password.contains(RegExp(r'[A-Z]'))) strength++;
    
    // Has lowercase
    if (password.contains(RegExp(r'[a-z]'))) strength++;
    
    // Has number
    if (password.contains(RegExp(r'[0-9]'))) strength++;
    
    // Has special char
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) strength++;

    setState(() {
      if (strength <= 2) {
        _passwordStrength = 'Yếu';
        _strengthColor = const Color(0xFFEF4444);
      } else if (strength <= 4) {
        _passwordStrength = 'Trung bình';
        _strengthColor = const Color(0xFFF59E0B);
      } else {
        _passwordStrength = 'Mạnh';
        _strengthColor = const Color(0xFF10B981);
      }
    });
  }

  String? _validatePassword() {
    final current = _currentPasswordController.text;
    final newPass = _newPasswordController.text;
    final confirm = _confirmPasswordController.text;

    if (current.isEmpty) {
      return '❌ Vui lòng nhập mật khẩu hiện tại';
    }

    if (newPass.isEmpty) {
      return '❌ Vui lòng nhập mật khẩu mới';
    }

    if (newPass.length < 8) {
      return '❌ Mật khẩu phải có ít nhất 8 ký tự';
    }

    if (!newPass.contains(RegExp(r'[A-Z]'))) {
      return '❌ Mật khẩu phải có ít nhất 1 chữ hoa';
    }

    if (!newPass.contains(RegExp(r'[a-z]'))) {
      return '❌ Mật khẩu phải có ít nhất 1 chữ thường';
    }

    if (!newPass.contains(RegExp(r'[0-9]'))) {
      return '❌ Mật khẩu phải có ít nhất 1 số';
    }

    if (newPass == current) {
      return '❌ Mật khẩu mới phải khác mật khẩu cũ';
    }

    if (confirm.isEmpty) {
      return '❌ Vui lòng xác nhận mật khẩu mới';
    }

    if (newPass != confirm) {
      return '❌ Mật khẩu xác nhận không khớp';
    }

    return null;
  }

  Future<void> _changePassword() async {
    final error = _validatePassword();
    if (error != null) {
      setState(() => _errorMessage = error);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await ApiService.changePassword(
        _currentPasswordController.text,
        _newPasswordController.text,
      );

      if (response['success'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Đổi mật khẩu thành công!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) Navigator.pop(context);
        });
      } else {
        setState(() => _errorMessage = '❌ ${response['message'] ?? 'Đổi mật khẩu thất bại'}');
      }
    } catch (e) {
      setState(() => _errorMessage = '❌ Lỗi: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Đổi mật khẩu'),
        backgroundColor: const Color(0xFF091A33),
        foregroundColor: Colors.white,
      ),
      backgroundColor: const Color(0xFF0F172A),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.lock_outline,
                      color: Color(0xFF60A5FA),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bảo mật tài khoản',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Đổi mật khẩu định kỳ để bảo vệ tài khoản',
                          style: TextStyle(color: Colors.white60, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Error message
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                  border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.5)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Color(0xFFF87171), size: 18),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Color(0xFFF87171),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Current password
            const Text(
              'Mật khẩu hiện tại',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _currentPasswordController,
              obscureText: !_showCurrentPassword,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Nhập mật khẩu hiện tại',
                hintStyle: const TextStyle(color: Colors.white30),
                prefixIcon: const Icon(Icons.lock, color: Color(0xFF60A5FA)),
                suffixIcon: IconButton(
                  icon: Icon(
                    _showCurrentPassword ? Icons.visibility_off : Icons.visibility,
                    color: Colors.white60,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _showCurrentPassword = !_showCurrentPassword),
                ),
                filled: true,
                fillColor: const Color(0xFF0D2242),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // New password
            const Text(
              'Mật khẩu mới',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _newPasswordController,
              obscureText: !_showNewPassword,
              style: const TextStyle(color: Colors.white),
              onChanged: _checkPasswordStrength,
              decoration: InputDecoration(
                hintText: 'Nhập mật khẩu mới',
                hintStyle: const TextStyle(color: Colors.white30),
                prefixIcon: const Icon(Icons.lock_open, color: Color(0xFF60A5FA)),
                suffixIcon: IconButton(
                  icon: Icon(
                    _showNewPassword ? Icons.visibility_off : Icons.visibility,
                    color: Colors.white60,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _showNewPassword = !_showNewPassword),
                ),
                filled: true,
                fillColor: const Color(0xFF0D2242),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Password strength indicator
            if (_passwordStrength.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: _passwordStrength == 'Yếu'
                                ? 0.33
                                : _passwordStrength == 'Trung bình'
                                    ? 0.66
                                    : 1.0,
                            backgroundColor: Colors.grey[800],
                            valueColor: AlwaysStoppedAnimation(_strengthColor),
                            minHeight: 6,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _passwordStrength,
                        style: TextStyle(
                          color: _strengthColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF091A33),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Yêu cầu mật khẩu:',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _buildRequirement('Ít nhất 8 ký tự', _newPasswordController.text.length >= 8),
                        _buildRequirement('Có chữ hoa (A-Z)', _newPasswordController.text.contains(RegExp(r'[A-Z]'))),
                        _buildRequirement('Có chữ thường (a-z)', _newPasswordController.text.contains(RegExp(r'[a-z]'))),
                        _buildRequirement('Có số (0-9)', _newPasswordController.text.contains(RegExp(r'[0-9]'))),
                      ],
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 20),

            // Confirm password
            const Text(
              'Xác nhận mật khẩu mới',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _confirmPasswordController,
              obscureText: !_showConfirmPassword,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Nhập lại mật khẩu mới',
                hintStyle: const TextStyle(color: Colors.white30),
                prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF60A5FA)),
                suffixIcon: IconButton(
                  icon: Icon(
                    _showConfirmPassword ? Icons.visibility_off : Icons.visibility,
                    color: Colors.white60,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _showConfirmPassword = !_showConfirmPassword),
                ),
                filled: true,
                fillColor: const Color(0xFF0D2242),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Change password button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isLoading ? null : _changePassword,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'ĐỔI MẬT KHẨU',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequirement(String text, bool isMet) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.circle_outlined,
            color: isMet ? const Color(0xFF10B981) : Colors.white30,
            size: 14,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: isMet ? const Color(0xFF10B981) : Colors.white60,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}
