# Configuração de Mapas

Este projeto suporta dois provedores de mapas:

## 🌍 OpenStreetMap (Padrão - Gratuito)

**✅ Já configurado e funcionando!**

- Totalmente gratuito
- Sem necessidade de API Key
- Sem configuração de billing
- Pronto para uso em demonstrações

## 🗺️ Google Maps (Opcional - Requer Configuração)

Se desejar usar Google Maps ao invés do OpenStreetMap:

### 1. Obter API Key do Google Maps

1. Acesse: https://console.cloud.google.com/
2. Crie um novo projeto ou selecione um existente
3. Ative as seguintes APIs:
   - Maps JavaScript API (para web)
   - Maps SDK for Android (para Android)
   - Maps SDK for iOS (para iOS)
4. Configure billing:
   - Vincule um cartão de crédito
   - Google oferece $200 de crédito grátis por mês
   - Uso básico geralmente fica dentro do limite gratuito
5. Crie uma API Key:
   - Vá em **APIs & Services** → **Credentials**
   - Clique em **Create Credentials** → **API Key**
   - Copie a chave gerada

### 2. Adicionar a chave no projeto

#### Para Web:
Edite `web/index.html` e descomente a linha:
```html
<script src="https://maps.googleapis.com/maps/api/js?key=SUA_CHAVE_AQUI"></script>
```

#### Para Android:
Edite `android/app/src/main/AndroidManifest.xml` e adicione:
```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="SUA_CHAVE_AQUI"/>
```

#### Para iOS:
Edite `ios/Runner/AppDelegate.swift` e adicione no topo:
```swift
import GoogleMaps

// No método didFinishLaunchingWithOptions:
GMSServices.provideAPIKey("SUA_CHAVE_AQUI")
```

### 3. Alterar o provedor de mapas

Edite `lib/core/map_config.dart` e altere:
```dart
static const String mapProvider = 'google'; // Mude de 'openstreet' para 'google'
static const String googleMapsApiKey = 'SUA_CHAVE_AQUI';
```

## 🔧 Configurações Adicionais

### Restringir API Key (Recomendado para produção)

No Google Cloud Console:
1. Clique na API Key criada
2. Em **Application restrictions**:
   - Para Web: selecione "HTTP referrers" e adicione seus domínios
   - Para Mobile: selecione "Android apps" ou "iOS apps"
3. Em **API restrictions**:
   - Selecione "Restrict key"
   - Marque apenas as APIs do Maps necessárias

### Verificar uso e billing

- Acesse: https://console.cloud.google.com/billing
- Monitore o uso para evitar custos inesperados
- Configure alertas de orçamento se necessário

## 📊 Comparação

| Recurso | OpenStreetMap | Google Maps |
|---------|---------------|-------------|
| Custo | Gratuito | $200/mês grátis, depois pago |
| Configuração | Nenhuma | API Key + Billing |
| Qualidade | Boa | Excelente |
| Atualização | Comunidade | Google |
| Melhor para | Demonstração, MVP | Produção |

## 🚀 Para demonstração

Use OpenStreetMap (padrão) - está configurado e pronto!
