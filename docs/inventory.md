# Inventário do Homelab

## Servidor principal

| Item | Valor |
|---|---|
| Hostname | `homelab` |
| Sistema operacional | Debian 13 |
| IP LAN | `192.168.0.2` |
| CPU | Intel Core i5-4210U |
| RAM | 4 GB |
| Disco | SSD SATA 240 GB |
| Interface principal | Ethernet 100 Mbps |
| Gerenciamento remoto | SSH / Tailscale |

---

## Rede

| Item | Valor |
|---|---|
| Rede LAN | `192.168.0.0/24` |
| Gateway | `192.168.0.1` |
| Servidor Homelab | `192.168.0.2` |
| DNS principal | `192.168.0.2` |
| DHCP | Roteador Claro |
| DNS interno | Pi-hole |
| Upstream DNS | Unbound |
| Acesso remoto | Tailscale |

O roteador da operadora continua responsável pelo DHCP.

O Pi-hole é utilizado como DNS principal nos dispositivos configurados para utilizar o homelab.

---

## Serviços

| Serviço | Função | Acesso |
|---|---|---|
| Pi-hole | DNS e bloqueio | `https://pihole.home` |
| Unbound | Upstream DNS | Interno |
| Caddy | Reverse Proxy / HTTPS | `80/443` |
| Portainer | Gerenciamento Docker | `https://portainer.home` |
| Uptime Kuma | Disponibilidade | `https://status.home` |
| Beszel | Monitoramento | `https://beszel.home` |
| Beszel Agent | Coleta de métricas | Unix Socket |
| Dozzle | Logs Docker | `https://logs.home` |
| Scrutiny | SMART / SSD | `https://scrutiny.home` |
| Speedtest Tracker | Teste via Dell | `https://speedtest.home` |
| Speedtest Desktop | Teste via Desktop Gigabit | `https://speedpc.home` |
| Vaultwarden | Gerenciador de senhas | `https://vault.home` |
| Home Assistant | Automação residencial | `https://casa.home` |
| Homepage | Dashboard central | `https://homelab.home` |
| Diun | Monitoramento de imagens Docker | Interno |

---

## Portas expostas no host

Portas intencionalmente disponíveis através do host:

| Porta | Protocolo | Serviço | Escopo |
|---|---|---|---|
| 22 | TCP | SSH | LAN / acesso autorizado |
| 53 | TCP/UDP | Pi-hole | DNS da LAN |
| 80 | TCP | Caddy | HTTP |
| 443 | TCP | Caddy | HTTPS |
| 5335 | TCP/UDP | Unbound | Somente `127.0.0.1` |
| 8085 | TCP | Health endpoint | Somente `127.0.0.1` |
| 8123 | TCP | Home Assistant | Filtrado pelo nftables |
| 8300 | TCP | Emulated Hue | Alexa / localhost via nftables |
| 18554 | TCP | go2rtc | Somente `127.0.0.1` |
| 18555 | TCP | go2rtc | Filtrado pelo nftables |

Interfaces administrativas como Portainer, Beszel, Dozzle, Scrutiny, Homepage e Uptime Kuma não possuem mais portas publicadas diretamente para a LAN.

O acesso web é centralizado no Caddy.

---

## Redes Docker

### caddy-net

Rede Docker externa utilizada pelo Caddy e pelos serviços publicados através do reverse proxy.

```text
caddy-net
172.29.0.0/16
```

Caddy:

```text
172.29.0.250
```

O IP do Caddy é estático porque também é utilizado pelas regras do nftables para autorizar o acesso ao Home Assistant.

Fluxo simplificado:

```text
Cliente
   |
HTTPS :443
   |
Caddy
172.29.0.250
   |
caddy-net
   |
Serviços internos
```

A rede precisa existir antes do deploy dos serviços que dependem dela.

### dns-net

Rede dedicada à comunicação entre Pi-hole e Unbound.

```text
dns-net
172.30.0.0/24
```

Endereços:

| Serviço | IP |
|---|---|
| Unbound | `172.30.0.2` |
| Pi-hole | `172.30.0.3` |

Fluxo:

```text
LAN
 |
192.168.0.2:53
 |
Pi-hole
172.30.0.3
 |
dns-net
 |
Unbound
172.30.0.2
 |
Internet
```

O IP estático do Unbound evita dependência de endereçamento Docker dinâmico para o upstream do Pi-hole.

---

## DNS

### Pi-hole

DNS da LAN:

```text
192.168.0.2:53
```

Responsabilidades:

- resolução DNS da LAN;
- registros internos;
- domínios `.home`;
- bloqueio;
- encaminhamento de consultas externas.

A interface web não possui porta dedicada publicada no host.

Acesso:

```text
https://pihole.home
```

### Unbound

Utilizado como upstream do Pi-hole.

Endereço interno:

```text
172.30.0.2:53
```

Diagnóstico pelo próprio servidor:

```text
127.0.0.1:5335
```

Exemplo:

```bash
dig example.com @127.0.0.1 -p 5335
```

---

## Reverse Proxy

### Caddy

O Caddy é o ponto central de entrada HTTP/HTTPS.

Portas:

```text
80
443
```

Rede:

```text
caddy-net
```

IP Docker fixo:

```text
172.29.0.250
```

Os serviços administrativos são preferencialmente acessados através de nomes internos e HTTPS, em vez de portas individuais publicadas na LAN.

---

## Firewall

Firewall:

```text
nftables
```

Arquivo principal das regras específicas do laboratório:

```text
/etc/nftables-homelab.conf
```

Tabela:

```text
inet homelab
```

### Home Assistant

Porta:

```text
8123
```

Permitida para:

```text
localhost
Caddy (172.29.0.250)
```

Demais origens são bloqueadas.

### go2rtc

Porta:

```text
18555
```

Acesso direto bloqueado pela política do homelab.

### Emulated Hue

Porta:

```text
8300
```

Permitida somente para:

```text
Alexa
localhost
```

Existe também redirecionamento específico para permitir descoberta/integração da Alexa com o Emulated Hue.

### Integração com Docker

O arquivo principal do nftables não utiliza:

```text
flush ruleset
```

Isso evita remover as chains de NAT/firewall criadas pelo Docker.

Para atualizar as regras próprias do homelab:

```bash
sudo nft delete table inet homelab
sudo nft -f /etc/nftables-homelab.conf
```

Dessa forma somente a tabela `inet homelab` é recriada.

---

## Speedtest externo

O Dell possui interface Ethernet limitada a 100 Mbps.

Para medir a capacidade real do link, também é utilizado um desktop Windows conectado por Gigabit Ethernet.

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
Caddy
      |
https://speedpc.home
```

Não é utilizado SMB nesse processo.

---

## Acesso remoto

Tecnologia:

```text
Tailscale
```

O homelab anuncia:

```text
192.168.0.0/24
```

como subnet route.

O acesso remoto administrativo não depende de port forwarding convencional no roteador.

---

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

Retenção:

```text
Local: 14 dias
Remoto: 30 dias
```

Tecnologias:

- tar
- sqlite3
- rclone
- Google Drive

O Vaultwarden utiliza backup consistente do banco SQLite.

A chave privada da CA interna do Caddy não é armazenada em claro no backup remoto.

---

## Segurança

Principais controles:

- SSH com autenticação por chave;
- autenticação SSH por senha desabilitada;
- login SSH de root desabilitado;
- Tailscale para acesso remoto;
- HTTPS interno;
- Caddy Internal CA;
- DNS interno;
- nftables;
- interfaces administrativas atrás do Caddy;
- redução de portas publicadas no host;
- `.env` fora do Git;
- secrets substituídos por variáveis;
- Caddy PKI privada fora do backup remoto em claro;
- redes Docker dedicadas;
- IPs estáticos onde regras ou dependências exigem previsibilidade.

---

## Secrets

Arquivos reais:

```text
.env
```

não são versionados.

O repositório utiliza:

```text
.env.example
```

com valores fictícios.

Variáveis atualmente documentadas:

```text
BESZEL_AGENT_TOKEN
PIHOLE_PASSWORD
SPEEDTEST_TRACKER_APP_KEY
```

---

## Infrastructure as Code

Componentes versionados:

- Docker Compose;
- Caddyfile;
- Homepage;
- scripts Bash;
- scripts PowerShell;
- documentação;
- GitHub Actions;
- Ansible;
- Speedtest Desktop;
- configurações reproduzíveis dos serviços.

O repositório representa a configuração desejada da infraestrutura, enquanto dados de runtime, bancos, logs e credenciais permanecem fora do Git.

---

## Reprodutibilidade

### Já tratado

- Docker Compose versionado;
- configurações do Caddy versionadas;
- Homepage versionado;
- scripts versionados;
- documentação da infraestrutura;
- `.env.example`;
- CI;
- rede DNS definida via Compose;
- IP fixo do Unbound;
- IP fixo do Pi-hole na `dns-net`;
- IP fixo do Caddy;
- regras próprias do nftables isoladas;
- serviços administrativos protegidos pelo reverse proxy.

### Pendências

- automatizar criação da rede externa `caddy-net`;
- automatizar deploy das stacks para `/opt`;
- pinning de versões críticas das imagens;
- teste automatizado de restore;
- estratégia segura para backup da CA interna;
- evolução da segmentação de rede;
- VLAN dedicada para IoT.

---

## Estado validado

A infraestrutura foi submetida a reboot completo após alterações de DNS, Docker networking e firewall.

Após a reinicialização foram validados:

- inicialização automática dos containers;
- Pi-hole saudável;
- Unbound saudável;
- resolução DNS externa;
- rede `dns-net`;
- endereçamento estático do DNS;
- Caddy;
- persistência das regras `inet homelab`;
- preservação das chains NAT gerenciadas pelo Docker.

Esse teste é utilizado como validação básica de resiliência após mudanças estruturais na infraestrutura.
