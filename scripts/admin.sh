#!/bin/bash
source "$(dirname "$0")/lib.sh"
USO='  scripts/admin.sh status [no]
  scripts/admin.sh ready <no> 0|1
  scripts/admin.sh atraso <no> <ms>
  scripts/admin.sh pool status | drenar <no> | restaurar <no>'
[ $# -ge 1 ] || { uso "$0"; exit 2; }
if [ "$1" = pool ]; then
  CONF="nginx/nginx.conf"
  [ "${2:-}" = status ] && { grep -E "# POOL:" "$CONF" | sed 's/^ */  /'; exit 0; }
  modo="${2:-}"; no="${3:-}"
  case "$modo" in drenar|restaurar) ;; *) uso "$0"; exit 2;; esac
  case "$no" in rust-a|rust-b) ;; *) die "informe o no: rust-a ou rust-b";; esac
  exigir_pilha
  grep -q "# POOL:$no\$" "$CONF" || die "linha do $no nao encontrada em $CONF (marcador '# POOL:$no')"
  bak="evidencias/nginx.conf.$(agora_arq).bak"; mkdir -p evidencias; cp "$CONF" "$bak"
  # sem sed -i: a opcao difere entre gnu e bsd (macos)
  tmp="$(mktemp)"
  if [ "$modo" = drenar ]; then sed -E "/# POOL:${no}\$/ { /down;/! s/;( +# POOL)/ down;\\1/; }" "$CONF" > "$tmp"
  else sed -E "/# POOL:${no}\$/ s/ down;( +# POOL)/;\\1/" "$CONF" > "$tmp"; fi || { rm -f "$tmp"; die "sed falhou: nada foi alterado"; }
  cat "$tmp" > "$CONF"; rm -f "$tmp"
  if [ "$modo" = drenar ]; then grep -qE "down; +# POOL:${no}\$" "$CONF" || { cp "$bak" "$CONF"; die "a linha do $no nao ficou com 'down': nada foi alterado"; }
  else grep -qE "down; +# POOL:${no}\$" "$CONF" && { cp "$bak" "$CONF"; die "a linha do $no continua com 'down': nada foi alterado"; }; fi
  if recarregar_nginx; then registrar pool.log "$modo $no (copia: $bak)"
  else cp "$bak" "$CONF"; die "configuracao invalida: mudanca DESFEITA (restaurado de $bak)"; fi
  exit 0
fi
exigir_pilha
registrar acoes.log "admin.sh $*"
tbx /opt/sentinel/admin.sh "$@"
