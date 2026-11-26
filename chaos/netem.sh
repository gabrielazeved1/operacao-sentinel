#!/bin/bash
set -u
ACAO="${1:-ajuda}"; shift || true
DST_IP="${DST_IP:-}"; DST_BAND="${DST_BAND:-}"; DST_NAME="${DST_NAME:-$DST_IP}"; NAME_MAP="${NAME_MAP:-}"

IF="$(ip -o -4 route show to default 2>/dev/null | awk '{print $5; exit}')"
IF="${IF:-eth0}"

nome_de_ip() { local ip="$1" par; for par in $NAME_MAP; do [ "${par%%=*}" = "$ip" ] && { echo "${par#*=}"; return; }; done; echo "$ip"; }

garantir_raiz() {
  if ! tc qdisc show dev "$IF" | grep -q 'qdisc prio 1:'; then
    tc qdisc del dev "$IF" root 2>/dev/null || true
    tc qdisc add dev "$IF" root handle 1: prio bands 16 priomap 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 || return 1
  fi
}

aplicar() {
  local atraso="${1:-0}" jitter="${2:-0}" perda="${3:-0}" args=""
  [ "$atraso" != "0" ] && { args="delay ${atraso}ms"; [ "$jitter" != "0" ] && args="$args ${jitter}ms"; }
  [ "$perda" != "0" ] && args="$args loss ${perda}%"
  [ -z "$args" ] && { echo "nada a aplicar (atraso, jitter e perda sao 0)" >&2; return 2; }
  garantir_raiz || { echo "ERRO: tc/prio indisponivel (modulo sch_prio ausente no host?)" >&2; return 1; }
  local band="1" alvo="todos os destinos"
  if [ -n "$DST_IP" ]; then band="${DST_BAND:?DST_BAND ausente}"; alvo="${DST_NAME} (${DST_IP})"; fi
  tc qdisc replace dev "$IF" parent "1:${band}" handle "$((band * 10)):" netem $args \
    || { echo "ERRO: netem indisponivel (modulo sch_netem ausente no host?)" >&2; return 1; }
  if [ -n "$DST_IP" ]; then
    tc filter del dev "$IF" parent 1: prio "$band" 2>/dev/null || true
    tc filter add dev "$IF" protocol ip parent 1: prio "$band" u32 match ip dst "${DST_IP}/32" flowid "1:${band}" \
      || { echo "ERRO: filtro u32 indisponivel (modulo cls_u32 ausente no host?)" >&2; return 1; }
  fi
  echo "OK  interface=${IF}  destino=${alvo}  netem: ${args}"
}

limpar() {
  if [ -n "$DST_IP" ]; then
    tc filter del dev "$IF" parent 1: prio "${DST_BAND}" 2>/dev/null || true
    tc qdisc del dev "$IF" parent "1:${DST_BAND}" 2>/dev/null || true
    echo "OK  regra removida: destino=${DST_NAME} (${DST_IP})"
  else
    tc qdisc del dev "$IF" root 2>/dev/null || true
    echo "OK  todas as regras de rede removidas (interface ${IF})"
  fi
}

hex_para_ip() { local h="$1"; printf '%d.%d.%d.%d' "0x${h:0:2}" "0x${h:2:2}" "0x${h:4:2}" "0x${h:6:2}"; }

status() {
  echo "interface: ${IF}"
  if ! tc qdisc show dev "$IF" | grep -q 'qdisc prio 1:'; then
    echo "nenhuma regra de falha ativa (rede normal)"; return 0
  fi
  local qd band
  qd="$(tc qdisc show dev "$IF")"
  if echo "$qd" | grep -q 'netem .* parent 1:1 '; then
    echo "  [todos os destinos]      $(echo "$qd" | awk '/netem/ && /parent 1:1 /{sub(/.*limit [0-9]+ */,""); print}')"
  fi
  tc filter show dev "$IF" parent 1: 2>/dev/null | awk '
    /flowid/ { for (i=1;i<=NF;i++) if ($i=="flowid") fl=$(i+1) }
    /match/  { split($2,a,"/"); print fl, a[1] }' | while read -r fl hex; do
      ip="$(hex_para_ip "$hex")"
      band="${fl#1:}"
      desc="$(echo "$qd" | awk -v p="parent ${fl} " 'index($0,p) && /netem/ {sub(/.*limit [0-9]+ */,""); print}')"
      printf '  [saida -> %-10s %s]  %s\n' "$(nome_de_ip "$ip")" "($ip)" "${desc:-sem netem}"
  done
  echo "  (tc qdisc show, bruto:)"; echo "$qd" | sed 's/^/    /'
}

captura() {
  local seg="${1:-10}" filtro="${2:-tcp port 8080 or tcp port 9100 or icmp}"
  echo "capturando ${seg}s em ${IF} (filtro: ${filtro}) ..."
  timeout "$seg" tcpdump -i "$IF" -nn -tttt -l "$filtro" 2>&1 | grep -v -E '^(tcpdump: verbose|listening on)' || true
}

case "$ACAO" in
  aplicar)  aplicar "$@" ;;
  limpar)   limpar ;;
  status)   status ;;
  captura)  captura "$@" ;;
  teste)
            ok=1
            tc qdisc add dev lo root handle 1: prio bands 16 priomap 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 2>/dev/null || ok=0
            [ $ok = 1 ] && { tc qdisc add dev lo parent 1:2 handle 20: netem delay 1ms loss 0% 2>/dev/null || ok=0; }
            [ $ok = 1 ] && { tc filter add dev lo protocol ip parent 1: prio 2 u32 match ip dst 10.255.255.1/32 flowid 1:2 2>/dev/null || ok=0; }
            if [ "$ok" = 1 ]; then echo "ok"; else echo "falta modulo no kernel do host (sch_prio, sch_netem ou cls_u32) ou falta NET_ADMIN"; exit 4; fi ;;
  *) cat <<AJUDA
uso (dentro do contêiner; normalmente chamado por scripts/chaos.sh):
  netem.sh aplicar ATRASO_MS JITTER_MS PERDA_PCT   (env DST_IP/DST_BAND/DST_NAME opcionais)
  netem.sh limpar | status | captura [segundos] [filtro tcpdump] | teste
AJUDA
     ;;
esac
