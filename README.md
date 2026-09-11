# Homelab Infrastructure

Homelab pessoal voltado para estudos e prática de **Infraestrutura, DevOps, automação, monitoramento, containers, redes, observabilidade e serviços self-hosted**.

O ambiente roda sobre um notebook Dell com Debian 13, utilizando Docker e serviços internos publicados via HTTPS com Caddy.

---

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
- DevOps

---
## Documentação

- [Arquitetura](docs/architecture.md)
- [Inventário técnico](docs/inventory.md)
---
## Arquitetura

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
