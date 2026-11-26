#!/bin/bash
source "$(dirname "$0")/lib.sh"
need docker
dc --profile trafego --profile tools down --remove-orphans || true
if [ "${1:-}" = "--tudo" ]; then
  dc --profile trafego --profile tools down -v --remove-orphans || true
  for img in sentinel-rust-a sentinel-rust-b sentinel-watchdog sentinel-toolbox sentinel-chaos sentinel-painel; do
    docker image rm -f "$img:local" >/dev/null 2>&1 && info "imagem removida: $img:local"
  done
fi
ok "limpeza concluida (evidencias/ preservada)"
docker ps -a --filter "label=com.docker.compose.project=sentinel" --format '  restante: {{.Names}} ({{.Status}})'
