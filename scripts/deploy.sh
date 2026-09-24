#!/usr/bin/env bash
# Commita, versiona e sobe o SouTracking pro Cloudflare Pages via push no GitHub.
# Existe pra resolver um problema real: mudanças ficavam só rodando local
# (flutter run) e nunca chegavam em produção porque o commit+push era um
# passo manual fácil de esquecer. Rodar este script É o passo de "subir".
#
# Uso: ./scripts/deploy.sh "mensagem do commit"

set -euo pipefail
cd "$(dirname "$0")/.."

if [ -z "${1:-}" ]; then
  echo "Uso: ./scripts/deploy.sh \"mensagem do commit\""
  exit 1
fi

MSG="$1"

git add -A -- ':!build'
git commit -m "$MSG

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"

git push origin main

COMMIT=$(git rev-parse --short HEAD)
TIMESTAMP=$(date +"%Y-%m-%d %H:%M")

echo ""
echo "Push feito: commit $COMMIT"
echo "O Cloudflare Pages builda automaticamente com esse dart-define:"
echo "  --dart-define=BUILD_COMMIT=$COMMIT --dart-define=BUILD_TIMESTAMP=\"$TIMESTAMP\""
echo ""
echo "Acompanhe o deploy em:"
echo "  https://dash.cloudflare.com/ae0e5c8861814f3c5f25ffa19fd4917f/pages/view/soutracking-frontend"
echo ""
echo "Quando terminar (~3min), confirme a versão no painel: rodapé do menu lateral deve mostrar v$COMMIT"
