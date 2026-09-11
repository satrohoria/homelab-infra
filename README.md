# Homelab Infrastructure

Homelab pessoal voltado para estudos e prática de **Infraestrutura, DevOps, automação, monitoramento, containers, redes, observabilidade e serviços self-hosted**.

O ambiente roda sobre um notebook Dell com Debian 13, utilizando Docker e serviços internos publicados via HTTPS com Caddy.

## Documentação

- [Arquitetura](docs/architecture.md)
- [Inventário técnico](docs/inventory.md)

## Objetivos

Este projeto tem como objetivo transformar um ambiente de infraestrutura doméstica em uma plataforma prática para estudos de:

- Linux
- Docker
- Docker Compose
- Redes
- DNS
- Reverse Proxy
- HTTPS
- Monitoramento
- Observabilidade
- Backup
- Automação
- Git
- Infrastructure as Code
- Ansible
- CI/CD
- DevOps

## Arquitetura resumida

```text
                    Internet
                       |
                 Roteador Claro
                  192.168.0.1
                       |
              +--------+--------+
              |                 |
        Homelab Dell         Desktop
        192.168.0.2          192.168.0.12
              |                 |
              |                 +--> Speedtest CLI
              |                      coleta via Gigabit
              |                           |
              |                           +--> SCP
              |                                |
              +--------------------------------+
              |
         Docker / Debian
              |
    +---------+----------+
    |                    |
 Pi-hole              Caddy
 DNS interno        Reverse Proxy
    |                    |
    +--------+-----------+
             |
      Serviços HTTPS
```

## Hardware

Servidor principal:

- Dell notebook
- Intel Core i5-4210U
- 4 GB RAM
- SSD SATA 240 GB
- Ethernet Fast Ethernet 100 Mbps
- Debian 13
- Ambiente headless

O servidor possui limitação física de 100 Mbps na interface Ethernet onboard.

Para medições reais da conexão de Internet, foi criado um coletor de Speedtest em um desktop com interface Gigabit Ethernet.

## Rede

### LAN

```text
192.168.0.0/24
```

Gateway:

```text
192.168.0.1
```

Servidor Homelab:

```text
192.168.0.2
```

DNS principal:

```text
192.168.0.2
```

O Pi-hole atua como DNS da LAN.

## DNS

### Pi-hole

Responsável por:

- DNS interno
- Bloqueio de anúncios
- Bloqueio de trackers
- Resolução de nomes locais

Exemplos:

```text
homelab.home
pihole.home
status.home
portainer.home
beszel.home
logs.home
scrutiny.home
speedtest.home
speedpc.home
vault.home
casa.home
```

### Unbound

Utilizado como DNS recursivo junto ao Pi-hole.

## Reverse Proxy

### Caddy

Responsável por:

- Reverse Proxy
- HTTPS interno
- Certificados internos
- Publicação dos serviços

## Serviços

### Infraestrutura

- Pi-hole
- Unbound
- Caddy
- Portainer

### Monitoramento

- Uptime Kuma
- Beszel
- Dozzle
- Scrutiny
- Speedtest Tracker
- Speedtest Desktop

### Serviços

- Vaultwarden
- Home Assistant
- Homepage
- Diun

## Speedtest Desktop

O Dell possui interface Ethernet limitada a 100 Mbps.

Para medir a conexão real, um desktop Windows executa o Ookla Speedtest CLI e envia os resultados ao Homelab.

```text
Windows Desktop
      |
Ookla Speedtest CLI
      |
PowerShell
      |
CSV + JSON
      |
SCP / SSH
      |
Dell Homelab
      |
Caddy
      |
Dashboard Web
```

O resultado mais recente também é disponibilizado em JSON e integrado ao Homepage.

## Homepage

O Homepage funciona como dashboard central do ambiente.

Categorias:

- Infraestrutura
- Monitoramento
- Serviços

O card do Speedtest Desktop utiliza um Custom API Widget para exibir:

- Download
- Upload
- Ping
- Perda de pacotes

## Home Assistant

Utilizado para automação residencial e integração com dispositivos IoT.

## Vaultwarden

Servidor Bitwarden self-hosted.

Características:

- não expõe porta diretamente no host;
- é acessado através do Caddy;
- novos cadastros estão desativados.

## Acesso remoto

O acesso remoto ao Homelab é realizado utilizando Tailscale.

A subnet anunciada é:

```text
192.168.0.0/24
```

## Backup

Os backups são executados por script automatizado.

Principais recursos:

- backup das configurações dos serviços;
- snapshot consistente do banco SQLite do Vaultwarden;
- validação de integridade;
- retenção local;
- retenção em nuvem;
- sincronização com Google Drive via rclone.

A PKI privada do Caddy não é enviada em claro para o armazenamento em nuvem.

## Infrastructure as Code

Estrutura atual:

```text
homelab-infra/
├── .github/
├── ansible/
├── apps/
├── caddy/
├── docker/
├── docs/
├── homepage/
├── scripts/
├── windows/
├── .env.example
├── .gitignore
└── README.md
```

## Segurança

Credenciais não devem ser versionadas.

Secrets são substituídos por variáveis de ambiente.

Exemplo:

```yaml
TOKEN: "${BESZEL_AGENT_TOKEN}"
```

O arquivo `.env` não é versionado.

O repositório contém apenas `.env.example` com valores de exemplo.

## Tecnologias

- Debian Linux
- Docker
- Docker Compose
- Git
- GitHub Actions
- Ansible
- Caddy
- Pi-hole
- Unbound
- Portainer
- Uptime Kuma
- Beszel
- Dozzle
- Scrutiny
- Speedtest Tracker
- Home Assistant
- Vaultwarden
- Tailscale
- rclone
- PowerShell
- SSH
- SCP

## Roadmap

- [x] Containerização dos serviços
- [x] DNS interno
- [x] Reverse Proxy
- [x] HTTPS interno
- [x] Monitoramento
- [x] Backup automatizado
- [x] Acesso remoto
- [x] Speedtest externo via desktop
- [x] Git local
- [x] GitHub
- [x] CI básica
- [x] Ansible baseline
- [ ] Ansible para Docker e stacks
- [ ] Provisionamento completo
- [ ] Fixar versões das imagens
- [ ] Scanner dedicado de secrets
- [ ] Healthchecks padronizados
- [ ] Disaster recovery completo
- [ ] CD controlado

## Fluxo DevOps

```text
Infraestrutura
      ↓
Docker
      ↓
Git
      ↓
GitHub
      ↓
CI
      ↓
Infrastructure as Code
      ↓
Ansible
      ↓
Automação
```

## Autor

**Lenilson Nunes**

Infraestrutura de TI
Estudos e projetos de Infra / DevOps / Automação
