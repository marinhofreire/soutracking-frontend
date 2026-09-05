import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Hash de senha de check-in (motorista/passageiro/etc), usado fora do
/// login normal do Traccar -- motorista não é um User, é um Driver sem
/// senha nativa, então a senha de check-in é nossa e fica em
/// attributes.souPasswordHash (nunca em texto puro).
///
/// SHA-256 simples, sem salt por linha (poderíamos salgar por driverId, mas
/// a exposição real aqui é baixa: não é senha de acesso ao painel, é só
/// confirmar "sou eu" na landing pública de check-in -- reforçar se algum
/// dia isso proteger algo mais sensível).
String hashCheckinPassword(String rawPassword) {
  final bytes = utf8.encode(rawPassword.trim());
  return sha256.convert(bytes).toString();
}

bool checkinPasswordMatches(String rawPassword, String? storedHash) {
  if (storedHash == null || storedHash.isEmpty) return false;
  return hashCheckinPassword(rawPassword) == storedHash;
}
