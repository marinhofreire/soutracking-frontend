/// Fonte unica de verdade para classificar status de device/veiculo.
///
/// Antes dessa funcao existirem 3 versoes divergentes (Dashboard, Frota,
/// Painel Master), cada uma contando "online"/"offline" diferente -- o que
/// fazia os KPIs mostrarem numeros diferentes pra mesma frota na mesma hora.
library;

/// true somente quando o Traccar reporta o device como conectado agora.
bool isDeviceOnline(String status) => status.trim().toLowerCase() == 'online';

/// true para offline "de verdade" (perdeu conexao) ou unknown (instabilidade
/// de conexao/identificacao) -- as duas situacoes significam, pro operador,
/// que o equipamento nao esta se comunicando agora.
bool isDeviceOffline(String status) => !isDeviceOnline(status);
