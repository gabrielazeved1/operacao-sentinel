#!/bin/bash
source "$(dirname "$0")/lib.sh"
need docker
falhou=0
passo() { local nome="$1"; shift; if out="$("$@" 2>&1)"; then ok "$nome"; else erro "$nome"; echo "$out" | sed 's/^/    /'; falhou=1; fi; }
prom() {
  docker run --rm --entrypoint promtool -v "$ROOT/prometheus:/etc/prometheus/sentinel:ro" prom/prometheus:v2.53.0 \
    check config /etc/prometheus/sentinel/prometheus.yml
}
passo "docker-compose.yml" docker compose config -q
passo "nginx.conf (nginx -t)" docker run --rm --add-host rust-a:127.0.0.1 --add-host rust-b:127.0.0.1 \
      -v "$ROOT/nginx:/etc/nginx/sentinel:ro" nginx:1.27-alpine nginx -t -c /etc/nginx/sentinel/nginx.conf
passo "prometheus.yml e alerts.yml (promtool)" prom
for f in scripts/*.sh toolbox/scripts/*.sh chaos/netem.sh; do passo "sintaxe $f" bash -n "$f"; done
command -v python3 >/dev/null && passo "sintaxe watchdog.py" python3 -I -c "import ast,sys;ast.parse(open('watchdog/watchdog.py').read())"
if [ "${1:-}" = "--recarregar" ]; then
  [ "$falhou" -eq 0 ] || die "validacao falhou: nada foi recarregado"
  exigir_pilha
  recarregar_nginx || die "falha ao recarregar o Nginx"
  if curl -s -m 5 -X POST "http://127.0.0.1:9090/-/reload"; then ok "Prometheus recarregado ($(agora))"; else die "falha ao recarregar o Prometheus"; fi
  registrar acoes.log "validar --recarregar"
fi
exit $falhou
