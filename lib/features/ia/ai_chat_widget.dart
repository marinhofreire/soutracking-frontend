import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../data/bridge_config.dart';

class _ChatMessage {
  const _ChatMessage({required this.fromAssistant, required this.text});
  final bool fromAssistant;
  final String text;
}

/// Botao flutuante + painel de chat com a IA Operacional, ligado direto no
/// soutracking-bridge (rota POST /chat). Autocontido: pode ser plugado em
/// qualquer tela sem depender de outro estado da tela.
class AiChatFloatingWidget extends ConsumerStatefulWidget {
  const AiChatFloatingWidget({super.key});

  @override
  ConsumerState<AiChatFloatingWidget> createState() =>
      _AiChatFloatingWidgetState();
}

class _AiChatFloatingWidgetState extends ConsumerState<AiChatFloatingWidget> {
  bool _open = false;
  bool _sending = false;
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = <_ChatMessage>[
    const _ChatMessage(
      fromAssistant: true,
      text: 'Oi! Pergunta algo sobre a frota — status, ignição, velocidade, '
          'quem está parado etc. Eu respondo só com dado real.',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 160,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    final config = ref.read(bridgeConfigProvider);
    if (config.bridgeUrl.isEmpty || config.bridgeApiKey.isEmpty) {
      setState(() {
        _messages.add(const _ChatMessage(
          fromAssistant: true,
          text: 'IA ainda não está configurada. Vá em Configurações → '
              'Integrações → Bridge / IA e salve a URL e a chave.',
        ));
      });
      _scrollToEnd();
      return;
    }

    _controller.clear();
    setState(() {
      _messages.add(_ChatMessage(fromAssistant: false, text: text));
      _sending = true;
    });
    _scrollToEnd();

    try {
      final history = _messages
          .map((m) => {'role': m.fromAssistant ? 'assistant' : 'user', 'text': m.text})
          .toList(growable: false);
      final response = await http
          .post(
            Uri.parse('${config.bridgeUrl}/chat'),
            headers: {
              'Authorization': 'Bearer ${config.bridgeApiKey}',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'message': text, 'history': history}),
          )
          .timeout(const Duration(seconds: 25));

      String reply;
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        reply = (body['reply'] as String?)?.trim().isNotEmpty == true
            ? body['reply'] as String
            : 'Não consegui gerar resposta agora.';
      } else {
        reply = 'Erro ao falar com a IA (HTTP ${response.statusCode}).';
      }
      if (!mounted) return;
      setState(() => _messages.add(_ChatMessage(fromAssistant: true, text: reply)));
    } catch (error) {
      if (!mounted) return;
      setState(() => _messages.add(
            _ChatMessage(fromAssistant: true, text: 'Falha ao conectar: $error'),
          ));
    } finally {
      if (mounted) setState(() => _sending = false);
      _scrollToEnd();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 20,
      bottom: 100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_open) _buildPanel(),
          const SizedBox(height: 10),
          _buildToggleButton(),
        ],
      ),
    );
  }

  Widget _buildToggleButton() {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: () => setState(() => _open = !_open),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF2563EB), Color(0xFF1E3A8A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0B1220).withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(
            _open ? Icons.close_rounded : Icons.auto_awesome_rounded,
            color: Colors.white,
            size: 26,
          ),
        ),
      ),
    );
  }

  Widget _buildPanel() {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 340,
        height: 440,
        decoration: BoxDecoration(
          color: const Color(0xFF0F1A2B),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF2A3F5F)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0B1220).withValues(alpha: 0.4),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFF2A3F5F))),
              ),
              child: Row(
                children: const [
                  Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'IA Operacional',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(12),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  return Align(
                    alignment: message.fromAssistant
                        ? Alignment.centerLeft
                        : Alignment.centerRight,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      constraints: const BoxConstraints(maxWidth: 260),
                      decoration: BoxDecoration(
                        color: message.fromAssistant
                            ? const Color(0xFF1B2A44)
                            : const Color(0xFF2563EB),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        message.text,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (_sending)
              const Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Pergunte sobre a frota...',
                        hintStyle: const TextStyle(color: Color(0xFF7C8DA8)),
                        filled: true,
                        fillColor: const Color(0xFF16233A),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send_rounded, color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
