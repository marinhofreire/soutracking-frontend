import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/white_label.dart';
import '../../state/session_state.dart';
import '../home/home_shell.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  bool _obscurePassword = true;

  static const _pixelRefSize = Size(1672, 941);
  static const _pixelRefZoom = 0.95;
  static const _emailFieldRefRect = Rect.fromLTWH(569, 450, 532, 96);
  static const _passwordFieldRefRect = Rect.fromLTWH(569, 560, 532, 96);
  static const _forgotButtonRefRect = Rect.fromLTWH(928, 684, 188, 42);
  static const _submitButtonRefRect = Rect.fromLTWH(569, 713, 540, 77);
  static const _errorRefRect = Rect.fromLTWH(569, 798, 540, 36);

  @override
  void initState() {
    super.initState();
    _emailFocusNode.addListener(_rebuildForFocus);
    _passwordFocusNode.addListener(_rebuildForFocus);
  }

  void _rebuildForFocus() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _submitLogin(BuildContext context) async {
    final session = ref.read(sessionProvider);
    if (session.status == SessionStatus.loading) {
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    await ref.read(sessionProvider.notifier).login(
          email: email,
          password: password,
        );

    if (!context.mounted) return;

    final sessionNow = ref.read(sessionProvider);
    if (sessionNow.isAuthenticated) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => HomeShell(),
        ),
      );
    }
  }

  @override
  void dispose() {
    _emailFocusNode.removeListener(_rebuildForFocus);
    _passwordFocusNode.removeListener(_rebuildForFocus);
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final isLoading = session.status == SessionStatus.loading;
    final whiteLabelAsync = ref.watch(whiteLabelProvider);
    final config = whiteLabelAsync.value ?? WhiteLabelConfig.fallback;
    final usePixelReferenceLogin =
        config.appName.trim().toLowerCase().contains('soutracking');

    if (usePixelReferenceLogin) {
      return _buildPixelReferenceLogin(
        context: context,
        session: session,
        isLoading: isLoading,
      );
    }

    final media = MediaQuery.of(context);
    final isCompact = media.size.width < 760;
    final cardPadding = isCompact
        ? const EdgeInsets.symmetric(horizontal: 18, vertical: 20)
        : const EdgeInsets.symmetric(horizontal: 28, vertical: 26);
    const brandAccent = Color(0xFFF9C61B);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _LoginBackdrop(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? 14 : 28,
                  vertical: 16,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isCompact ? 430 : 540,
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xCC02101F),
                      borderRadius: BorderRadius.circular(isCompact ? 24 : 30),
                      border: Border.all(
                        color: const Color(0xFF1189FF).withValues(alpha: 0.85),
                        width: 1.05,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color:
                              const Color(0xFF0B8BFF).withValues(alpha: 0.45),
                          blurRadius: 45,
                          spreadRadius: 2,
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.45),
                          blurRadius: 28,
                          spreadRadius: 2,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: cardPadding,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _LoginBrand(
                            appName: config.appName,
                            compact: isCompact,
                          ),
                          const SizedBox(height: 12),
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              const Divider(
                                  color: Color(0xFF1A2B43), height: 1),
                              Container(
                                width: 76,
                                height: 3,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1BA9FF),
                                  borderRadius: BorderRadius.circular(999),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF1BA9FF)
                                          .withValues(alpha: 0.6),
                                      blurRadius: 14,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'PLATAFORMA DE GESTAO DE FROTAS',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: const Color(0xFF91A8C7)
                                  .withValues(alpha: 0.82),
                              fontSize: isCompact ? 10.5 : 12,
                              letterSpacing: 1.8,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 22),
                          _InputLabel(
                            icon: Icons.mail_outline,
                            text: 'E-mail',
                            compact: isCompact,
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: TextStyle(
                              color: Color(0xFFE7F0FF),
                              fontSize: isCompact ? 15.5 : 16.5,
                            ),
                            cursorColor: const Color(0xFF3DAFFF),
                            decoration: _inputDecoration(
                              hintText: 'Digite seu e-mail',
                              compact: isCompact,
                            ),
                            onSubmitted: (_) {
                              if (!isLoading) {
                                _submitLogin(context);
                              }
                            },
                          ),
                          const SizedBox(height: 14),
                          _InputLabel(
                            icon: Icons.lock_outline,
                            text: 'Senha',
                            compact: isCompact,
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            style: TextStyle(
                              color: Color(0xFFE7F0FF),
                              fontSize: isCompact ? 15.5 : 16.5,
                            ),
                            cursorColor: const Color(0xFF3DAFFF),
                            decoration: _inputDecoration(
                              hintText: 'Digite sua senha',
                              compact: isCompact,
                              suffix: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  child: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    color: const Color(0xFF8096B6),
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                            onSubmitted: (_) {
                              if (!isLoading) {
                                _submitLogin(context);
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {},
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF2FB0FF),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                textStyle: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              child: const Text('Esqueceu sua senha?'),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: isCompact ? 50 : 54,
                            child: ElevatedButton(
                              onPressed: isLoading
                                  ? null
                                  : () {
                                      _submitLogin(context);
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: brandAccent,
                                foregroundColor: const Color(0xFF111111),
                                disabledBackgroundColor:
                                    brandAccent.withValues(alpha: 0.5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                elevation: 0,
                                textStyle: TextStyle(
                                  fontSize: isCompact ? 17 : 19,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              child: isLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFF111111),
                                      ),
                                    )
                                  : Stack(
                                      alignment: Alignment.center,
                                      children: const [
                                        Align(
                                          alignment: Alignment.center,
                                          child: Text('Entrar'),
                                        ),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: Icon(
                                            Icons.arrow_forward,
                                            size: 24,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                          if (session.status == SessionStatus.error) ...[
                            const SizedBox(height: 14),
                            Text(
                              session.error ?? 'Falha ao autenticar',
                              style: const TextStyle(
                                color: Color(0xFFFF6B6B),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                          const SizedBox(height: 18),
                          Row(
                            children: const [
                              Expanded(
                                child: Divider(
                                    color: Color(0xFF23334A), height: 1),
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  'ou',
                                  style: TextStyle(
                                    color: Color(0xFF7388A4),
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Divider(
                                    color: Color(0xFF23334A), height: 1),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.verified_user_outlined,
                                color: Color(0xFF6F87A6),
                                size: 19,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Acesso seguro e protegido',
                                style: TextStyle(
                                  color: const Color(0xFF6F87A6)
                                      .withValues(alpha: 0.95),
                                  fontSize: isCompact ? 13 : 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
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

  InputDecoration _inputDecoration({
    required String hintText,
    required bool compact,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(
        color: const Color(0xFF758CAA),
        fontSize: compact ? 14.5 : 15.5,
      ),
      filled: true,
      fillColor: const Color(0x260A1C30),
      contentPadding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: compact ? 12 : 13,
      ),
      suffixIcon: suffix,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: const Color(0xFF365272).withValues(alpha: 0.68),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(
          color: Color(0xFF2EAAFF),
          width: 1.25,
        ),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: const Color(0xFF365272).withValues(alpha: 0.45),
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(
          color: Color(0xFFE56363),
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(
          color: Color(0xFFE56363),
          width: 1.2,
        ),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  Widget _buildPixelReferenceLogin({
    required BuildContext context,
    required SessionState session,
    required bool isLoading,
  }) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final viewport = Size(constraints.maxWidth, constraints.maxHeight);
          final fullCoverRect = _coverRect(viewport, _pixelRefSize);
          final coverRect = Rect.fromCenter(
            center: fullCoverRect.center,
            width: fullCoverRect.width * _pixelRefZoom,
            height: fullCoverRect.height * _pixelRefZoom,
          );
          final coverScale = coverRect.width / _pixelRefSize.width;

          Rect scaleRefRect(Rect source) {
            return Rect.fromLTWH(
              coverRect.left + source.left * coverScale,
              coverRect.top + source.top * coverScale,
              source.width * coverScale,
              source.height * coverScale,
            );
          }

          final emailRect = scaleRefRect(_emailFieldRefRect);
          final passwordRect = scaleRefRect(_passwordFieldRefRect);
          final forgotRect = scaleRefRect(_forgotButtonRefRect);
          final submitRect = scaleRefRect(_submitButtonRefRect);
          final errorRect = scaleRefRect(_errorRefRect);
          final fieldFontSize = (21.0 * coverScale).clamp(15.0, 23.0);
          final buttonRadius = (10 * coverScale).clamp(8.0, 14.0);
          final inputRadius = (10 * coverScale).clamp(8.0, 12.0).toDouble();
          final emailInputFocused = _emailFocusNode.hasFocus;
          final passwordInputFocused = _passwordFocusNode.hasFocus;
          final emailHasText = _emailController.text.isNotEmpty;
          final passwordHasText = _passwordController.text.isNotEmpty;

          return Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fromRect(
                rect: coverRect,
                child: Image.asset(
                  'assets/branding/login_pixel_reference.png',
                  fit: BoxFit.fill,
                ),
              ),
              Positioned.fromRect(
                rect: emailRect,
                child: TextField(
                  controller: _emailController,
                  focusNode: _emailFocusNode,
                  keyboardType: TextInputType.emailAddress,
                  textAlignVertical: TextAlignVertical.center,
                  style: TextStyle(
                    color: const Color(0xFFE7F0FF),
                    fontSize: fieldFontSize,
                    fontWeight: FontWeight.w500,
                    height: 1.0,
                  ),
                  cursorColor: const Color(0xFF3DAFFF),
                  decoration: _pixelInputDecoration(
                    hintText: 'Digite seu e-mail',
                    fillColor: emailInputFocused || emailHasText
                        ? const Color(0x66080C12)
                        : const Color(0x3D080C12),
                    borderColor: const Color(0x66A2A8B2),
                    focusedBorderColor: const Color(0xFFF9C61B),
                    borderRadius: inputRadius,
                    hintFontSize: fieldFontSize * 0.9,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 18 * coverScale,
                      vertical: 14 * coverScale,
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) {
                    if (!isLoading) {
                      _submitLogin(context);
                    }
                  },
                ),
              ),
              Positioned.fromRect(
                rect: passwordRect,
                child: TextField(
                  controller: _passwordController,
                  focusNode: _passwordFocusNode,
                  obscureText: _obscurePassword,
                  textAlignVertical: TextAlignVertical.center,
                  style: TextStyle(
                    color: const Color(0xFFE7F0FF),
                    fontSize: fieldFontSize,
                    fontWeight: FontWeight.w500,
                    height: 1.0,
                  ),
                  cursorColor: const Color(0xFF3DAFFF),
                  decoration: _pixelInputDecoration(
                    hintText: 'Digite sua senha',
                    fillColor: passwordInputFocused || passwordHasText
                        ? const Color(0x66080C12)
                        : const Color(0x3D080C12),
                    borderColor: const Color(0x66A2A8B2),
                    focusedBorderColor: const Color(0xFFF9C61B),
                    borderRadius: inputRadius,
                    hintFontSize: fieldFontSize * 0.9,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 18 * coverScale,
                      vertical: 14 * coverScale,
                    ),
                    suffix: IconButton(
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: const Color(0xFFAAB2BE),
                        size: 20 * coverScale,
                      ),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) {
                    if (!isLoading) {
                      _submitLogin(context);
                    }
                  },
                ),
              ),
              Positioned.fromRect(
                rect: forgotRect,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {},
                    borderRadius: BorderRadius.circular(8),
                    splashColor: const Color(0x223DAFFF),
                    highlightColor: const Color(0x123DAFFF),
                  ),
                ),
              ),
              Positioned.fromRect(
                rect: submitRect,
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(buttonRadius),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(buttonRadius),
                    onTap: isLoading
                        ? null
                        : () {
                            _submitLogin(context);
                          },
                    splashColor: const Color(0x18FFFFFF),
                    highlightColor: const Color(0x10FFFFFF),
                    child: Center(
                      child: isLoading
                          ? SizedBox(
                              width: 22 * coverScale,
                              height: 22 * coverScale,
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF111111),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
              if (session.status == SessionStatus.error)
                Positioned.fromRect(
                  rect: errorRect,
                  child: Center(
                    child: Text(
                      session.error ?? 'Falha ao autenticar',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: const Color(0xFFFF7A7A),
                        fontSize: (13.5 * coverScale).clamp(11.0, 16.0),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Rect _coverRect(Size output, Size input) {
    if (output.width <= 0 || output.height <= 0) {
      return Rect.zero;
    }
    final scale = math.max(
      output.width / input.width,
      output.height / input.height,
    );
    final fittedSize = Size(input.width * scale, input.height * scale);
    final dx = (output.width - fittedSize.width) / 2;
    final dy = (output.height - fittedSize.height) / 2;
    return Rect.fromLTWH(dx, dy, fittedSize.width, fittedSize.height);
  }

  InputDecoration _pixelInputDecoration({
    String? hintText,
    required Color fillColor,
    required Color borderColor,
    required Color focusedBorderColor,
    required double borderRadius,
    required double hintFontSize,
    required EdgeInsets contentPadding,
    Widget? suffix,
  }) {
    return InputDecoration(
      isCollapsed: false,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        borderSide: BorderSide(
          color: borderColor,
          width: 1.0,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        borderSide: BorderSide(
          color: borderColor,
          width: 1.0,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        borderSide: BorderSide(
          color: focusedBorderColor,
          width: 1.2,
        ),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        borderSide: BorderSide(
          color: borderColor.withValues(alpha: 0.4),
          width: 1.0,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        borderSide: const BorderSide(
          color: Color(0xFFE56363),
          width: 1.0,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        borderSide: const BorderSide(
          color: Color(0xFFE56363),
          width: 1.2,
        ),
      ),
      hintText: hintText,
      hintStyle: const TextStyle(
        color: Color(0xFFA5ADB9),
        fontWeight: FontWeight.w400,
      ).copyWith(fontSize: hintFontSize),
      contentPadding: contentPadding,
      filled: true,
      fillColor: fillColor,
      suffixIconConstraints: const BoxConstraints(
        minWidth: 46,
        minHeight: 46,
      ),
      suffixIcon: suffix,
    );
  }
}

class _InputLabel extends StatelessWidget {
  const _InputLabel({
    required this.icon,
    required this.text,
    required this.compact,
  });

  final IconData icon;
  final String text;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFB9CAE3), size: compact ? 17 : 18),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            color: Color(0xFFEAF3FF),
            fontSize: compact ? 14.5 : 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _LoginBrand extends StatelessWidget {
  const _LoginBrand({required this.appName, required this.compact});

  final String appName;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isSoutracking = appName.trim().toLowerCase().contains('soutracking');
    if (!isSoutracking) {
      return Text(
        appName,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white,
          fontSize: compact ? 28 : 32,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      );
    }

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: compact ? 34 : 42,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.7,
                height: 1,
              ),
              children: const [
                TextSpan(
                  text: 'SOU',
                  style: TextStyle(
                    color: Color(0xFFF3F7FF),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextSpan(
                  text: 'TRACKING',
                  style: TextStyle(
                    color: Color(0xFFF9C61B),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: compact ? 34 : 40,
            height: compact ? 34 : 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: const Color(0xFF35516F).withValues(alpha: 0.75),
              ),
              color: const Color(0x12000000),
            ),
            child: const Icon(
              Icons.lightbulb_outline_rounded,
              color: Color(0xFFF9C61B),
              size: 22,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginBackdrop extends StatelessWidget {
  const _LoginBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF010C1A),
                Color(0xFF02152B),
                Color(0xFF010914),
              ],
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.4, -0.2),
                radius: 1.1,
                colors: [
                  const Color(0xFF0A3568).withValues(alpha: 0.55),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        const Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _RouteGridPainter(),
            ),
          ),
        ),
        const Positioned.fill(
          child: IgnorePointer(
            child: _RoutePinsLayer(),
          ),
        ),
        Positioned.fill(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: 0.56,
              widthFactor: 1,
              child: CustomPaint(
                painter: _CityAndRoadPainter(),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.15),
                  Colors.black.withValues(alpha: 0.35),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RoutePinsLayer extends StatelessWidget {
  const _RoutePinsLayer();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        Widget buildPin(double x, double y) {
          return Positioned(
            left: constraints.maxWidth * x,
            top: constraints.maxHeight * y,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF0E56A8).withValues(alpha: 0.6),
                border: Border.all(
                  color: const Color(0xFF4AB8FF).withValues(alpha: 0.9),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF24A0FF).withValues(alpha: 0.42),
                    blurRadius: 14,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.directions_car_filled,
                size: 14,
                color: Color(0xFFCFE8FF),
              ),
            ),
          );
        }

        return Stack(
          children: [
            buildPin(0.84, 0.15),
            buildPin(0.88, 0.31),
            buildPin(0.8, 0.47),
          ],
        );
      },
    );
  }
}

class _RouteGridPainter extends CustomPainter {
  const _RouteGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFF2E74BE).withValues(alpha: 0.13)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (var i = -3; i <= 18; i++) {
      final x = i * size.width / 14;
      final path = Path()
        ..moveTo(x, 0)
        ..lineTo(x - size.width * 0.12, size.height);
      canvas.drawPath(path, gridPaint);
    }

    for (var i = 0; i <= 18; i++) {
      final y = i * size.height / 16;
      final path = Path()
        ..moveTo(0, y)
        ..lineTo(size.width, y + size.height * 0.08);
      canvas.drawPath(path, gridPaint);
    }

    final routePaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF1D87FF), Color(0xFF2BC5FF)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.4
      ..strokeCap = StrokeCap.round;

    final glowPaint = Paint()
      ..color = const Color(0xFF299CFF).withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    final route = Path()
      ..moveTo(size.width * 0.93, size.height * 0.08)
      ..cubicTo(
        size.width * 0.86,
        size.height * 0.15,
        size.width * 0.91,
        size.height * 0.24,
        size.width * 0.86,
        size.height * 0.32,
      )
      ..cubicTo(
        size.width * 0.8,
        size.height * 0.4,
        size.width * 0.86,
        size.height * 0.46,
        size.width * 0.81,
        size.height * 0.56,
      )
      ..cubicTo(
        size.width * 0.75,
        size.height * 0.64,
        size.width * 0.82,
        size.height * 0.78,
        size.width * 0.76,
        size.height * 0.93,
      );

    canvas.drawPath(route, glowPaint);
    canvas.drawPath(route, routePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CityAndRoadPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final skylinePaint = Paint()..color = const Color(0xFF08131F);
    final skylineGlowPaint = Paint()
      ..color = const Color(0xFF0A2644).withValues(alpha: 0.8)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    final buildingHeights = <double>[0.34, 0.45, 0.3, 0.54, 0.38, 0.48, 0.36];
    final buildingWidths = <double>[0.08, 0.1, 0.07, 0.12, 0.09, 0.11, 0.1];

    var cursor = size.width * 0.04;
    for (var i = 0; i < buildingHeights.length; i++) {
      final width = size.width * buildingWidths[i];
      final height = size.height * buildingHeights[i];
      final left = cursor;
      final top = size.height - height;
      final rect = Rect.fromLTWH(left, top, width, height);
      canvas.drawRect(rect, skylinePaint);

      final windowPaint = Paint()
        ..color =
            const Color(0xFF5EC0FF).withValues(alpha: i.isEven ? 0.22 : 0.14);
      final rowCount = math.max(2, (height / 26).floor());
      final colCount = math.max(2, (width / 16).floor());
      for (var row = 0; row < rowCount; row++) {
        for (var col = 0; col < colCount; col++) {
          if ((row + col + i) % 3 == 0) continue;
          final wx = left + 4 + col * (width - 8) / colCount;
          final wy = top + 6 + row * (height - 12) / rowCount;
          canvas.drawRect(Rect.fromLTWH(wx, wy, 2.5, 4), windowPaint);
        }
      }

      canvas.drawRect(
        Rect.fromLTWH(left, top, width, 2),
        skylineGlowPaint,
      );
      cursor += width + size.width * 0.02;
    }

    final roadGlowPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Color(0xFFFFB347),
          Color(0xFF67BEFF),
        ],
      ).createShader(
          Rect.fromLTWH(0, size.height * 0.45, size.width, size.height))
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 34
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 11);

    final roadCorePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Color(0xFFFFA733),
          Color(0xFFBEE2FF),
        ],
      ).createShader(
          Rect.fromLTWH(0, size.height * 0.45, size.width, size.height))
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 11;

    final roadPath = Path()
      ..moveTo(size.width * 0.03, size.height)
      ..cubicTo(
        size.width * 0.07,
        size.height * 0.78,
        size.width * 0.18,
        size.height * 0.63,
        size.width * 0.28,
        size.height * 0.52,
      )
      ..cubicTo(
        size.width * 0.38,
        size.height * 0.43,
        size.width * 0.5,
        size.height * 0.4,
        size.width * 0.63,
        size.height * 0.39,
      );

    canvas.drawPath(roadPath, roadGlowPaint);
    canvas.drawPath(roadPath, roadCorePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
