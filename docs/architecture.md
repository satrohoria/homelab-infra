# Arquitetura do Homelab

Este documento representa a arquitetura lógica atual do ambiente, incluindo rede LAN, redes Docker, DNS, reverse proxy, firewall, acesso remoto, automação residencial e backup.

---

## Visão geral

```mermaid
flowchart TB

    Internet((Internet))
    Router["Roteador Claro<br/>192.168.0.1<br/>Gateway + DHCP"]

    Internet --> Router

    subgraph LAN["LAN 192.168.0.0/24"]

        Desktop["Desktop Windows<br/>192.168.0.12<br/>Gigabit Ethernet"]
        Alexa["Amazon Alexa<br/>192.168.0.10"]

        subgraph Dell["Dell Homelab — 192.168.0.2"]
            Debian["Debian 13<br/>Docker Engine + nftables"]

            subgraph DNSNET["dns-net — 172.30.0.0/24"]
                Pihole["Pi-hole<br/>172.30.0.3<br/>DNS :53"]
                Unbound["Unbound<br/>172.30.0.2<br/>DNS upstream"]
                Pihole --> Unbound
            end

            subgraph CADDYNET["caddy-net — 172.29.0.0/16"]
                Caddy["Caddy<br/>172.29.0.250<br/>Reverse Proxy"]
                Homepage["Homepage"]
                Portainer["Portainer"]
                Kuma["Uptime Kuma"]
                Beszel["Beszel"]
                Dozzle["Dozzle"]
                Scrutiny["Scrutiny"]
                SpeedTracker["Speedtest Tracker"]
                Vault["Vaultwarden"]

                Caddy --> Homepage
                Caddy --> Portainer
                Caddy --> Kuma
                Caddy --> Beszel
                Caddy --> Dozzle
                Caddy --> Scrutiny
                Caddy --> SpeedTracker
                Caddy --> Vault
            end

            HA["Home Assistant<br/>Host Network<br/>:8123"]
            Hue["Emulated Hue<br/>:8300"]
            Go2RTC["go2rtc"]
            SpeedPC["Speedtest Desktop<br/>Static files"]
            Diun["Diun"]
            Agent["Beszel Agent<br/>Unix Socket"]

            Debian --> Pihole
            Debian --> Caddy

            Caddy -->|"nftables permite Caddy"| HA
            Caddy --> SpeedPC

            HA --> Hue
            HA --> Go2RTC

            Agent -. "métricas" .-> Beszel
            Diun -. "monitora imagens" .-> Debian
        end
    end

    Router --> Desktop
    Router --> Alexa
    Router --> Dell

    Desktop -->|"Speedtest CLI"| Collector["PowerShell Collector"]
    Collector -->|"CSV + JSON via SCP/SSH"| SpeedPC

    Remote["Dispositivos remotos<br/>Tailscale"]
    Remote -. "VPN / Subnet Route" .-> Dell
```

---

## Topologia de rede

### LAN

```text
192.168.0.0/24
```

Principais endereços:

```text
Gateway / DHCP       192.168.0.1
Homelab / DNS        192.168.0.2
Alexa                192.168.0.10
Desktop Windows      192.168.0.12
```

O roteador da operadora permanece responsável pelo DHCP.

O servidor utiliza endereço estático `192.168.0.2`.

---

## Redes Docker

A infraestrutura utiliza redes Docker distintas conforme a função.

### caddy-net

```text
172.29.0.0/16
```

Rede externa compartilhada entre o Caddy e os serviços publicados pelo reverse proxy.

O Caddy possui endereço fixo:

```text
172.29.0.250
```

O endereço fixo é necessário porque também participa das regras de firewall que controlam o acesso ao Home Assistant.

### dns-net

```text
172.30.0.0/24
```

Rede dedicada ao caminho DNS:

```text
Pi-hole     172.30.0.3
Unbound     172.30.0.2
```

O endereço fixo do Unbound evita dependência de IP Docker dinâmico no upstream do Pi-hole.

---

## Fluxo de acesso aos serviços

Um acesso típico a um serviço interno segue:

```mermaid
sequenceDiagram

    participant C as Cliente
    participant P as Pi-hole
    participant CA as Caddy
    participant S as Serviço

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
Pi-hole :53
   ↓
homelab.home → 192.168.0.2
   ↓
Caddy :443
   ↓
Homepage :3000
```

As portas internas dos serviços administrativos não precisam ser publicadas diretamente na LAN.

---

## Fluxo DNS

```mermaid
flowchart LR

    Client["Cliente LAN"]

    Host["Homelab<br/>192.168.0.2:53"]

    Pi["Pi-hole<br/>172.30.0.3"]

    Local["Registros locais<br/>*.home"]

    Unbound["Unbound<br/>172.30.0.2:53"]

    External["DNS upstream<br/>Internet"]

    Client -->|"Consulta DNS"| Host
    Host --> Pi

    Pi -->|"Domínio local"| Local
    Pi -->|"Domínio externo"| Unbound

    Unbound --> External
```

O Pi-hole é responsável por:

- DNS da LAN;
- resolução dos domínios `.home`;
- bloqueio;
- encaminhamento de consultas externas.

O Unbound é utilizado como upstream.

Para diagnóstico no próprio host:

```text
127.0.0.1:5335 → Unbound :53
```

Exemplo:

```bash
dig example.com @127.0.0.1 -p 5335
```

---

## Reverse Proxy

O Caddy centraliza o acesso HTTP/HTTPS.

```mermaid
flowchart LR

    Client["Cliente LAN"]

    Host["192.168.0.2<br/>:80 / :443"]

    Caddy["Caddy<br/>172.29.0.250"]

    Homepage["Homepage"]
    Pihole["Pi-hole Web"]
    Kuma["Uptime Kuma"]
    Portainer["Portainer"]
    Beszel["Beszel"]
    Dozzle["Dozzle"]
    Scrutiny["Scrutiny"]
    Speed["Speedtest"]
    Vault["Vaultwarden"]
    HA["Home Assistant"]

    Client -->|"HTTPS"| Host
    Host --> Caddy

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

Os serviços são acessados através de nomes como:

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

---

## Firewall

O firewall do host utiliza `nftables`.

As regras específicas do laboratório ficam isoladas em:

```text
table inet homelab
```

Arquivo:

```text
/etc/nftables-homelab.conf
```

### Home Assistant

Fluxo permitido:

```mermaid
flowchart LR

    Client["Cliente"]
    Caddy["Caddy<br/>172.29.0.250"]
    FW["nftables"]
    HA["Home Assistant<br/>:8123"]

    Client -->|"HTTPS :443"| Caddy
    Caddy --> FW
    FW -->|"Permitido"| HA

    Direct["Acesso direto LAN<br/>:8123"]
    Direct -->|"Bloqueado"| FW
```

A porta `8123` aceita:

```text
localhost
172.29.0.250 (Caddy)
```

e bloqueia o restante.

### go2rtc

A porta `18555` não é disponibilizada diretamente para clientes da LAN.

### Docker

O nftables do homelab não executa:

```text
flush ruleset
```

globalmente.

Isso é necessário porque o Docker mantém suas próprias chains de NAT e firewall.

As regras próprias podem ser recarregadas independentemente:

```bash
sudo nft delete table inet homelab
sudo nft -f /etc/nftables-homelab.conf
```

Assim, as chains gerenciadas pelo Docker permanecem intactas.

---

## Alexa e Emulated Hue

O Home Assistant utiliza Emulated Hue para integração local com Alexa.

Fluxo simplificado:

```mermaid
flowchart LR

    Alexa["Alexa<br/>192.168.0.10"]

    Host["Homelab<br/>192.168.0.2:80"]

    NFT["nftables<br/>redirect"]

    Hue["Emulated Hue<br/>:8300"]

    HA["Home Assistant"]

    Alexa --> Host
    Host --> NFT
    NFT -->|"redirect :8300"| Hue
    Hue --> HA
```

A porta `8300` é permitida somente para:

```text
192.168.0.10
localhost
```

O redirecionamento também é limitado ao IP da Alexa.

---

## Speedtest Desktop

O servidor Dell possui interface Fast Ethernet de 100 Mbps.

Por isso, uma segunda máquina realiza medições capazes de utilizar a conexão Gigabit.

```mermaid
flowchart LR

    Internet((Internet))

    Desktop["Desktop Windows<br/>192.168.0.12<br/>Gigabit"]

    CLI["Ookla<br/>Speedtest CLI"]

    PS["PowerShell<br/>Collector"]

    CSV["CSV"]
    JSON["JSON"]

    SSH["SCP / SSH"]

    Dell["Homelab"]

    Caddy["Caddy"]

    Dashboard["speedpc.home"]

    Internet --> Desktop
    Desktop --> CLI
    CLI --> PS

    PS --> CSV
    PS --> JSON

    CSV --> SSH
    JSON --> SSH

    SSH --> Dell
    Dell --> Caddy
    Caddy --> Dashboard
```

Não é utilizado SMB nesse fluxo.

---

## Backup

```mermaid
flowchart LR

    Services["Configurações<br/>dos serviços"]

    Vault["Vaultwarden<br/>SQLite"]

    Script["homelab-backup.sh"]

    Integrity["SQLite<br/>integrity_check"]

    Local["/opt/backups<br/>14 dias"]

    Rclone["rclone"]

    Drive["Google Drive<br/>30 dias"]

    Services --> Script

    Vault --> Integrity
    Integrity --> Script

    Script --> Local

    Local --> Rclone
    Rclone --> Drive
```

A PKI privada do Caddy não é enviada em claro para o armazenamento remoto.

---

## Acesso remoto

```mermaid
flowchart LR

    Device["Notebook / Smartphone<br/>fora da LAN"]

    Tail["Tailscale"]

    Homelab["Homelab"]

    Route["Subnet Route<br/>192.168.0.0/24"]

    LAN["LAN"]

    Services["Serviços internos"]

    Device --> Tail
    Tail --> Homelab
    Homelab --> Route
    Route --> LAN
    LAN --> Services
```

O homelab anuncia:

```text
192.168.0.0/24
```

como subnet route.

Isso permite acesso remoto sem expor interfaces administrativas diretamente à internet.

---

## Separação de exposição

A arquitetura diferencia três níveis de exposição.

```mermaid
flowchart TB

    LAN["LAN"]

    subgraph PublicHost["Portas do host"]
        SSH["22<br/>SSH"]
        DNS["53<br/>Pi-hole"]
        HTTP["80/443<br/>Caddy"]
    end

    subgraph Proxy["Atrás do Caddy"]
        Portainer
        Homepage
        Kuma["Uptime Kuma"]
        Beszel
        Dozzle
        Scrutiny
        Vaultwarden
        PiholeWeb["Pi-hole Web"]
    end

    subgraph Restricted["Restrito pelo firewall"]
        HA["8123<br/>Home Assistant"]
        Hue["8300<br/>Emulated Hue"]
        Go["18555<br/>go2rtc"]
    end

    LAN --> PublicHost
    HTTP --> Proxy
    LAN -. "regras nftables" .-> Restricted
```

O objetivo é reduzir a superfície de ataque e centralizar o acesso web no reverse proxy.

---

## Resiliência e troubleshooting

Um incidente de DNS durante a evolução do laboratório demonstrou a interação entre firewall e Docker networking.

Fluxo investigado:

```mermaid
flowchart LR

    Client["Cliente"]
    Pi["Pi-hole"]
    UB["Unbound"]
    Docker["Docker Networking"]
    NFT["nftables"]
    Internet((Internet))

    Client --> Pi
    Pi --> UB
    UB --> Docker
    Docker --> NFT
    NFT --> Internet
```

Foi identificado que uma recarga global do nftables utilizando `flush ruleset` removia chains NAT criadas pelo Docker.

Isso podia gerar um cenário em que containers existentes continuavam parcialmente funcionais, enquanto containers reiniciados não conseguiam recriar seus mapeamentos de portas.

Também foi eliminada a dependência de IP dinâmico entre Pi-hole e Unbound.

A correção incluiu:

- remoção do `flush ruleset` global;
- isolamento das regras em `inet homelab`;
- recarga independente das regras próprias;
- criação da `dns-net`;
- IP estático `172.30.0.2` para Unbound;
- IP estático `172.30.0.3` para Pi-hole;
- IP estático `172.29.0.250` para Caddy;
- validação das chains NAT do Docker;
- teste completo após reboot.

Após a reinicialização foram validados:

```text
Docker
Pi-hole
Unbound
DNS externo
Caddy
nftables
redes Docker
serviços persistentes
```

---

## Fluxo de mudança

As alterações seguem o fluxo:

```mermaid
flowchart LR

    Change["Mudança"]

    Lab["Implementação<br/>no Homelab"]

    Test["Teste"]

    Reboot["Teste de<br/>persistência"]

    IaC["Atualização<br/>do IaC"]

    Git["Git"]

    GitHub["GitHub / CI"]

    Change --> Lab
    Lab --> Test
    Test --> Reboot
    Reboot --> IaC
    IaC --> Git
    Git --> GitHub
```

Esse processo permite que problemas de persistência, dependências de rede e diferenças entre configuração declarada e ambiente real sejam encontrados antes de considerar uma alteração concluída.

---

## Princípios da arquitetura

O ambiente busca aplicar práticas utilizadas em infraestrutura, operações e DevOps:

- serviços declarados com Docker Compose;
- configuração versionada em Git;
- secrets separados do código;
- DNS centralizado;
- redes Docker segmentadas por função;
- endereçamento estático quando necessário;
- reverse proxy centralizado;
- redução de portas diretamente expostas;
- HTTPS interno;
- firewall;
- observabilidade;
- health monitoring;
- backup automatizado;
- acesso remoto privado;
- documentação versionada;
- validação pós-reboot;
- troubleshooting baseado em camadas;
- Infrastructure as Code.
