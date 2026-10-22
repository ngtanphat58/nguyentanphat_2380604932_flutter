
import 'package:flutter/material.dart';

import '../Services/auth_service.dart';
import '../Services/api_client.dart';
import '../Services/device_services.dart';
import '../Models/app_models.dart';
import '../themes/app_theme.dart';

enum _AuthMode {
  login,
  parentRegister,
  childRegister,
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _linkCodeController = TextEditingController();
  final _otpController = TextEditingController();

  _AuthMode _mode = _AuthMode.login;

  bool _loading = false;
  bool _hidePassword = true;
  bool _showOtp = false;
  bool _loginOtp = false;
  bool _biometricLoading = false;

  String _otpEmail = '';
  String _loginIdentifier = '';

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _linkCodeController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _message(String message, {bool error = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor:
          error ? AppTheme.danger : AppTheme.success,
        ),
      );
  }

  String? _required(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      return 'Vui lòng nhập $label.';
    }
    return null;
  }

  String? _emailValidator(String? value) {
    final required = _required(value, 'email');
    if (required != null) return required;

    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
        .hasMatch(value!.trim())) {
      return 'Email không đúng định dạng.';
    }

    return null;
  }

  String? _passwordValidator(String? value) {
    final required = _required(value, 'mật khẩu');
    if (required != null) return required;

    if (value!.length < 8) {
      return 'Mật khẩu phải có ít nhất 8 ký tự.';
    }

    return null;
  }

  String _errorText(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }

  Future<void> _submit() async {
    if (_loading || !_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _loading = true);

    try {
      switch (_mode) {
        case _AuthMode.login:
          await _login();
          break;

        case _AuthMode.parentRegister:
          await _registerParent();
          break;

        case _AuthMode.childRegister:
          await _registerChild();
          break;
      }
    } catch (e) {
      if (mounted) {
        _message(_errorText(e), error: true);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  // Đăng nhập bằng vân tay.
  Future<void> _loginWithBiometrics() async {
    if (_loading || _biometricLoading) return;

    setState(() => _biometricLoading = true);

    try {
      final enabled =
      await ApiClient.isBiometricLoginEnabled();

      if (!enabled) {
        _message(
          'Bạn cần đăng nhập bằng tài khoản và OTP trước, '
              'sau đó bật đăng nhập vân tay.',
          error: true,
        );
        return;
      }

      final authenticated =
      await DeviceServices.authenticateWithBiometrics();

      if (!authenticated) {
        _message(
          'Xác thực vân tay không thành công.',
          error: true,
        );
        return;
      }

      final user = await ApiClient.restoreBiometricSession();

      if (user == null) {
        _message(
          'Không tìm thấy phiên đăng nhập. '
              'Vui lòng đăng nhập lại bằng tài khoản và OTP.',
          error: true,
        );
        return;
      }

      if (!mounted) return;

      Navigator.of(context).pushNamedAndRemoveUntil(
        '/home',
            (route) => false,
        arguments: user,
      );
    } catch (e) {
      if (mounted) {
        _message(_errorText(e), error: true);
      }
    } finally {
      if (mounted) {
        setState(() => _biometricLoading = false);
      }
    }
  }

  // Hỏi bật vân tay sau lần đăng nhập OTP thành công.
  Future<void> _askToEnableBiometrics() async {
    if (!mounted) return;

    final alreadyEnabled =
    await ApiClient.isBiometricLoginEnabled();

    if (alreadyEnabled || !mounted) return;

    final enable = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Bật đăng nhập bằng vân tay?'),
          content: const Text(
            'Bạn có muốn dùng vân tay để đăng nhập '
                'ParentShield lần sau trên thiết bị này không?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Để sau'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Bật vân tay'),
            ),
          ],
        );
      },
    );

    if (enable != true || !mounted) return;

    try {
      final authenticated =
      await DeviceServices.authenticateWithBiometrics();

      if (!authenticated) {
        _message(
          'Xác thực không thành công, chưa bật vân tay.',
          error: true,
        );
        return;
      }

      await ApiClient.enableBiometricLogin();

      if (mounted) {
        _message('Đã bật đăng nhập bằng vân tay.');
      }
    } catch (e) {
      if (mounted) {
        _message(
          'Không thể bật vân tay: ${_errorText(e)}',
          error: true,
        );
      }
    }
  }

  // Đăng nhập bằng tài khoản và mật khẩu.
  Future<void> _login() async {
    final login = _usernameController.text.trim();

    final result = await AuthService.login(
      login: login,
      password: _passwordController.text,
    );

    _loginIdentifier = login;
    _otpEmail =
        (result['email'] ?? result['Email'] ?? '').toString();

    _loginOtp = true;
    _otpController.clear();

    if (!mounted) return;

    setState(() => _showOtp = true);

    _message(
      _otpEmail.isNotEmpty
          ? 'Mã OTP đã được gửi đến $_otpEmail.'
          : 'Hãy kiểm tra email để lấy mã OTP.',
    );
  }

  // Đăng ký tài khoản phụ huynh.
  Future<void> _registerParent() async {
    final result = await AuthService.registerParent(
      fullName: _nameController.text.trim(),
      username: _usernameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    _otpEmail = _emailController.text.trim();
    _loginOtp = false;
    _otpController.clear();

    if (!mounted) return;

    setState(() => _showOtp = true);

    _message(
      (result['message'] ??
          result['Message'] ??
          'Đăng ký thành công. Hãy kiểm tra email.')
          .toString(),
    );
  }

  // Đăng ký tài khoản trẻ.
  Future<void> _registerChild() async {
    final result = await AuthService.registerChild(
      fullName: _nameController.text.trim(),
      username: _usernameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      linkCode: _linkCodeController.text.trim(),
    );

    _otpEmail = _emailController.text.trim();
    _loginOtp = false;
    _otpController.clear();

    if (!mounted) return;

    setState(() => _showOtp = true);

    _message(
      (result['message'] ??
          result['Message'] ??
          'Đăng ký thành công. Hãy kiểm tra email.')
          .toString(),
    );
  }

  // Xác minh OTP đăng nhập hoặc đăng ký.
  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();

    if (otp.isEmpty) {
      _message('Vui lòng nhập mã OTP.', error: true);
      return;
    }

    if (_loading) return;

    setState(() => _loading = true);

    try {
      if (_loginOtp) {
        final AppUser user = await AuthService.verifyLoginOtp(
          login: _loginIdentifier,
          otp: otp,
        );

        if (!mounted) return;

        _message('Đăng nhập thành công.');

        // Hiện hộp thoại trước khi chuyển trang.
        // Lỗi vân tay không làm mất kết quả đăng nhập OTP.
        await _askToEnableBiometrics();

        if (!mounted) return;

        Navigator.of(context).pushNamedAndRemoveUntil(
          '/home',
              (route) => false,
          arguments: user.toJson(),
        );
      } else {
        if (_mode == _AuthMode.childRegister) {
          await AuthService.verifyChildEmail(
            email: _otpEmail,
            otp: otp,
          );
        } else {
          await AuthService.verifyParentEmail(
            email: _otpEmail,
            otp: otp,
          );
        }

        if (!mounted) return;

        _message(
          'Xác minh email thành công. Hãy đăng nhập.',
        );

        setState(() {
          _showOtp = false;
          _loginOtp = false;
          _mode = _AuthMode.login;
          _usernameController.text = _otpEmail;
          _passwordController.clear();
          _otpController.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        _message(_errorText(e), error: true);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _changeMode(_AuthMode mode) {
    setState(() {
      _mode = mode;
      _showOtp = false;
      _loginOtp = false;
      _passwordController.clear();
      _otpController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _brand(),
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: const Color(0xFFE8ECF4),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 25,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: _showOtp ? _otpForm() : _authForm(),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'ParentShield • Bảo vệ bằng sự tin tưởng',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.muted,
                      fontSize: 12,
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

  Widget _brand() {
    return Column(
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              colors: [
                Color(0xFF172554),
                Color(0xFF2563EB),
              ],
            ),
          ),
          child: const Icon(
            Icons.shield_rounded,
            color: Colors.white,
            size: 43,
          ),
        ),
        const SizedBox(height: 15),
        const Text(
          'ParentShield',
          style: TextStyle(
            color: AppTheme.navy,
            fontSize: 29,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 7),
        const Text(
          'Kết nối gia đình, bảo vệ an toàn số',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppTheme.muted,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _authForm() {
    final isLogin = _mode == _AuthMode.login;
    final isChild = _mode == _AuthMode.childRegister;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            isLogin
                ? 'Chào mừng trở lại'
                : isChild
                ? 'Đăng ký tài khoản trẻ'
                : 'Đăng ký phụ huynh',
            style: const TextStyle(
              color: AppTheme.navy,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isLogin
                ? 'Đăng nhập để tiếp tục sử dụng ParentShield.'
                : isChild
                ? 'Nhập thông tin và mã liên kết từ phụ huynh.'
                : 'Tạo tài khoản để quản lý thiết bị của trẻ.',
            style: const TextStyle(
              color: AppTheme.muted,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 22),

          if (!isLogin) ...[
            _input(
              controller: _nameController,
              label: 'Họ và tên',
              icon: Icons.person_outline,
              validator: (v) => _required(v, 'họ và tên'),
              capitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 14),
          ],

          _input(
            controller: _usernameController,
            label: isLogin ? 'Username hoặc email' : 'Tên đăng nhập',
            icon: Icons.account_circle_outlined,
            validator: (v) => _required(v, 'tên đăng nhập'),
          ),

          if (!isLogin) ...[
            const SizedBox(height: 14),
            _input(
              controller: _emailController,
              label: 'Email',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: _emailValidator,
            ),
          ],

          const SizedBox(height: 14),
          _input(
            controller: _passwordController,
            label: 'Mật khẩu',
            icon: Icons.lock_outline,
            obscure: _hidePassword,
            validator: _passwordValidator,
            suffix: IconButton(
              onPressed: () {
                setState(() => _hidePassword = !_hidePassword);
              },
              icon: Icon(
                _hidePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
          ),

          if (isChild) ...[
            const SizedBox(height: 14),
            _input(
              controller: _linkCodeController,
              label: 'Mã liên kết',
              icon: Icons.link_rounded,
              keyboardType: TextInputType.number,
              validator: (v) {
                final required = _required(v, 'mã liên kết');
                if (required != null) return required;

                if (v!.trim().length != 8) {
                  return 'Mã liên kết phải có 8 ký tự.';
                }

                return null;
              },
            ),
          ],

          const SizedBox(height: 22),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : Text(
                isLogin ? 'Đăng nhập' : 'Đăng ký và nhận OTP',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),

          // Chỉ hiện nút vân tay ở màn hình đăng nhập.
          if (isLogin) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: (_loading || _biometricLoading)
                  ? null
                  : _loginWithBiometrics,
              icon: _biometricLoading
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Icon(Icons.fingerprint_rounded),
              label: const Text('Đăng nhập bằng vân tay'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                foregroundColor: AppTheme.primary,
                side: const BorderSide(
                  color: Color(0xFFCBD5E1),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],

          const SizedBox(height: 18),
          const Divider(color: Color(0xFFE8ECF4)),
          const SizedBox(height: 12),

          if (isLogin) ...[
            const Center(
              child: Text(
                'Bạn chưa có tài khoản?',
                style: TextStyle(color: AppTheme.muted),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => _changeMode(_AuthMode.parentRegister),
              child: const Text('Đăng ký phụ huynh'),
            ),
            TextButton(
              onPressed: () => _changeMode(_AuthMode.childRegister),
              child: const Text('Đăng ký trẻ bằng mã liên kết'),
            ),
          ] else
            TextButton.icon(
              onPressed: () => _changeMode(_AuthMode.login),
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Quay lại đăng nhập'),
            ),
        ],
      ),
    );
  }

  Widget _otpForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(
          Icons.mark_email_read_outlined,
          color: AppTheme.primary,
          size: 52,
        ),
        const SizedBox(height: 15),
        const Text(
          'Xác minh OTP',
          style: TextStyle(
            color: AppTheme.navy,
            fontSize: 23,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _otpEmail.isEmpty
              ? 'Nhập mã OTP đã được gửi đến email của bạn.'
              : 'Nhập mã OTP gửi đến $_otpEmail',
          style: const TextStyle(
            color: AppTheme.muted,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 22),
        TextField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 8,
          decoration: InputDecoration(
            labelText: 'Mã OTP',
            counterText: '',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 50,
          child: FilledButton(
            onPressed: _loading ? null : _verifyOtp,
            child: _loading
                ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
                : const Text(
              'Xác minh',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: _loading
              ? null
              : () {
            setState(() {
              _showOtp = false;
              _loginOtp = false;
              _otpController.clear();
            });
          },
          icon: const Icon(Icons.arrow_back_rounded),
          label: const Text('Quay lại'),
        ),
      ],
    );
  }

  Widget _input({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    TextCapitalization capitalization = TextCapitalization.none,
    bool obscure = false,
    Widget? suffix,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      textCapitalization: capitalization,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppTheme.muted),
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFFFAFBFE),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}
