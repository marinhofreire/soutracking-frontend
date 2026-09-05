import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/checkin_password.dart';
import '../../data/models.dart';
import '../../data/traccar_client.dart';
import '../../state/session_state.dart';

/// Landing pública de check-in de motorista, acessada via QR code fixo no
/// veículo (rota /checkin/device/:deviceId, ver core/app_router.dart).
/// Fora do fluxo de login do painel -- motorista não é um User do Traccar,
/// então a autenticação aqui é local (CNH/telefone + senha de check-in,
/// ver core/checkin_password.dart) e quem realmente fala com o Traccar é
/// uma conta técnica fixa (ver _TechnicalSession).
///
/// Peça inicial de uma arquitetura maior (usuário confirmou, 2026-09-06):
/// o mesmo padrão -- ator escaneia/loga, sistema registra presença num
/// alvo, marca entrada/saída -- deve servir depois pra check-in de
/// passageiro no fretado e check-in/checkout de encomenda. Por isso o
/// vínculo fica modelado como "motorista ativo no veículo" (1 por vez,
/// nunca dois motoristas no mesmo veículo ao mesmo tempo) em vez de um
/// hack específico só pra esta tela.
class VehicleCheckinScreen extends ConsumerStatefulWidget {
  const VehicleCheckinScreen({super.key, required this.deviceId});

  final int deviceId;

  @override
  ConsumerState<VehicleCheckinScreen> createState() =>
      _VehicleCheckinScreenState();
}

enum _CheckinStage { loading, form, submitting, success, error }

class _VehicleCheckinScreenState extends ConsumerState<VehicleCheckinScreen> {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();

  _CheckinStage _stage = _CheckinStage.loading;
  TraccarDevice? _device;
  String? _errorMessage;
  TraccarDriver? _matchedDriver;

  @override
  void initState() {
    super.initState();
    _loadDevice();
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadDevice() async {
    setState(() => _stage = _CheckinStage.loading);
    try {
      final client = ref.read(traccarClientProvider);
      final session = await _technicalSession(client);
      final devices = await client.getDevices(
        cookie: session.cookie,
        authHeader: session.authHeader,
        id: widget.deviceId,
      );
      if (devices.isEmpty) {
        setState(() {
          _stage = _CheckinStage.error;
          _errorMessage = 'Veículo não encontrado. Confira o QR code.';
        });
        return;
      }
      setState(() {
        _device = devices.first;
        _stage = _CheckinStage.form;
      });
    } catch (error) {
      setState(() {
        _stage = _CheckinStage.error;
        _errorMessage = 'Não foi possível carregar o veículo agora. '
            'Tente novamente em instantes.';
      });
    }
  }

  // Conta técnica fixa (não é a sessão de nenhum operador do painel) --
  // única forma de autenticar contra o Traccar aqui, já que o motorista
  // não é um User. Configurável via --dart-define, sem credencial embutida
  // no código-fonte (ver core/app_router.dart para o mesmo padrão de
  // credencial de rota pública via String.fromEnvironment).
  Future<TraccarSession> _technicalSession(TraccarClient client) async {
    const email = String.fromEnvironment('CHECKIN_TECH_EMAIL');
    const password = String.fromEnvironment('CHECKIN_TECH_PASSWORD');
    if (email.isEmpty || password.isEmpty) {
      throw StateError(
        'Credencial técnica de check-in não configurada '
        '(--dart-define=CHECKIN_TECH_EMAIL=... CHECKIN_TECH_PASSWORD=...).',
      );
    }
    return client.login(email: email, password: password);
  }

  Future<void> _submit() async {
    final identifier = _identifierController.text.trim();
    final password = _passwordController.text;
    if (identifier.isEmpty || password.isEmpty) {
      setState(() {
        _stage = _CheckinStage.error;
        _errorMessage = 'Informe seu identificador e senha.';
      });
      return;
    }

    setState(() => _stage = _CheckinStage.submitting);
    try {
      final client = ref.read(traccarClientProvider);
      final session = await _technicalSession(client);
      final drivers = await client.getDrivers(
        cookie: session.cookie,
        authHeader: session.authHeader,
      );

      final normalizedIdentifier = identifier.toLowerCase();
      TraccarDriver? matched;
      for (final driver in drivers) {
        final uniqueId = driver.uniqueId.toLowerCase();
        final phone =
            (driver.attributes?['phone'] ?? '').toString().toLowerCase();
        final cnh =
            (driver.attributes?['cnh'] ?? '').toString().toLowerCase();
        if (uniqueId == normalizedIdentifier ||
            (phone.isNotEmpty && phone == normalizedIdentifier) ||
            (cnh.isNotEmpty && cnh == normalizedIdentifier)) {
          matched = driver;
          break;
        }
      }

      if (matched == null) {
        setState(() {
          _stage = _CheckinStage.error;
          _errorMessage = 'Motorista não encontrado. Confira seus dados.';
        });
        return;
      }

      final storedHash = matched.attributes?['souPasswordHash'] as String?;
      if (!checkinPasswordMatches(password, storedHash)) {
        setState(() {
          _stage = _CheckinStage.error;
          _errorMessage = 'Senha incorreta.';
        });
        return;
      }

      // Um veículo tem um motorista ativo por vez -- se havia alguém
      // vinculado antes, remove o vínculo antigo antes de criar o novo
      // (Traccar não faz "check-out automático" sozinho).
      final previousDriverId = _device?.attributes?['souCurrentDriverId'];
      if (previousDriverId is int && previousDriverId != matched.id) {
        try {
          await client.unlinkDriverFromDevice(
            driverId: previousDriverId,
            deviceId: widget.deviceId,
            cookie: session.cookie,
            authHeader: session.authHeader,
          );
        } catch (_) {
          // Vínculo antigo pode já não existir (removido manualmente) --
          // não bloqueia o novo check-in por isso.
        }
      }

      await client.linkDriverToDevice(
        driverId: matched.id,
        deviceId: widget.deviceId,
        cookie: session.cookie,
        authHeader: session.authHeader,
      );

      final now = DateTime.now().toIso8601String();
      await client.updateEntityById(
        path: '/devices',
        id: widget.deviceId,
        cookie: session.cookie,
        authHeader: session.authHeader,
        body: {
          'id': widget.deviceId,
          'name': _device!.name,
          if (_device!.uniqueId != null) 'uniqueId': _device!.uniqueId,
          if (_device!.category != null) 'category': _device!.category,
          'attributes': {
            ...?_device!.attributes,
            'souCurrentDriverId': matched.id,
            'souCurrentDriverName': matched.name,
            'souLastCheckinAt': now,
          },
        },
      );
      await client.updateEntityById(
        path: '/drivers',
        id: matched.id,
        cookie: session.cookie,
        authHeader: session.authHeader,
        body: {
          'id': matched.id,
          'name': matched.name,
          'uniqueId': matched.uniqueId,
          'attributes': {
            ...?matched.attributes,
            'souCurrentDeviceId': widget.deviceId,
            'souLastCheckinAt': now,
          },
        },
      );

      setState(() {
        _matchedDriver = matched;
        _stage = _CheckinStage.success;
      });
    } catch (error) {
      setState(() {
        _stage = _CheckinStage.error;
        _errorMessage = 'Falha ao registrar o check-in. Tente novamente.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FA),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFDDE5F0)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: _buildContent(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_stage) {
      case _CheckinStage.loading:
        return const SizedBox(
          height: 160,
          child: Center(child: CircularProgressIndicator()),
        );
      case _CheckinStage.success:
        return _buildSuccess();
      case _CheckinStage.form:
      case _CheckinStage.submitting:
      case _CheckinStage.error:
        return _buildForm();
    }
  }

  Widget _buildSuccess() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle_rounded,
            color: Color(0xFF16A34A), size: 56),
        const SizedBox(height: 12),
        Text(
          'Check-in confirmado!',
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 18,
            color: Color(0xFF1F2A44),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${_matchedDriver?.name ?? 'Você'} está no veículo '
          '${_device?.name ?? ''} desde agora.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF60718D), fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.directions_car_filled_rounded,
            color: Color(0xFF176EEB), size: 40),
        const SizedBox(height: 10),
        Text(
          _device?.name ?? 'Check-in do veículo',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 17,
            color: Color(0xFF1F2A44),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Informe seus dados de motorista para assumir este veículo.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF60718D), fontSize: 12.5),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _identifierController,
          decoration: const InputDecoration(
            labelText: 'CNH, telefone ou identificador',
            filled: true,
            fillColor: Color(0xFFF7F9FD),
            border: OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFDDE5F0)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passwordController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Senha de check-in',
            filled: true,
            fillColor: Color(0xFFF7F9FD),
            border: OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFDDE5F0)),
            ),
          ),
          onSubmitted: (_) => _submit(),
        ),
        if (_stage == _CheckinStage.error && _errorMessage != null) ...[
          const SizedBox(height: 10),
          Text(
            _errorMessage!,
            style: const TextStyle(color: Color(0xFFB42318), fontSize: 12.5),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _stage == _CheckinStage.submitting ? null : _submit,
          child: _stage == _CheckinStage.submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Entrar no veículo'),
        ),
      ],
    );
  }
}
