import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/bar_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _loginFormKey    = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();

  // Login fields + focus nodes
  final _loginEmail      = TextEditingController();
  final _loginPass       = TextEditingController();
  final _loginEmailFocus = FocusNode();
  final _loginPassFocus  = FocusNode();

  // Register fields + focus nodes
  final _regName       = TextEditingController();
  final _regEmail      = TextEditingController();
  final _regPass       = TextEditingController();
  final _regNameFocus  = FocusNode();
  final _regEmailFocus = FocusNode();
  final _regPassFocus  = FocusNode();

  bool _obscureLogin = true;
  bool _obscureReg   = true;
  bool _loading      = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() {
      setState(() => _error = null);
      if (_tabs.index == 0) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) FocusScope.of(context).requestFocus(_loginEmailFocus);
        });
      } else {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) FocusScope.of(context).requestFocus(_regNameFocus);
        });
      }
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _loginEmail.dispose();     _loginPass.dispose();
    _loginEmailFocus.dispose(); _loginPassFocus.dispose();
    _regName.dispose();   _regEmail.dispose();   _regPass.dispose();
    _regNameFocus.dispose(); _regEmailFocus.dispose(); _regPassFocus.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_loginFormKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      await context.read<BarProvider>().login(
          _loginEmail.text.trim(), _loginPass.text.trim());
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _register() async {
    if (!_registerFormKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      await context.read<BarProvider>().register(
          _regName.text.trim(), _regEmail.text.trim(), _regPass.text.trim());
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Staff login — asks for bar ID then pushes PIN screen ──────────────────
  void _openStaffLogin() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _StaffBarIdSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── Background gradient ────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF87CEEB),
                  Color(0xFF0097A7),
                  Color(0xFF006B77),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.55, 1.0],
              ),
            ),
          ),

          // ── Sun glow ──────────────────────────────────────────────────
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.sunYellow.withOpacity(0.45),
                    AppTheme.sunYellow.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),

          // ── Waves ─────────────────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: CustomPaint(
              painter: _WavePainter(),
              size: const Size(double.infinity, 180),
            ),
          ),

          // ── Content ───────────────────────────────────────────────────
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
              child: Column(
                children: [
                  const SizedBox(height: 32),

                  // Brand icon
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.ocean.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.beach_access_rounded,
                      color: AppTheme.ocean,
                      size: 38,
                    ),
                  ),
                  const SizedBox(height: 16),

                  const Text(
                    'SumrTime',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const Text(
                    'Beach Bar Manager',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 36),

                  // ── Auth card ─────────────────────────────────────────
                  Container(
                    width: 400,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(6),
                          child: TabBar(
                            controller: _tabs,
                            dividerColor: Colors.transparent,
                            indicator: BoxDecoration(
                              gradient: AppGradients.sunsetGradient,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            labelColor: Colors.white,
                            unselectedLabelColor: AppTheme.textSecondary,
                            labelStyle: const TextStyle(
                              fontFamily: 'Nunito',
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                            unselectedLabelStyle: const TextStyle(
                              fontFamily: 'Nunito',
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                            tabs: const [
                              Padding(
                                padding: EdgeInsets.all(10),
                                child: Tab(text: 'Sign In'),
                              ),
                              Padding(
                                padding: EdgeInsets.all(10),
                                child: Tab(text: 'Register'),
                              ),
                            ],
                          ),
                        ),

                        if (_error != null)
                          Container(
                            margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppTheme.danger.withOpacity(.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: AppTheme.danger.withOpacity(.25)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline_rounded,
                                    color: AppTheme.danger, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: const TextStyle(
                                      color: AppTheme.danger,
                                      fontSize: 13,
                                      fontFamily: 'Nunito',
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          width: 400,
                          height: _tabs.index == 0 ? 220 : 280,
                          child: TabBarView(
                            controller: _tabs,
                            children: [
                              _loginForm(),
                              _registerForm(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Staff login button ─────────────────────────────────
                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: _openStaffLogin,
                    child: Container(
                      width: 400,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.25), width: 1.2),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.badge_outlined,
                              color: Colors.white70, size: 20),
                          SizedBox(width: 10),
                          Text(
                            'Staff? Log in with your PIN',
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),),
            ),
          ),
        ],
      ),
    );
  }

  // ── Login form ─────────────────────────────────────────────────────────────
  Widget _loginForm() {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Form(
        key: _loginFormKey,
        child: Column(
          children: [
            TextFormField(
              controller: _loginEmail,
              focusNode: _loginEmailFocus,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              onFieldSubmitted: (_) =>
                  FocusScope.of(context).requestFocus(_loginPassFocus),
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon:
                    Icon(Icons.email_outlined, color: AppTheme.dune, size: 20),
              ),
              validator: (v) =>
                  v!.contains('@') ? null : 'Enter a valid email',
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _loginPass,
              focusNode: _loginPassFocus,
              obscureText: _obscureLogin,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _login(),
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline_rounded,
                    color: AppTheme.dune, size: 20),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureLogin
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: AppTheme.dune,
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _obscureLogin = !_obscureLogin),
                ),
              ),
              validator: (v) => v!.length >= 6 ? null : 'Min 6 characters',
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: 'Sign In',
              icon: Icons.login_rounded,
              onTap: _login,
              loading: _loading,
            ),
          ],
        ),
      ),
    );
  }

  // ── Register form ──────────────────────────────────────────────────────────
  Widget _registerForm() {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Form(
        key: _registerFormKey,
        child: Column(
          children: [
            TextFormField(
              controller: _regName,
              focusNode: _regNameFocus,
              autofocus: false,
              textInputAction: TextInputAction.next,
              onFieldSubmitted: (_) =>
                  FocusScope.of(context).requestFocus(_regEmailFocus),
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Bar Name',
                prefixIcon:
                    Icon(Icons.store_outlined, color: AppTheme.dune, size: 20),
              ),
              validator: (v) => v!.isNotEmpty ? null : 'Required',
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _regEmail,
              focusNode: _regEmailFocus,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              onFieldSubmitted: (_) =>
                  FocusScope.of(context).requestFocus(_regPassFocus),
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon:
                    Icon(Icons.email_outlined, color: AppTheme.dune, size: 20),
              ),
              validator: (v) =>
                  v!.contains('@') ? null : 'Enter a valid email',
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _regPass,
              focusNode: _regPassFocus,
              obscureText: _obscureReg,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _register(),
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline_rounded,
                    color: AppTheme.dune, size: 20),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureReg
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: AppTheme.dune,
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _obscureReg = !_obscureReg),
                ),
              ),
              validator: (v) => v!.length >= 6 ? null : 'Min 6 characters',
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: 'Create Account',
              icon: Icons.beach_access_rounded,
              onTap: _register,
              loading: _loading,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Staff login sheet — join code + name + PIN ────────────────────────────────
class _StaffBarIdSheet extends StatefulWidget {
  const _StaffBarIdSheet();

  @override
  State<_StaffBarIdSheet> createState() => _StaffBarIdSheetState();
}

class _StaffBarIdSheetState extends State<_StaffBarIdSheet> {
  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _pinCtrl  = TextEditingController();
  bool    _loading = false;
  String? _error;

  Future<void> _submit() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    final name = _nameCtrl.text.trim();
    final pin  = _pinCtrl.text.trim();

    if (code.length != 6) {
      setState(() => _error = 'Join code must be 6 characters');
      return;
    }
    if (name.isEmpty) {
      setState(() => _error = 'Enter your name');
      return;
    }
    if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
      setState(() => _error = 'PIN must be exactly 4 digits');
      return;
    }

    setState(() { _loading = true; _error = null; });
    try {
      await context.read<BarProvider>().staffLogin(code, name, pin);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = e
          .toString()
          .replaceAll('ApiException(401): ', '')
          .replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppTheme.pebble,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          const Text(
            'Staff Login',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Ask your manager for the 6-character join code.',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 20),

          // Join code
          TextField(
            controller: _codeCtrl,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            maxLength: 6,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Join Code',
              hintText: 'e.g. SUN42X',
              prefixIcon: Icon(Icons.store_outlined, color: AppTheme.dune),
              counterText: '',
            ),
          ),
          const SizedBox(height: 12),

          // Name
          TextField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Your Name',
              prefixIcon: Icon(Icons.person_outline_rounded, color: AppTheme.dune),
            ),
          ),
          const SizedBox(height: 12),

          // PIN
          TextField(
            controller: _pinCtrl,
            keyboardType: TextInputType.number,
            maxLength: 4,
            obscureText: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: const InputDecoration(
              labelText: '4-digit PIN',
              prefixIcon: Icon(Icons.pin_outlined, color: AppTheme.dune),
              counterText: '',
            ),
          ),

          // Error
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: const TextStyle(
                color: Colors.red,
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.ocean,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _loading
                  ? const SizedBox(
                      height: 20, width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text(
                      'Log In',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Wave painter ──────────────────────────────────────────────────────────────
class _WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final backPaint = Paint()
      ..color = Colors.white.withOpacity(0.12)
      ..style = PaintingStyle.fill;

    final backPath = Path()
      ..moveTo(0, size.height * 0.5)
      ..quadraticBezierTo(size.width * 0.3, size.height * 0.25,
          size.width * 0.6, size.height * 0.5)
      ..quadraticBezierTo(
          size.width * 0.85, size.height * 0.75, size.width, size.height * 0.5)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(backPath, backPaint);

    final frontPaint = Paint()
      ..color = Colors.white.withOpacity(0.18)
      ..style = PaintingStyle.fill;

    final frontPath = Path()
      ..moveTo(0, size.height * 0.65)
      ..quadraticBezierTo(size.width * 0.25, size.height * 0.45,
          size.width * 0.5, size.height * 0.65)
      ..quadraticBezierTo(
          size.width * 0.75, size.height * 0.85, size.width, size.height * 0.65)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(frontPath, frontPaint);
  }

  @override
  bool shouldRepaint(_) => false;
}