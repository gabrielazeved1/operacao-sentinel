#!/bin/bash
cmd="${1:-}"; no="${2:-}"; val="${3:-}"
alvo() { case "$1" in rust-a|rust-b) echo "http://$1:8080";; *) echo "no invalido: '$1' (use rust-a ou rust-b)" >&2; exit 2;; esac; }
case "$cmd" in
  status)
    for n in ${no:-rust-a rust-b}; do curl -s -m 2 "$(alvo "$n")/admin/status" || echo "$n: sem resposta"; done ;;
  ready)  [ -n "$val" ] || { echo "uso: admin.sh ready <no> 0|1" >&2; exit 2; }
          curl -s -m 3 "$(alvo "$no")/admin/ready?v=$val" ;;
  atraso) [ -n "$val" ] || { echo "uso: admin.sh atraso <no> <ms>" >&2; exit 2; }
          curl -s -m 3 "$(alvo "$no")/admin/atraso?ms=$val" ;;
  *) echo "uso: admin.sh status [no] | ready <no> 0|1 | atraso <no> <ms>" >&2; exit 2 ;;
esac
