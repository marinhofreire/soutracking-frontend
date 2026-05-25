import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../data/traccar_client.dart';
import '../../state/session_state.dart';

class AssistantMessage {
  const AssistantMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });

  final String text;
  final bool isUser;
  final DateTime timestamp;
}

class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key});

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<AssistantMessage> _messages = [
    AssistantMessage(
      text:
          'Olá! Sou seu assistente. Peça algo como: "Criar cerca na Rua X" ou "Relatório da placa ABC".',
      isUser: false,
      timestamp: DateTime.now(),
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      _messages.add(
        AssistantMessage(
          text: trimmed,
          isUser: true,
          timestamp: DateTime.now(),
        ),
      );
    });
    _controller.clear();
    _scrollToEnd();

    final response = await _handleIntent(trimmed);
    if (!mounted) return;
    setState(() {
      _messages.add(
        AssistantMessage(
          text: response,
          isUser: false,
          timestamp: DateTime.now(),
        ),
      );
    });
    _scrollToEnd();
  }

  Future<String> _handleIntent(String input) async {
    final session = ref.read(sessionProvider);
    if (!session.isAuthenticated) {
      return 'Você precisa estar logado para executar comandos.';
    }

    final text = input.toLowerCase();
    final client = ref.read(traccarClientProvider);
    final devices = await ref.read(devicesProvider.future);

    final compoundResponse = await _handleCompoundGeofenceAutomation(
      input: input,
      text: text,
      client: client,
      session: session,
    );
    if (compoundResponse != null) {
      return compoundResponse;
    }

    if (text.contains('alerta') && text.contains('cerca')) {
      final fences = await client.getList(
        path: '/geofences',
        cookie: session.cookie,
        authHeader: session.authHeader,
      );
      if (fences.isEmpty) {
        return 'Nenhuma cerca cadastrada para criar o alerta.';
      }
      final fenceQuery = _extractAfterKeyword(input, const ['cerca']) ?? '';
      final fence = _findGeofence(fences, fenceQuery);
      if (fence == null) {
        return 'Não encontrei a cerca. Informe o nome exato.';
      }
      final type = text.contains('saida') || text.contains('saída')
          ? 'geofenceExit'
          : 'geofenceEnter';
      try {
        await client.createEntity(
          path: '/notifications',
          cookie: session.cookie,
          authHeader: session.authHeader,
          body: {
            'name': 'Geofence ${fence['name']} ($type)',
            'type': type,
            'always': true,
            'notificators': ['web'],
            'attributes': {'geofenceId': fence['id']},
          },
        );
        ref.invalidate(notificationsProvider);
        return 'Alerta de cerca criado para ${fence['name']} ($type).';
      } catch (e) {
        return 'Falha ao criar alerta de cerca: $e';
      }
    }

    if (text.contains('cerca') || text.contains('geofence')) {
      final numbers = _extractNumbers(input);
      if (numbers.length >= 3) {
        final lat = numbers[0];
        final lon = numbers[1];
        final radius = numbers[2];
        final name = _extractName(
          input,
          fallback: 'Cerca criada pelo assistente',
        );
        final area = 'CIRCLE ($lat $lon, $radius)';
        try {
          await client.createEntity(
            path: '/geofences',
            cookie: session.cookie,
            authHeader: session.authHeader,
            body: {'name': name, 'area': area},
          );
          ref.invalidate(geofencesProvider);
          return 'Cerca criada: $name (raio ${radius.toStringAsFixed(0)}m).';
        } catch (e) {
          return 'Falha ao criar cerca: $e';
        }
      }
      return 'Para criar cerca, informe: "Criar cerca LAT LON RAIO". Ex: -23.56 -46.64 200.';
    }

    if ((text.contains('relatorio') || text.contains('relatório')) &&
        text.contains('evento')) {
      final plate = _extractPlate(input);
      final device = _findDevice(devices, plate ?? input);
      if (device == null) {
        return 'Não encontrei o veículo. Informe a placa ou nome exato.';
      }
      return _runReport(
        client: client,
        session: session,
        deviceId: device.id,
        path: '/reports/events',
        label: 'eventos',
      );
    }

    if ((text.contains('relatorio') || text.contains('relatório')) &&
        text.contains('viagem')) {
      final plate = _extractPlate(input);
      final device = _findDevice(devices, plate ?? input);
      if (device == null) {
        return 'Não encontrei o veículo. Informe a placa ou nome exato.';
      }
      return _runReport(
        client: client,
        session: session,
        deviceId: device.id,
        path: '/reports/trips',
        label: 'viagens',
      );
    }

    if ((text.contains('relatorio') || text.contains('relatório')) &&
        text.contains('parada')) {
      final plate = _extractPlate(input);
      final device = _findDevice(devices, plate ?? input);
      if (device == null) {
        return 'Não encontrei o veículo. Informe a placa ou nome exato.';
      }
      return _runReport(
        client: client,
        session: session,
        deviceId: device.id,
        path: '/reports/stops',
        label: 'paradas',
      );
    }

    if ((text.contains('relatorio') || text.contains('relatório')) &&
        text.contains('resumo')) {
      final plate = _extractPlate(input);
      final device = _findDevice(devices, plate ?? input);
      if (device == null) {
        return 'Não encontrei o veículo. Informe a placa ou nome exato.';
      }
      return _runReport(
        client: client,
        session: session,
        deviceId: device.id,
        path: '/reports/summary',
        label: 'resumo',
      );
    }

    if (text.contains('relatorio') || text.contains('relatório')) {
      final plate = _extractPlate(input);
      final device = _findDevice(devices, plate ?? input);
      if (device == null) {
        return 'Não encontrei o veículo. Informe a placa ou nome exato.';
      }
      return _runReport(
        client: client,
        session: session,
        deviceId: device.id,
        path: '/reports/route',
        label: 'rotas',
      );
    }

    if (text.contains('status')) {
      final plate = _extractPlate(input);
      final device = _findDevice(devices, plate ?? input);
      if (device == null) {
        return 'Não encontrei o veículo. Informe a placa ou nome exato.';
      }
      return 'Status do ${device.name}: ${device.status}. Última atualização: ${device.lastUpdate ?? 'N/A'}.';
    }

    if (text.contains('alerta') && text.contains('igni')) {
      final plate = _extractPlate(input);
      final device = _findDevice(devices, plate ?? input);
      if (device == null) {
        return 'Não encontrei o veículo. Informe a placa ou nome exato.';
      }
      if (text.contains('desativar') || text.contains('desligar')) {
        try {
          final notifications = await client.getList(
            path: '/notifications',
            cookie: session.cookie,
            authHeader: session.authHeader,
          );
          final target = _findNotificationType(
            notifications,
            device.name,
            'ignition',
          );
          if (target == null) {
            return 'Nenhum alerta de ignição encontrado para ${device.name}.';
          }
          await client.updateEntity(
            path: '/notifications/${target['id']}',
            cookie: session.cookie,
            authHeader: session.authHeader,
            body: {'id': target['id'], 'always': false},
          );
          ref.invalidate(notificationsProvider);
          return 'Alerta de ignição desativado para ${device.name}.';
        } catch (e) {
          return 'Falha ao desativar alerta de ignição: $e';
        }
      }
      final type = text.contains('desligar') || text.contains('off')
          ? 'ignitionOff'
          : 'ignitionOn';
      try {
        await client.createEntity(
          path: '/notifications',
          cookie: session.cookie,
          authHeader: session.authHeader,
          body: {
            'name': 'Ignition ${device.name} ($type)',
            'type': type,
            'always': true,
            'notificators': ['web'],
          },
        );
        ref.invalidate(notificationsProvider);
        return 'Alerta de ignição criado para ${device.name} ($type).';
      } catch (e) {
        return 'Falha ao criar alerta de ignição: $e';
      }
    }

    if (text.contains('alerta') && text.contains('veloc')) {
      if (text.contains('desativar') || text.contains('desligar')) {
        final plate = _extractPlate(input);
        final device = _findDevice(devices, plate ?? input);
        if (device == null) {
          return 'Não encontrei o veículo. Informe a placa ou nome exato.';
        }
        try {
          final notifications = await client.getList(
            path: '/notifications',
            cookie: session.cookie,
            authHeader: session.authHeader,
          );
          final target = _findNotification(notifications, device.name);
          if (target == null) {
            return 'Nenhum alerta de velocidade encontrado para ${device.name}.';
          }
          await client.updateEntity(
            path: '/notifications/${target['id']}',
            cookie: session.cookie,
            authHeader: session.authHeader,
            body: {'id': target['id'], 'always': false},
          );
          ref.invalidate(notificationsProvider);
          return 'Alerta de velocidade desativado para ${device.name}.';
        } catch (e) {
          return 'Falha ao desativar alerta de velocidade: $e';
        }
      }
      final speed = _extractFirstNumber(input);
      if (speed == null) {
        return 'Informe a velocidade. Ex: "Ativar alerta de velocidade 80".';
      }
      final plate = _extractPlate(input);
      final device = _findDevice(devices, plate ?? input);
      if (device == null) {
        return 'Não encontrei o veículo. Informe a placa ou nome exato.';
      }
      try {
        await client.createEntity(
          path: '/notifications',
          cookie: session.cookie,
          authHeader: session.authHeader,
          body: {
            'name': 'Overspeed ${device.name} ${speed.toStringAsFixed(0)}',
            'type': 'overspeed',
            'always': true,
            'notificators': ['web'],
            'attributes': {'speed': speed},
          },
        );
        ref.invalidate(notificationsProvider);
        return 'Alerta de velocidade criado para ${device.name} (limite ${speed.toStringAsFixed(0)}).';
      } catch (e) {
        return 'Falha ao criar alerta de velocidade: $e';
      }
    }

    if (text.contains('alerta') &&
        (text.contains('offline') || text.contains('online'))) {
      final plate = _extractPlate(input);
      final device = _findDevice(devices, plate ?? input);
      if (device == null) {
        return 'Não encontrei o veículo. Informe a placa ou nome exato.';
      }
      final type = text.contains('offline') ? 'deviceOffline' : 'deviceOnline';
      return _createSimpleAlert(
        client: client,
        session: session,
        type: type,
        name: '${type.toUpperCase()} ${device.name}',
      );
    }

    if (text.contains('alerta') && text.contains('movimento')) {
      final plate = _extractPlate(input);
      final device = _findDevice(devices, plate ?? input);
      if (device == null) {
        return 'Não encontrei o veículo. Informe a placa ou nome exato.';
      }
      return _createSimpleAlert(
        client: client,
        session: session,
        type: 'deviceMoving',
        name: 'MOVIMENTO ${device.name}',
      );
    }

    if (text.contains('alerta') &&
        (text.contains('parada') || text.contains('parado'))) {
      final plate = _extractPlate(input);
      final device = _findDevice(devices, plate ?? input);
      if (device == null) {
        return 'Não encontrei o veículo. Informe a placa ou nome exato.';
      }
      return _createSimpleAlert(
        client: client,
        session: session,
        type: 'deviceStopped',
        name: 'PARADA ${device.name}',
      );
    }

    if (text.contains('alerta') &&
        (text.contains('inatividade') || text.contains('ocioso'))) {
      final plate = _extractPlate(input);
      final device = _findDevice(devices, plate ?? input);
      if (device == null) {
        return 'Não encontrei o veículo. Informe a placa ou nome exato.';
      }
      return _createSimpleAlert(
        client: client,
        session: session,
        type: 'idle',
        name: 'INATIVIDADE ${device.name}',
      );
    }

    if (text.contains('alerta') && text.contains('manut')) {
      final plate = _extractPlate(input);
      final device = _findDevice(devices, plate ?? input);
      if (device == null) {
        return 'Não encontrei o veículo. Informe a placa ou nome exato.';
      }
      return _createSimpleAlert(
        client: client,
        session: session,
        type: 'maintenance',
        name: 'MANUTENÇÃO ${device.name}',
      );
    }

    if (text.contains('motorista') || text.contains('vincular')) {
      final drivers = await ref.read(driversProvider.future);
      final wantsUnlink =
          text.contains('desvincular') || text.contains('remover');
      final driverQuery =
          _extractAfterKeyword(input, const ['motorista']) ?? '';
      final deviceQuery = _extractAfterKeyword(input, const [
            'veiculo',
            'veículo',
            'placa',
            'carro',
          ]) ??
          _extractPlate(input) ??
          '';
      final device = _findDevice(devices, deviceQuery);
      if (device == null) {
        return 'Não encontrei o veículo. Informe a placa ou nome exato.';
      }
      if (wantsUnlink) {
        try {
          await client.updateEntity(
            path: '/devices/${device.id}',
            cookie: session.cookie,
            authHeader: session.authHeader,
            body: {'id': device.id, 'driverId': null},
          );
          ref.invalidate(devicesProvider);
          return 'Motorista desvinculado do ${device.name}.';
        } catch (e) {
          return 'Falha ao desvincular motorista: $e';
        }
      }
      final driverId =
          _extractFirstInt(driverQuery) ?? _findDriverId(drivers, driverQuery);
      if (driverId == null) {
        return 'Não encontrei o motorista. Informe o nome ou ID.';
      }
      try {
        await client.updateEntity(
          path: '/devices/${device.id}',
          cookie: session.cookie,
          authHeader: session.authHeader,
          body: {'id': device.id, 'driverId': driverId},
        );
        ref.invalidate(devicesProvider);
        return 'Motorista vinculado ao ${device.name} (driverId: $driverId).';
      } catch (e) {
        return 'Falha ao vincular motorista: $e';
      }
    }

    if (text.contains('listar') && text.contains('motorista')) {
      final drivers = await ref.read(driversProvider.future);
      if (drivers.isEmpty) return 'Nenhum motorista cadastrado.';
      return _listSample(
        'Motoristas',
        drivers.map((d) => '${d['id']}: ${d['name']}').toList(),
      );
    }

    if (text.contains('listar') && text.contains('cerca')) {
      final fences = await client.getList(
        path: '/geofences',
        cookie: session.cookie,
        authHeader: session.authHeader,
      );
      if (fences.isEmpty) return 'Nenhuma cerca cadastrada.';
      return _listSample(
        'Cercas',
        fences.map((d) => '${d['id']}: ${d['name']}').toList(),
      );
    }

    if (text.contains('listar') &&
        (text.contains('alerta') || text.contains('notifica'))) {
      final notifications = await client.getList(
        path: '/notifications',
        cookie: session.cookie,
        authHeader: session.authHeader,
      );
      if (notifications.isEmpty) return 'Nenhum alerta cadastrado.';
      return _listSample(
        'Alertas',
        notifications.map((n) => '${n['id']}: ${n['name']}').toList(),
      );
    }

    if (text.contains('listar') && text.contains('veiculo')) {
      if (devices.isEmpty) return 'Nenhum veículo cadastrado.';
      return _listSample(
        'Veículos',
        devices.map((d) => '${d.id}: ${d.name}').toList(),
      );
    }

    if (text.contains('listar') && text.contains('grupo')) {
      final groups = await ref.read(groupsProvider.future);
      if (groups.isEmpty) return 'Nenhum grupo cadastrado.';
      return _listSample(
        'Grupos',
        groups.map((g) => '${g['id']}: ${g['name']}').toList(),
      );
    }

    if (text.contains('listar') && text.contains('usuario')) {
      final users = await ref.read(usersProvider.future);
      if (users.isEmpty) return 'Nenhum usuário cadastrado.';
      return _listSample(
        'Usuários',
        users.map((u) => '${u.id}: ${u.name}').toList(),
      );
    }

    if (text.contains('listar') && text.contains('comando')) {
      final commands = await client.getList(
        path: '/commands',
        cookie: session.cookie,
        authHeader: session.authHeader,
      );
      if (commands.isEmpty) return 'Nenhum comando cadastrado.';
      return _listSample(
        'Comandos',
        commands.map((c) => '${c['id']}: ${c['description']}').toList(),
      );
    }

    if (text.contains('comando') || text.contains('ignicao')) {
      final plate = _extractPlate(input);
      final device = _findDevice(devices, plate ?? input);
      if (device == null) {
        return 'Não encontrei o veículo. Informe a placa ou nome exato.';
      }
      final type = _resolveCommandType(text);
      if (type == null &&
          (text.contains('custom') || text.contains('personaliz'))) {
        final payload =
            _extractAfterKeyword(input, const ['comando', 'custom']) ?? '';
        if (payload.isEmpty) {
          return 'Informe o comando customizado. Ex: "Comando custom reset".';
        }
        try {
          await client.createEntity(
            path: '/commands/send',
            cookie: session.cookie,
            authHeader: session.authHeader,
            body: {
              'deviceId': device.id,
              'type': 'custom',
              'attributes': {'data': payload},
            },
          );
          return 'Comando custom enviado para ${device.name}: $payload.';
        } catch (e) {
          return 'Falha ao enviar comando custom: $e';
        }
      }
      if (type == null) {
        return 'Informe o comando: bloquear ignição, ligar ignição, retomar ignição ou customizado.';
      }
      try {
        await client.createEntity(
          path: '/commands/send',
          cookie: session.cookie,
          authHeader: session.authHeader,
          body: {'deviceId': device.id, 'type': type},
        );
        return 'Comando enviado para ${device.name}: $type.';
      } catch (e) {
        return 'Falha ao enviar comando: $e';
      }
    }

    if (text.contains('agendar') && text.contains('relatorio')) {
      return 'Agendamento de relatório está planejado, mas ainda não foi integrado com o backend.';
    }

    return 'Ainda não reconheci esse comando. Tente: criar cerca, alerta de cerca, relatórios (rotas/eventos/viagens/paradas/resumo), status, alertas (velocidade/ignição/offline/online/movimento/parada/inatividade/manutenção), comandos de ignição/custom, vincular/desvincular motorista, listar veículos/grupos/usuários/motoristas/cercas/alertas/comandos.';
  }

  List<double> _extractNumbers(String text) {
    final matches = RegExp(r'(-?\d+[\.,]?\d*)').allMatches(text);
    return matches
        .map((m) => m.group(0)!.replaceAll(',', '.'))
        .map(double.tryParse)
        .whereType<double>()
        .toList();
  }

  Future<String?> _handleCompoundGeofenceAutomation({
    required String input,
    required String text,
    required TraccarClient client,
    required SessionState session,
  }) async {
    final wantsGeofence = text.contains('cerca') || text.contains('geofence');
    final wantsAlert = text.contains('alerta');
    final wantsGroup = text.contains('grupo');
    if (!wantsGeofence || !wantsAlert || !wantsGroup) {
      return null;
    }

    final isExit = text.contains('saida') || text.contains('saída');
    final groupHint = _extractAfterKeyword(input, const ['grupo']) ?? '';
    if (groupHint.trim().isEmpty) {
      return 'Entendi a automacao, mas preciso do grupo. Ex: "grupo de carros da ZL".';
    }

    final regionQuery = _extractRegionHint(input);
    final regionShape = await _resolveRegionArea(regionQuery);
    if (regionShape == null) {
      return 'Não consegui identificar a regiao para criar a cerca. Tente informar um endereco ou regiao mais especifica.';
    }

    final fenceName = _buildRegionFenceName(regionQuery);

    try {
      final geofence = await client.createEntity(
        path: '/geofences',
        cookie: session.cookie,
        authHeader: session.authHeader,
        body: {
          'name': fenceName,
          'area': regionShape,
        },
      );

      final geofenceId = geofence['id'];
      if (geofenceId == null) {
        return 'Cerca criada, mas sem id retornado para concluir automacao.';
      }

      final notificationType = isExit ? 'geofenceExit' : 'geofenceEnter';
      final notification = await client.createEntity(
        path: '/notifications',
        cookie: session.cookie,
        authHeader: session.authHeader,
        body: {
          'name': 'Alerta ${isExit ? 'saida' : 'entrada'} - $fenceName',
          'type': notificationType,
          'always': true,
          'notificators': ['web'],
          'attributes': {'geofenceId': geofenceId},
        },
      );

      final notificationId = notification['id'];

      final groups = await ref.read(groupsProvider.future);
      final targetGroup = _findGroupByHint(groups, groupHint);
      if (targetGroup == null || targetGroup['id'] == null) {
        return 'Cerca e alerta criados, mas nao encontrei o grupo "$groupHint" para vincular.';
      }

      final groupId = targetGroup['id'];

      await client.createEntity(
        path: '/permissions',
        cookie: session.cookie,
        authHeader: session.authHeader,
        body: {
          'groupId': groupId,
          'geofenceId': geofenceId,
        },
      );

      if (notificationId != null) {
        await client.createEntity(
          path: '/permissions',
          cookie: session.cookie,
          authHeader: session.authHeader,
          body: {
            'groupId': groupId,
            'notificationId': notificationId,
          },
        );
      }

      ref.invalidate(geofencesProvider);
      ref.invalidate(notificationsProvider);

      return 'Automação concluida: cerca "$fenceName" criada, alerta de ${isExit ? 'saida' : 'entrada'} criado e vinculado ao grupo ${targetGroup['name']}.';
    } catch (e) {
      return 'Falha na automacao da cerca/alerta/grupo: $e';
    }
  }

  String _extractRegionHint(String input) {
    final raw = _extractAfterKeyword(input, const [
          'regiao do',
          'região do',
          'regiao de',
          'região de',
          'regiao',
          'região',
          'na',
          'no',
        ]) ??
        input;
    return raw
        .replaceAll(
            RegExp(r'crie|criar|cerca|alerta|grupo', caseSensitive: false), '')
        .trim();
  }

  String _buildRegionFenceName(String regionHint) {
    final clean = regionHint.trim();
    if (clean.isEmpty) {
      return 'Cerca automatica';
    }
    return 'Cerca ${clean[0].toUpperCase()}${clean.substring(1)}';
  }

  Map<String, dynamic>? _findGroupByHint(
    List<Map<String, dynamic>> groups,
    String hint,
  ) {
    final q = _normalize(hint);
    if (q.isEmpty) return null;

    final expandedHints = <String>{q};
    if (q == 'zl' || q.contains('zona leste')) {
      expandedHints.addAll({'zona leste', 'carros zl', 'zl'});
    }

    for (final group in groups) {
      final name = _normalize((group['name'] ?? '').toString());
      for (final candidate in expandedHints) {
        if (name.contains(candidate)) {
          return group;
        }
      }
    }
    return null;
  }

  String _normalize(String value) {
    const from = 'áàâãäéèêëíìîïóòôõöúùûüç';
    const to = 'aaaaaeeeeiiiiooooouuuuc';
    var out = value.toLowerCase();
    for (var i = 0; i < from.length; i++) {
      out = out.replaceAll(from[i], to[i]);
    }
    return out.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  Future<String?> _resolveRegionArea(String query) async {
    final normalized = _normalize(query);
    if (normalized.contains('rodizio') &&
        (normalized.contains('sp') || normalized.contains('sao paulo'))) {
      // Centro expandido de Sao Paulo para uso operacional inicial.
      return 'CIRCLE (-23.550520 -46.633308, 9000)';
    }

    final geocoded = await _geocodeByNominatim(query);
    if (geocoded == null) {
      return null;
    }
    return 'CIRCLE (${geocoded.latitude} ${geocoded.longitude}, 1200)';
  }

  Future<_GeoPointLL?> _geocodeByNominatim(String query) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': query,
        'format': 'json',
        'limit': '1',
      });
      final response = await http.get(
        uri,
        headers: const {'User-Agent': 'SoutrackingAssistant/1.0'},
      );
      if (response.statusCode != 200) {
        return null;
      }
      final body = jsonDecode(response.body);
      if (body is! List || body.isEmpty || body.first is! Map) {
        return null;
      }
      final first = body.first as Map;
      final lat = double.tryParse((first['lat'] ?? '').toString());
      final lon = double.tryParse((first['lon'] ?? '').toString());
      if (lat == null || lon == null) {
        return null;
      }
      return _GeoPointLL(latitude: lat, longitude: lon);
    } catch (_) {
      return null;
    }
  }

  double? _extractFirstNumber(String text) {
    final numbers = _extractNumbers(text);
    if (numbers.isEmpty) return null;
    return numbers.first;
  }

  int? _extractFirstInt(String text) {
    final match = RegExp(r'\b(\d{1,6})\b').firstMatch(text);
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  String _extractName(String text, {required String fallback}) {
    final match = RegExp(
      r'nome\s+([\w\s-]+)',
      caseSensitive: false,
    ).firstMatch(text);
    if (match != null && match.groupCount >= 1) {
      final name = match.group(1)?.trim();
      if (name != null && name.isNotEmpty) return name;
    }
    return fallback;
  }

  String? _extractPlate(String text) {
    final match = RegExp(
      r'([A-Z]{3}[0-9][A-Z0-9][0-9]{2})',
      caseSensitive: false,
    ).firstMatch(text);
    return match?.group(1)?.toUpperCase();
  }

  dynamic _findDevice(List<dynamic> devices, String query) {
    final q = query.trim().toLowerCase();
    for (final d in devices) {
      final name = (d.name ?? '').toString().toLowerCase();
      final unique = (d.uniqueId ?? '').toString().toLowerCase();
      if (name.contains(q) || unique.contains(q)) return d;
    }
    return null;
  }

  int? _findDriverId(List<Map<String, dynamic>> drivers, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return null;
    for (final d in drivers) {
      final name = (d['name'] ?? '').toString().toLowerCase();
      final unique = (d['uniqueId'] ?? '').toString().toLowerCase();
      if (name.contains(q) || unique.contains(q)) {
        return d['id'] as int?;
      }
    }
    return null;
  }

  String? _extractAfterKeyword(String text, List<String> keywords) {
    for (final keyword in keywords) {
      final match = RegExp(
        '$keyword\\s+([\\w\\s-]+)',
        caseSensitive: false,
      ).firstMatch(text);
      if (match != null && match.groupCount >= 1) {
        final value = match.group(1)?.trim();
        if (value != null && value.isNotEmpty) return value;
      }
    }
    return null;
  }

  Future<String> _runReport({
    required TraccarClient client,
    required SessionState session,
    required int deviceId,
    required String path,
    required String label,
  }) async {
    final now = DateTime.now().toUtc();
    final from = now.subtract(const Duration(hours: 24));
    try {
      final data = await client.getList(
        path: path,
        cookie: session.cookie,
        authHeader: session.authHeader,
        query: {
          'deviceId': '$deviceId',
          'from': from.toIso8601String(),
          'to': now.toIso8601String(),
        },
      );
      return 'Relatório de $label: ${data.length} linhas nas últimas 24h.';
    } catch (e) {
      return 'Falha ao gerar relatório de $label: $e';
    }
  }

  Map<String, dynamic>? _findNotification(
    List<Map<String, dynamic>> items,
    String deviceName,
  ) {
    final q = deviceName.toLowerCase();
    for (final n in items) {
      final type = (n['type'] ?? '').toString().toLowerCase();
      final name = (n['name'] ?? '').toString().toLowerCase();
      if (type.contains('overspeed') && name.contains(q)) return n;
    }
    return null;
  }

  Map<String, dynamic>? _findNotificationType(
    List<Map<String, dynamic>> items,
    String deviceName,
    String typeContains,
  ) {
    final q = deviceName.toLowerCase();
    for (final n in items) {
      final type = (n['type'] ?? '').toString().toLowerCase();
      final name = (n['name'] ?? '').toString().toLowerCase();
      if (type.contains(typeContains) && name.contains(q)) return n;
    }
    return null;
  }

  Map<String, dynamic>? _findGeofence(
    List<Map<String, dynamic>> fences,
    String query,
  ) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return fences.first;
    for (final f in fences) {
      final name = (f['name'] ?? '').toString().toLowerCase();
      if (name.contains(q)) return f;
    }
    return null;
  }

  String _listSample(String label, List<String> items) {
    if (items.isEmpty) return '$label: nenhum item.';
    final sample = items.take(5).join(', ');
    return '$label: $sample${items.length > 5 ? '...' : ''}.';
  }

  String? _resolveCommandType(String text) {
    if (text.contains('bloquear') || text.contains('parar')) {
      return 'engineStop';
    }
    if (text.contains('ligar') || text.contains('start')) {
      return 'engineStart';
    }
    if (text.contains('retomar') || text.contains('liberar')) {
      return 'engineResume';
    }
    return null;
  }

  Future<String> _createSimpleAlert({
    required TraccarClient client,
    required SessionState session,
    required String type,
    required String name,
  }) async {
    try {
      await client.createEntity(
        path: '/notifications',
        cookie: session.cookie,
        authHeader: session.authHeader,
        body: {
          'name': name,
          'type': type,
          'always': true,
          'notificators': ['web'],
        },
      );
      ref.invalidate(notificationsProvider);
      return 'Alerta criado: $name.';
    } catch (e) {
      return 'Falha ao criar alerta: $e';
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Assistente IA', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          'Escreva livremente o que voce precisa. A IA interpreta sua solicitacao e executa a automacao.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.white70),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Theme.of(context).colorScheme.outline),
            ),
            child: ListView.separated(
              controller: _scrollController,
              itemCount: _messages.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final message = _messages[index];
                final bubbleColor = message.isUser
                    ? Theme.of(context).colorScheme.primary
                    : Colors.white10;
                final textColor = message.isUser ? Colors.black : Colors.white;
                final alignment = message.isUser
                    ? Alignment.centerRight
                    : Alignment.centerLeft;
                return Align(
                  alignment: alignment,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 420),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      message.text,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: textColor),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  labelText: 'Digite sua solicitacao?',
                ),
                onSubmitted: _sendMessage,
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: () => _sendMessage(_controller.text),
              icon: const Icon(Icons.send_outlined),
              label: const Text('Enviar'),
            ),
          ],
        ),
      ],
    );
  }
}

class _GeoPointLL {
  const _GeoPointLL({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}
