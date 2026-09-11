# Arquitetura do Homelab

Este documento representa a arquitetura lógica atual do ambiente.

## Visão geral

```mermaid
flowchart TB

    Internet((Internet))

    Router["Roteador Claro<br/>192.168.0.1<br/>Gateway + DHCP"]

    Internet --> Router

    subgraph LAN["LAN 192.168.0.0/24"]

        Desktop["Desktop Windows<br/>192.168.0.12<br/>Gigabit Ethernet"]

        subgraph Dell["Dell Homelab — 192.168.0.2"]
            Debian["Debian 13<br/>Docker Engine"]

            Pihole["Pi-hole<br/>DNS :53"]
            Unbound["Unbound<br/>DNS Recursivo"]
            Caddy["Caddy<br/>Reverse Proxy<br/>HTTP :80 / HTTPS :443"]

            Homepage["Homepage"]
            Portainer["Portainer"]
            Kuma["Uptime Kuma"]
            Beszel["Beszel"]
            Dozzle["Dozzle"]
            Scrutiny["Scrutiny"]
            SpeedTracker["Speedtest Tracker"]
            SpeedPC["Speedtest Desktop<br/>Dashboard + JSON"]
            Vault["Vaultwarden"]
            HA["Home Assistant"]
            Diun["Diun"]

            Debian --> Pihole
            Debian --> Caddy

            Pihole --> Unbound

            Caddy --> Homepage
            Caddy --> Portainer
            Caddy --> Kuma
            Caddy --> Beszel
            Caddy --> Dozzle
            Caddy --> Scrutiny
            Caddy --> SpeedTracker
            Caddy --> SpeedPC
            Caddy --> Vault
            Caddy --> HA

            Diun -. monitora imagens .-> Debian
        end

    end

    Router --> Desktop
    Router --> Dell

    Desktop -->|"Speedtest CLI"| DesktopCollector["PowerShell Collector"]
    DesktopCollector -->|"CSV + JSON via SCP/SSH"| SpeedPC

    Pihole -. "DNS da LAN" .-> Desktop

    Remote["Dispositivos remotos<br/>Tailscale"]
    Remote -. "VPN / Subnet Route" .-> Dell
```

---

## Fluxo de acesso aos serviços

Um acesso típico a um serviço interno segue:

```mermaid
sequenceDiagram

    participant C as Cliente
    participant P as Pi-hole
    participant CA as Caddy
    participant S as Serviço Docker

    C->>P: Consulta exemplo.home
    P-->>C: 192.168.0.2

    C->>CA: HTTPS :443
    CA->>S: Reverse Proxy
    S-->>CA: Resposta
    CA-->>C: HTTPS
```

Exemplo:

```text
Cliente
   ↓
Pi-hole
   ↓
homelab.home → 192.168.0.2
   ↓
Caddy :443
   ↓
Homepage :3000
```

---

## Fluxo DNS

```mermaid
flowchart LR

    Client["Cliente LAN"]
    Pi["Pi-hole<br/>192.168.0.2"]
    Unbound["Unbound"]
    DNS["DNS autoritativo<br/>Internet"]

    Client -->|"Consulta DNS"| Pi

    Pi -->|"Domínio local"| Local["Registro local<br/>*.home"]

    Pi -->|"Domínio externo"| Unbound

    Unbound --> DNS
```

O roteador continua responsável pelo DHCP, enquanto o Pi-hole é responsável pelo DNS da rede.

---

## Reverse Proxy

O Caddy centraliza o acesso HTTP/HTTPS.

```mermaid
flowchart LR

    Client["Cliente"]

    Caddy["Caddy<br/>192.168.0.2<br/>:80 / :443"]

    Homepage["Homepage"]
    Pihole["Pi-hole"]
    Kuma["Uptime Kuma"]
    Portainer["Portainer"]
    Beszel["Beszel"]
    Dozzle["Dozzle"]
    Scrutiny["Scrutiny"]
    Speed["Speedtest Desktop"]
    Vault["Vaultwarden"]
    HA["Home Assistant"]

    Client -->|HTTPS| Caddy

    Caddy --> Homepage
    Caddy --> Pihole
    Caddy --> Kuma
    Caddy --> Portainer
    Caddy --> Beszel
    Caddy --> Dozzle
    Caddy --> Scrutiny
    Caddy --> Speed
    Caddy --> Vault
    Caddy --> HA
```

---

## Speedtest Desktop

O servidor Dell possui interface Fast Ethernet de 100 Mbps.

Por isso, uma segunda máquina realiza as medições de Internet.

```mermaid
flowchart LR

    Internet((Internet))

    Desktop["Desktop Windows<br/>Gigabit Ethernet"]

    CLI["Ookla<br/>Speedtest CLI"]

    PS["PowerShell<br/>speedtest-monitor.ps1"]

    CSV["speedtest-history.csv"]

    JSON["speedtest-latest.json"]

    SSH["SCP / SSH"]

    Dell["Dell Homelab"]

    Dashboard["speedpc.home"]

    Homepage["Homepage<br/>Custom API Widget"]

    Internet --> Desktop

    Desktop --> CLI
    CLI --> PS

    PS --> CSV
    PS --> JSON

    CSV --> SSH
    JSON --> SSH

    SSH --> Dell

    Dell --> Dashboard

    JSON --> Homepage
```

O teste utiliza um servidor fixo para manter as medições comparáveis ao longo do tempo.

---

## Backup

```mermaid
flowchart LR

    Services["Configurações<br/>dos serviços"]

    Vault["Vaultwarden<br/>SQLite"]

    Script["homelab-backup.sh"]

    Integrity["SQLite<br/>integrity_check"]

    Local["/opt/backups"]

    Rclone["rclone"]

    Drive["Google Drive<br/>Homelab/Backups"]

    Services --> Script

    Vault --> Integrity
    Integrity --> Script

    Script --> Local

    Local --> Rclone
    Rclone --> Drive
```

A PKI privada do Caddy não é enviada para o armazenamento em nuvem.

---

## Acesso remoto

```mermaid
flowchart LR

    Phone["Notebook / Smartphone<br/>fora da LAN"]

    Tail["Tailscale"]

    Homelab["Homelab<br/>192.168.0.2"]

    LAN["LAN<br/>192.168.0.0/24"]

    Services["Serviços *.home"]

    Phone --> Tail
    Tail --> Homelab
    Homelab --> LAN
    LAN --> Services
```

O Homelab anuncia a subnet `192.168.0.0/24`, permitindo acesso remoto aos serviços internos.

---

## Princípios da arquitetura

O ambiente busca aplicar práticas utilizadas em infraestrutura e DevOps:

- serviços declarados com Docker Compose;
- configuração versionada em Git;
- secrets separados do código;
- DNS centralizado;
- reverse proxy centralizado;
- HTTPS;
- observabilidade;
- health monitoring;
- backup automatizado;
- acesso remoto privado;
- documentação versionada;
- evolução para Infrastructure as Code.
