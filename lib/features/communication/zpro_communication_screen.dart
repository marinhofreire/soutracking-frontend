import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_constants.dart';

class ZproCommunicationScreen extends StatefulWidget {
  const ZproCommunicationScreen({super.key});

  @override
  State<ZproCommunicationScreen> createState() =>
      _ZproCommunicationScreenState();
}

class _ZproCommunicationScreenState extends State<ZproCommunicationScreen> {
  final _phoneController = TextEditingController();
  final _messageController = TextEditingController(
    text:
        'Olá! Sou da central operacional. Posso te enviar status em tempo real com mapa e câmeras agora.',
  );

  @override
  void dispose() {
    _phoneController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _openUrl(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('URL não configurada. Defina no app_constants.dart.'),
        ),
      );
      return;
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('URL inválida.')),
      );
      return;
    }

    final launched = await launchUrl(uri, webOnlyWindowName: '_blank');
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o link.')),
      );
    }
  }

  Future<void> _openWhatsAppConversation() async {
    final phoneRaw = _phoneController.text.trim();
    final messageRaw = _messageController.text.trim();
    final digits = phoneRaw.replaceAll(RegExp(r'\D'), '');

    if (digits.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Informe um telefone para abrir a conversa.')),
      );
      return;
    }

    final url =
        'https://wa.me/$digits?text=${Uri.encodeComponent(messageRaw.isEmpty ? 'Olá!' : messageRaw)}';
    await _openUrl(url);
  }

  Future<void> _openPlatformWhatsApp() async {
    final digits = kPlatformWhatsAppNumber.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Número oficial não configurado. Defina PLATFORM_WHATSAPP_NUMBER.',
          ),
        ),
      );
      return;
    }
    await _openUrl('https://wa.me/$digits');
  }

  @override
  Widget build(BuildContext context) {
    final isConfigured =
        kZproPanelUrl.trim().isNotEmpty || kPlatformWhatsAppNumber.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Comunicação WhatsApp',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: SizedBox.shrink(),
        ),
        Text(
          'Fluxo comercial imediato: conversa com cliente + prova visual no Mural de Câmeras.',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: Colors.white70),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 16),
          child: SizedBox.shrink(),
        ),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Icon(
                isConfigured
                    ? Icons.verified_outlined
                    : Icons.error_outline_rounded,
                color: isConfigured ? Colors.greenAccent : Colors.orangeAccent,
              ),
              const Padding(
                padding: EdgeInsets.only(left: 10),
                child: SizedBox.shrink(),
              ),
              Expanded(
                child: Text(
                  isConfigured
                      ? 'Integração pronta para uso comercial (WhatsApp e painel Z-Pro).'
                      : 'Configure URL do painel e número oficial para ativar o fluxo completo.',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              onPressed: _openPlatformWhatsApp,
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('WhatsApp da plataforma'),
            ),
            OutlinedButton.icon(
              onPressed: () => _openUrl(kZproPanelUrl),
              icon: const Icon(Icons.hub_outlined),
              label: const Text('Abrir painel Z-Pro'),
            ),
            OutlinedButton.icon(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Abra “Câmeras > Mural de Câmeras” no menu para mostrar imagens ao cliente.',
                  ),
                ),
              ),
              icon: const Icon(Icons.videocam_outlined),
              label: const Text('Onde ver imagens'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Abrir conversa de atendimento',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _phoneController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Telefone do cliente (com DDI)',
                  hintText: 'Ex: +55 11999998888',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _messageController,
                minLines: 2,
                maxLines: 4,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Mensagem inicial',
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _openWhatsAppConversation,
                icon: const Icon(Icons.send_outlined),
                label: const Text('Iniciar conversa no WhatsApp'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
