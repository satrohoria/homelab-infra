# Inventário do Homelab

## Servidor principal

| Item | Valor |
|---|---|
| Hostname | homelab |
| Sistema operacional | Debian 13 |
| IP | 192.168.0.2 |
| CPU | Intel Core i5-4210U |
| RAM | 4 GB |
| Disco | SSD SATA 240 GB |
| Interface principal | Ethernet 100 Mbps |
| Gerenciamento remoto | SSH / Tailscale |

## Rede

| Item | Valor |
|---|---|
| Rede LAN | 192.168.0.0/24 |
| Gateway | 192.168.0.1 |
| DNS principal | 192.168.0.2 |
| DHCP | Roteador Claro |
| DNS interno | Pi-hole |
| DNS recursivo | Unbound |

## Serviços

| Serviço | Função | Acesso |
|---|---|---|
| Pi-hole | DNS e bloqueio | https://pihole.home |
| Unbound | DNS recursivo | Interno |
| Caddy | Reverse Proxy / HTTPS | Interno |
| Portainer | Gerenciamento Docker | https://portainer.home |
| Uptime Kuma | Disponibilidade | https://status.home |
| Beszel | Monitoramento | https://beszel.home |
| Dozzle | Logs Docker | https://logs.home |
| Scrutiny | SMART / SSD | https://scrutiny.home |
| Speedtest Tracker | Teste via Dell | https://speedtest.home |
| Speedtest Desktop | Teste via Desktop Gigabit | https://speedpc.home |
| Vaultwarden | Gerenciador de senhas | https://vault.home |
| Home Assistant | Automação residencial | https://casa.home |
| Homepage | Dashboard central | https://homelab.home |
| Diun | Monitoramento de imagens Docker | Interno |

## Portas principais

| Porta | Serviço |
|---|---|
| 22 | SSH |
| 53 TCP/UDP | Pi-hole |
| 80 | Caddy HTTP |
| 443 | Caddy HTTPS |
| 3000 | Homepage |
| 3001 | Uptime Kuma |
| 8080 | Dozzle |
| 8081 | Pi-hole Web |
| 8086 | Scrutiny |
| 8087 | Speedtest Tracker |
| 8090 | Beszel |
| 8123 | Home Assistant |
| 9443 | Portainer |

## Redes Docker

### caddy-net

Rede Docker externa utilizada pelo Caddy e serviços que não precisam expor portas diretamente.

```text
Caddy
  |
caddy-net
  |
Vaultwarden
```

A rede precisa existir antes do deploy dos serviços que dependem dela.

## Speedtest externo

O Dell possui interface Ethernet limitada a 100 Mbps.

```text
Desktop Windows
192.168.0.12
      |
Ookla Speedtest CLI
      |
PowerShell
      |
CSV + JSON
      |
SCP
      |
Homelab
      |
Dashboard + Homepage
```

## Backup

Script principal:

```text
/usr/local/sbin/homelab-backup.sh
```

Destino local:

```text
/opt/backups
```

Destino remoto:

```text
gdrive:Homelab/Backups
```

Tecnologias:

- tar
- sqlite3
- rclone
- Google Drive

## Segurança

Principais controles:

- SSH
- Tailscale
- HTTPS interno
- Caddy Internal CA
- DNS interno
- Vaultwarden
- `.env` fora do Git
- secrets substituídos por variáveis
- Caddy PKI privada fora do backup em nuvem em claro

## IaC

Componentes atualmente versionados:

- Docker Compose
- Caddyfile
- Homepage
- scripts
- documentação
- GitHub Actions
- Ansible
- Speedtest Desktop
- coletor PowerShell

## Observações de reprodutibilidade

Ainda precisam ser tratados:

- criação automática da rede `caddy-net`;
- cópia/deploy das stacks para `/opt`;
- versionamento fixo das imagens;
- restore completo;
- backup criptografado da CA interna;
- redução de portas diretamente expostas.
