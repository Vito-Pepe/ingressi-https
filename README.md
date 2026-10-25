# ingressi-https

Indirizzi HTTPS **senza porta** per le app del Raspberry Pi, solo nella tailnet:

| App | Indirizzo | Porta locale sul Pi |
|---|---|---|
| Sillabe | `https://sillabe.<tailnet>.ts.net` | 8080 |
| Parole | `https://parole.<tailnet>.ts.net` | 8082 |
| Minigiochi | `https://minigiochi.<tailnet>.ts.net` | 8087 |
| Chess | `https://chess.<tailnet>.ts.net` | 8085 |
| Meteo | `https://meteo.<tailnet>.ts.net` | 8765 |
| onlineEmu (giochi retro) | `https://retro.<tailnet>.ts.net` | 8088 |

La homepage resta su `https://vito.<tailnet>.ts.net` (il `tailscale serve` del Pi, porta 443).

## Come funziona

Ogni dispositivo della tailnet ha un solo indirizzo HTTPS senza porta (la 443). Per dare un indirizzo senza porta a ogni app, questa repo avvia un **piccolo container Tailscale per app** (`tailscale/tailscale`), che entra nella tailnet con il nome dell'app, riceve le richieste in HTTPS con il certificato di Tailscale e le passa alla porta locale dell'app (regole in `serve/<app>.json`). Lo stesso meccanismo di `parole-esercizi` nella repo parole, ma **senza funnel**: questi indirizzi funzionano solo dai dispositivi collegati alla tailnet, mai da Internet.

- Le app non vanno modificate: ognuna resta alla radice del suo indirizzo, come prima.
- Ogni app ha un'origine sua nel browser: cookie e dati salvati non si mescolano.
- I container usano la rete del Pi (`network_mode: host`) in modalità utente: nessuna interfaccia di rete, nessuna rotta, nessun conflitto con il Tailscale del Pi.
- Gli indirizzi di prima (`http://vito:<porta>`, `http://192.168.1.22:<porta>`) continuano a funzionare.

## Installazione sul Raspberry Pi

1. Nel pannello Tailscale (Settings > Keys > Generate auth key) crea una chiave **Reusable** (riutilizzabile: serve per 5 dispositivi), **non Ephemeral**, con scadenza breve (es. 1 giorno).
2. Sul Pi:

   ```bash
   cd ~
   git clone https://github.com/Vito-Pepe/ingressi-https.git
   cd ingressi-https
    read -rsp "Incolla la auth key: " K && echo "TS_AUTHKEY=$K" >> .env && unset K && echo
   docker compose up -d
   docker compose ps
   ```

3. Nel pannello Tailscale, Machines: compaiono `sillabe`, `parole`, `minigiochi`, `chess`, `meteo`. Su ognuno: **Disable key expiry**. Se un nome era già preso, Tailscale aggiunge un numero (es. `parole-1`): in quel caso rinomina o cancella il vecchio dispositivo.
4. Togli la chiave, che non serve più (l'identità resta nei volumi), e revocala dal pannello (Settings > Keys):

   ```bash
   sed -i '/^TS_AUTHKEY=/d' .env
   ```

5. Aggiornamento automatico (senza sudo) e aggiornamento settimanale dell'immagine di Tailscale:

   ```bash
   (crontab -l 2>/dev/null; echo "*/5 * * * * cd $HOME/ingressi-https && ./update.sh >> $HOME/ingressi-https/update.log 2>&1") | crontab -
   (crontab -l 2>/dev/null; echo "45 4 * * 1 cd $HOME/ingressi-https && docker compose pull -q && docker compose up -d >> $HOME/ingressi-https/update.log 2>&1") | crontab -
   ```

Verifica: da un dispositivo della tailnet aprire `https://minigiochi.<tailnet>.ts.net`. Dal Pi:

```bash
for a in sillabe parole minigiochi chess meteo retro; do echo "$a: $(curl -s -o /dev/null -w '%{http_code}' https://$a.<tailnet>.ts.net)"; done
```

## Aggiungere un'app

1. `serve/<nome>.json` copiando uno degli altri e cambiando la porta locale.
2. Un servizio in `docker-compose.yml` copiando uno degli altri (nome, `TS_HOSTNAME`, `TS_SERVE_CONFIG`, volume) e il suo volume in fondo.
3. Pushare su `main`; sul Pi serve una nuova auth key per il primo avvio del nuovo dispositivo (`TS_AUTHKEY` nel `.env`, poi `./update.sh` o `docker compose up -d`, poi togliere la chiave).
4. Una riga in `app/apps.js` della homepage con `tsHost: "<nome>"`.

## Comandi utili

```bash
docker compose ps
docker compose logs --tail 30 minigiochi
docker compose exec minigiochi tailscale --socket=/tmp/tailscaled.sock serve status
docker compose restart          # dopo una modifica a mano dei file in serve/
```

## Nota sull'iPhone

Con il **Relay privato di iCloud** attivo, Safari può non aprire gli indirizzi `*.ts.net` (il Relay scavalca il DNS di Tailscale). Se capita: disattivare il Relay per quella rete, oppure usare gli indirizzi `http://vito:<porta>`.
