#!/bin/bash
source "$(dirname "$0")/lib.sh"
USO='  scripts/status.sh                      retrato atual
  scripts/status.sh --vivo [segundos]    atualizacao continua
  scripts/status.sh --usuario [--desde 5m] [--servico nginx|trafego]'
exigir_pilha
retrato() {
  echo "${B}CONTEINERES${N}"
  dc --profile trafego ps --format 'table {{.Service}}\t{{.State}}\t{{.Health}}\t{{.Status}}'
  echo
  tbx /opt/sentinel/snapshot.sh || warn "toolbox indisponivel (rode: docker compose up -d toolbox)"
}
case "${1:-}" in
  --usuario) shift; analisar "$@" ;;
  --vivo)
    INT="${2:-3}"; trap 'exit 0' INT TERM
    while true; do
      quadro="$(echo "${B}OPERACAO SENTINEL - painel ao vivo${N}  (a cada ${INT}s; Ctrl+C sai)"; echo
                retrato; echo
                echo "${B}VISAO DO USUARIO - Nginx (30 s)${N}"; analisar --desde 30s --compacto
                [ -n "$(cid trafego)" ] && { echo "${B}VISAO DO USUARIO - gerador de trafego (30 s)${N}"; analisar --servico trafego --desde 30s --compacto; })"
      clear; echo "$quadro"; sleep "$INT"
    done ;;
  ""|-h|--help) if [ "${1:-}" = "" ]; then retrato; else uso "$0"; fi ;;
  *) uso "$0"; exit 2 ;;
esac
