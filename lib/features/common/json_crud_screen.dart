import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/session_state.dart';

class JsonCrudScreen extends ConsumerStatefulWidget {
  const JsonCrudScreen({
    super.key,
    required this.title,
    required this.endpointPath,
    required this.listProvider,
    required this.template,
    this.titleField = 'name',
    this.subtitleField,
    this.enableCreate = true,
    this.typeOptions,
    this.notificatorOptions,
  });

  final String title;
  final String endpointPath;
  final ProviderBase<AsyncValue<List<Map<String, dynamic>>>> listProvider;
  final Map<String, dynamic> template;
  final String titleField;
  final String? subtitleField;
  final bool enableCreate;
  final List<String>? typeOptions;
  final List<String>? notificatorOptions;

  @override
  ConsumerState<JsonCrudScreen> createState() => _JsonCrudScreenState();
}

class _JsonCrudScreenState extends ConsumerState<JsonCrudScreen> {
  late final TextEditingController _jsonController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _jsonController = TextEditingController(
      text: const JsonEncoder.withIndent('  ').convert(widget.template),
    );
  }

  @override
  void dispose() {
    _jsonController.dispose();
    super.dispose();
  }

  String _titleFor(Map<String, dynamic> item) {
    final value = item[widget.titleField];
    if (value is String && value.trim().isNotEmpty) {
      return value;
    }
    final id = item['id'];
    return id == null ? 'Item' : 'Item #$id';
  }

  String? _subtitleFor(Map<String, dynamic> item) {
    final key = widget.subtitleField;
    if (key != null && item[key] != null) {
      return '${item[key]}';
    }
    final type = item['type'];
    final description = item['description'];
    final deviceId = item['deviceId'];
    if (type != null || description != null || deviceId != null) {
      return [
        if (type != null) 'Tipo: $type',
        if (description != null) '$description',
        if (deviceId != null) 'Device: $deviceId',
      ].join(' • ');
    }
    return null;
  }

  Map<String, dynamic>? _currentJson() {
    final raw = _jsonController.text.trim();
    if (raw.isEmpty) return null;
    try {
      final parsed = jsonDecode(raw);
      if (parsed is Map) {
        return parsed.cast<String, dynamic>();
      }
    } catch (_) {}
    return null;
  }

  dynamic _currentFieldValue(String key) {
    final current = _currentJson();
    if (current != null && current.containsKey(key)) {
      return current[key];
    }
    return widget.template[key];
  }

  String _currentText(String key) {
    final value = _currentFieldValue(key);
    if (value == null) return '';
    return '$value';
  }

  void _setJsonField(String key, dynamic value) {
    final current = _currentJson();
    if (current == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('JSON inválido para atualizar o campo.')),
      );
      return;
    }
    current[key] = value;
    _jsonController.text = const JsonEncoder.withIndent('  ').convert(current);
    _jsonController.selection = TextSelection.fromPosition(
      TextPosition(offset: _jsonController.text.length),
    );
  }

  List<String> _currentStringList(String key) {
    final value = _currentFieldValue(key);
    if (value is List) {
      return value.map((e) => '$e').toList();
    }
    return [];
  }

  void _toggleListValue(String key, String value, bool enabled) {
    final current = _currentStringList(key);
    final updated = List<String>.from(current);
    if (enabled) {
      if (!updated.contains(value)) {
        updated.add(value);
      }
    } else {
      updated.remove(value);
    }
    _setJsonField(key, updated);
  }

  Future<void> _create() async {
    final raw = _jsonController.text.trim();
    if (raw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o JSON para criar.')),
      );
      return;
    }

    Map<String, dynamic> body;
    try {
      final parsed = jsonDecode(raw);
      if (parsed is! Map) {
        throw const FormatException('JSON deve ser um objeto.');
      }
      body = parsed.cast<String, dynamic>();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('JSON inválido: $e')));
      return;
    }

    setState(() => _saving = true);
    final session = ref.read(sessionProvider);
    final client = ref.read(traccarClientProvider);

    try {
      await client.createEntity(
        path: widget.endpointPath,
        cookie: session.cookie,
        authHeader: session.authHeader,
        body: body,
      );
      ref.invalidate(widget.listProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registro criado com sucesso.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Falha ao criar: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dataAsync = ref.watch(widget.listProvider);

    final showDeviceSelector = widget.template.containsKey('deviceId');
    final showUserSelector = widget.template.containsKey('userId');
    final showGroupSelector = widget.template.containsKey('groupId');
    final showNameField = widget.template.containsKey('name');
    final showDescriptionField = widget.template.containsKey('description');
    final showAttributeField = widget.template.containsKey('attribute');
    final showExpressionField = widget.template.containsKey('expression');
    final showTypeField = widget.template.containsKey('type');
    final showAlwaysField = widget.template.containsKey('always');
    final showNotificatorsField = widget.template.containsKey('notificators');
    final devicesAsync = showDeviceSelector ? ref.watch(devicesProvider) : null;
    final usersAsync = showUserSelector ? ref.watch(usersProvider) : null;
    final groupsAsync = showGroupSelector ? ref.watch(groupsProvider) : null;

    final list = dataAsync.when(
      data: (items) {
        if (items.isEmpty) {
          return const Center(child: Text('Nenhum registro encontrado'));
        }
        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final item = items[index];
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.article_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _titleFor(item),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (_subtitleFor(item) != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            _subtitleFor(item)!,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Colors.white70),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
      error: (error, _) => Center(child: Text('Erro: $error')),
      loading: () => const Center(child: CircularProgressIndicator()),
    );

    final form = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        if (showNameField) ...[
          Text('Nome', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          TextFormField(
            key: ValueKey('json-name-${_currentText('name')}'),
            initialValue: _currentText('name'),
            decoration: const InputDecoration(labelText: 'name'),
            onChanged: (value) => _setJsonField('name', value.trim()),
          ),
          const SizedBox(height: 12),
        ],
        if (showDescriptionField) ...[
          Text('Descrição', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          TextFormField(
            key: ValueKey('json-description-${_currentText('description')}'),
            initialValue: _currentText('description'),
            decoration: const InputDecoration(labelText: 'description'),
            onChanged: (value) => _setJsonField('description', value.trim()),
          ),
          const SizedBox(height: 12),
        ],
        if (showAttributeField) ...[
          Text('Atributo', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          TextFormField(
            key: ValueKey('json-attribute-${_currentText('attribute')}'),
            initialValue: _currentText('attribute'),
            decoration: const InputDecoration(labelText: 'attribute'),
            onChanged: (value) => _setJsonField('attribute', value.trim()),
          ),
          const SizedBox(height: 12),
        ],
        if (showExpressionField) ...[
          Text('Expressão', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          TextFormField(
            key: ValueKey('json-expression-${_currentText('expression')}'),
            initialValue: _currentText('expression'),
            decoration: const InputDecoration(labelText: 'expression'),
            onChanged: (value) => _setJsonField('expression', value),
          ),
          const SizedBox(height: 12),
        ],
        if (showTypeField) ...[
          Text('Tipo', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          if (widget.typeOptions != null && widget.typeOptions!.isNotEmpty)
            DropdownButtonFormField<String>(
              key: ValueKey('json-type-${_currentText('type')}'),
              initialValue:
                  _currentText('type').isEmpty ? null : _currentText('type'),
              items: widget.typeOptions!
                  .map(
                    (type) => DropdownMenuItem<String>(
                      value: type,
                      child: Text(type),
                    ),
                  )
                  .toList(),
              onChanged: (value) => _setJsonField('type', value),
              decoration: const InputDecoration(labelText: 'type'),
            )
          else
            TextFormField(
              key: ValueKey('json-type-${_currentText('type')}'),
              initialValue: _currentText('type'),
              decoration: const InputDecoration(labelText: 'type'),
              onChanged: (value) => _setJsonField('type', value.trim()),
            ),
          const SizedBox(height: 12),
        ],
        if (showAlwaysField) ...[
          SwitchListTile(
            value: (_currentFieldValue('always') as bool?) ?? false,
            onChanged: (value) => _setJsonField('always', value),
            title: const Text('Sempre ativo (always)'),
          ),
          const SizedBox(height: 12),
        ],
        if (showNotificatorsField && widget.notificatorOptions != null) ...[
          Text('Notificadores', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          for (final option in widget.notificatorOptions!)
            CheckboxListTile(
              value: _currentStringList('notificators').contains(option),
              onChanged: (checked) =>
                  _toggleListValue('notificators', option, checked ?? false),
              title: Text(option),
              controlAffinity: ListTileControlAffinity.leading,
            ),
          const SizedBox(height: 12),
        ],
        if (showDeviceSelector && devicesAsync != null) ...[
          Text('Dispositivo', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          devicesAsync.when(
            data: (devices) {
              return DropdownButtonFormField<int?>(
                key: ValueKey('json-device-${_currentFieldValue('deviceId')}'),
                initialValue: _currentFieldValue('deviceId') as int?,
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('Selecionar dispositivo'),
                  ),
                  ...devices.map(
                    (d) => DropdownMenuItem<int?>(
                      value: d.id,
                      child: Text(d.name),
                    ),
                  ),
                ],
                onChanged: (value) => _setJsonField('deviceId', value),
                decoration: const InputDecoration(labelText: 'deviceId'),
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => Text('Erro: $error'),
          ),
          const SizedBox(height: 12),
        ],
        if (showUserSelector && usersAsync != null) ...[
          Text('Usuário', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          usersAsync.when(
            data: (users) {
              return DropdownButtonFormField<int?>(
                key: ValueKey('json-user-${_currentFieldValue('userId')}'),
                initialValue: _currentFieldValue('userId') as int?,
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('Selecionar usuário'),
                  ),
                  ...users.map(
                    (u) => DropdownMenuItem<int?>(
                      value: u.id,
                      child: Text('${u.name} (${u.email})'),
                    ),
                  ),
                ],
                onChanged: (value) => _setJsonField('userId', value),
                decoration: const InputDecoration(labelText: 'userId'),
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => Text('Erro: $error'),
          ),
          const SizedBox(height: 12),
        ],
        if (showGroupSelector && groupsAsync != null) ...[
          Text('Grupo', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          groupsAsync.when(
            data: (groups) {
              return DropdownButtonFormField<int?>(
                key: ValueKey('json-group-${_currentFieldValue('groupId')}'),
                initialValue: _currentFieldValue('groupId') as int?,
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('Selecionar grupo'),
                  ),
                  ...groups.map(
                    (g) => DropdownMenuItem<int?>(
                      value: g['id'] as int?,
                      child: Text('${g['name'] ?? 'Grupo'}'),
                    ),
                  ),
                ],
                onChanged: (value) => _setJsonField('groupId', value),
                decoration: const InputDecoration(labelText: 'groupId'),
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => Text('Erro: $error'),
          ),
          const SizedBox(height: 12),
        ],
        Text(
          'Novo registro (JSON)',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _jsonController,
          decoration: const InputDecoration(
            labelText: 'JSON do registro',
            alignLabelWithHint: true,
          ),
          minLines: 8,
          maxLines: 12,
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: widget.enableCreate && !_saving ? _create : null,
          child: _saving
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Criar registro'),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        if (!widget.enableCreate) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Expanded(child: list),
            ],
          );
        }
        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 380,
                margin: const EdgeInsets.only(left: 16, right: 20, top: 24),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black54,
                        blurRadius: 14,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: SingleChildScrollView(child: form),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 24, right: 16),
                  child: list,
                ),
              ),
            ],
          );
        }
        return ListView(
          children: [
            form,
            const SizedBox(height: 20),
            SizedBox(height: 420, child: list),
          ],
        );
      },
    );
  }
}
