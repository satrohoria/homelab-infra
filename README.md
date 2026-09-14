# Homelab Infrastructure

Infraestrutura de homelab criada para estudo e prática de Linux, Docker, redes, DNS, segurança, monitoramento, automação e Infrastructure as Code.

O ambiente roda sobre um notebook Dell com Debian 13, utilizando Docker e serviços internos publicados via HTTPS com Caddy.

---

## Documentação

Documentação adicional do projeto:

- `docs/architecture.md` — arquitetura detalhada e fluxos
- `docs/inventory.md` — inventário de infraestrutura e serviços

---

## Objetivos

Este laboratório foi criado para praticar conceitos utilizados em ambientes reais de infraestrutura:

- Linux
- Docker
- Docker Compose
- Redes
- DNS
- Reverse Proxy
- HTTPS interno
- Monitoramento
- Observabilidade
- Segurança
- Backup
- Automação
- Infrastructure as Code
- Troubleshooting
- Git / GitHub
- CI/CD

---

## Arquitetura resumida

```text
                         INTERNET
                            │
                            │
                     Claro / Vantiva
                      192.168.0.1
                       DHCP da LAN
                            │
                            │
                   ┌────────┴────────┐
                   │                 │
               Clientes          Homelab
                                192.168.0.2
                                     │
                  ┌──────────────────┼──────────────────┐
                  │                  │                  │
               Pi-hole             Caddy          Home Assistant
              DNS interno       Reverse Proxy
                  │                  │
                  │             HTTPS interno
               Unbound               │
            DNS upstream       Serviços Docker
```

O servidor concentra DNS, reverse proxy, monitoramento, automação residencial, gerenciamento de containers e outros serviços internos.

---

## Hardware

Servidor principal:

| Componente | Configuração |
|---|---|
| Equipamento | Notebook Dell |
| Processador | Intel Core i5-4210U |
| Memória | 4 GB RAM |
| Armazenamento | SSD SATA 240 GB |
| Sistema | Debian 13 |
| Interface principal | Ethernet |
| Hostname | `homelab` |

O equipamento foi reaproveitado como servidor doméstico headless.

---

## Rede

### LAN

```text
Rede:       192.168.0.0/24
Gateway:    192.168.0.1
Homelab:    192.168.0.2
```

O servidor utiliza endereço IPv4 estático.

O roteador da operadora permanece responsável pelo DHCP.

DNS principal utilizado nos dispositivos configurados para utilizar o homelab:

```text
192.168.0.2
```

O Pi-hole atua como DNS da LAN.

Devido a limitações do firmware do roteador da operadora, alguns dispositivos podem receber servidores DNS adicionais via DHCP. Dispositivos críticos podem utilizar o Pi-hole manualmente como DNS.

---

## DNS

### Pi-hole

O Pi-hole é responsável por:

- DNS interno
- resolução dos domínios `.home`
- bloqueio de domínios
- observabilidade das consultas
- encaminhamento das consultas externas para o Unbound

Exemplos de nomes internos:

```text
homelab.home
pihole.home
status.home
portainer.home
beszel.home
logs.home
scrutiny.home
speedtest.home
vault.home
casa.home
speedpc.home
```

O Pi-hole atende a LAN através de:

```text
192.168.0.2:53
```

A interface web não possui porta administrativa publicada diretamente no host.

O acesso é realizado através do Caddy:

```text
https://pihole.home
```

### Rede DNS dedicada

Pi-hole e Unbound possuem uma rede Docker dedicada:

```text
dns-net
172.30.0.0/24
```

Endereços fixos:

```text
Pi-hole:  172.30.0.3
Unbound:  172.30.0.2
```

O endereço estático do Unbound evita que o upstream configurado no Pi-hole seja perdido após recriações dos containers.

### Unbound

O Unbound atua como upstream DNS do Pi-hole.

Fluxo:

```text
Cliente
   │
   ▼
Pi-hole
192.168.0.2:53
   │
   ▼
Unbound
172.30.0.2:53
   │
   ▼
DNS upstream
   │
   ▼
Internet
```

Para diagnóstico diretamente no servidor, o Unbound também é publicado somente em loopback:

```text
127.0.0.1:5335
```

Isso permite testes como:

```bash
dig example.com @127.0.0.1 -p 5335
```

sem expor essa porta para a LAN.

---

## Reverse Proxy

### Caddy

O Caddy centraliza o acesso HTTP/HTTPS aos serviços internos.

Rede Docker:

```text
caddy-net
172.29.0.0/16
```

O Caddy utiliza endereço fixo:

```text
172.29.0.250
```

O endereço estático também permite que regras de firewall identifiquem explicitamente o reverse proxy.

Os serviços internos utilizam certificados emitidos pela CA interna do Caddy.

Exemplo:

```text
https://homelab.home
https://status.home
https://portainer.home
https://pihole.home
https://vault.home
https://casa.home
```

A CA interna é instalada nos dispositivos confiáveis quando necessário.

---

## Serviços

### Infraestrutura

- Pi-hole
- Unbound
- Caddy
- Portainer
- Tailscale

### Monitoramento

- Uptime Kuma
- Beszel
- Beszel Agent
- Dozzle
- Scrutiny
- Speedtest Tracker

### Serviços

- Homepage
- Vaultwarden
- Home Assistant
- Diun

---

## Speedtest Desktop

Além dos testes realizados diretamente pelo servidor, existe uma rotina de teste executada em um desktop Windows conectado por Gigabit Ethernet.

Isso permite separar:

```text
capacidade do link de internet
```

de:

```text
limitação física da interface Fast Ethernet do notebook
```

O desktop executa o Speedtest CLI e publica os resultados para o homelab.

Os resultados podem ser acessados através de:

```text
https://speedpc.home
```

Fluxo:

```text
Windows Desktop
      │
      │ SCP
      ▼
Homelab
      │
      ▼
Caddy
      │
      ▼
https://speedpc.home
```

Não é utilizado SMB nesse fluxo.

---

## Homepage

O Homepage funciona como dashboard principal do ambiente.

Acesso:

```text
https://homelab.home
```

Ele concentra atalhos e informações dos principais serviços.

A integração com Docker utiliza acesso somente leitura ao socket quando possível.

---

## Home Assistant

O Home Assistant roda em container utilizando `network_mode: host`.

Acesso:

```text
https://casa.home
```

A porta nativa:

```text
8123
```

não fica disponível diretamente para os clientes da LAN.

O nftables permite acesso à porta apenas através do Caddy e do próprio servidor.

O ambiente também utiliza integração com dispositivos Tuya e Alexa.

Para compatibilidade com Alexa através do Emulated Hue, regras específicas de firewall e redirecionamento são utilizadas.

---

## Vaultwarden

O Vaultwarden fornece gerenciamento de senhas dentro da infraestrutura.

Acesso:

```text
https://vault.home
```

Características:

- não possui porta web publicada diretamente para a LAN;
- é acessado através do Caddy;
- criação pública de novas contas permanece desabilitada;
- dados persistentes são incluídos na estratégia de backup.

---

## Acesso remoto

O acesso remoto ao homelab utiliza Tailscale.

O servidor também anuncia a rede:

```text
192.168.0.0/24
```

como subnet route.

Isso permite acesso remoto aos recursos internos sem necessidade de publicação direta de serviços na internet.

Não são utilizados port forwards convencionais para administração do homelab.

---

## Backup

Os backups são realizados através de scripts e `rclone`.

Destino remoto:

```text
Google Drive
```

Política utilizada:

```text
Backups locais: 14 dias
Backups remotos: 30 dias
```

Os backups incluem dados persistentes importantes dos serviços.

Para bancos SQLite, como o Vaultwarden, é utilizado processo de backup consistente em vez de simples cópia do arquivo em uso.

A PKI privada do Caddy não é enviada em claro para o armazenamento em nuvem.

---

## Infrastructure as Code

As configurações principais do ambiente são mantidas neste repositório.

Estrutura aproximada:

```text
homelab-infra/
├── ansible/
├── apps/
├── caddy/
├── docker/
├── docs/
├── homepage/
├── scripts/
└── windows/
```

Exemplos de itens versionados:

- Docker Compose
- Caddyfile
- configurações do Homepage
- scripts
- documentação
- automações
- exemplos de variáveis de ambiente

Segredos reais não são versionados.

Arquivos `.env` são ignorados pelo Git e o repositório mantém somente:

```text
.env.example
```

como referência.

---

## Segurança

A infraestrutura utiliza múltiplas camadas de proteção.

### SSH

O SSH utiliza autenticação por chave.

Configurações principais:

```text
PasswordAuthentication no
PermitRootLogin no
MaxAuthTries 3
PubkeyAuthentication yes
```

### Serviços Docker

Interfaces administrativas não são publicadas diretamente quando não há necessidade.

Sempre que possível, o acesso ocorre através do Caddy.

Exemplos:

```text
Portainer
Beszel
Dozzle
Scrutiny
Uptime Kuma
Homepage
Pi-hole Web
Vaultwarden
```

### nftables

As regras específicas do homelab são mantidas em:

```text
/etc/nftables-homelab.conf
```

dentro da tabela:

```text
inet homelab
```

Entre as regras existentes estão:

- Home Assistant `8123` acessível somente pelo localhost e pelo Caddy;
- go2rtc `18555` bloqueado para acesso direto;
- Emulated Hue `8300` permitido somente para a Alexa e localhost;
- redirecionamento específico da Alexa para o Emulated Hue.

O arquivo principal do nftables **não utiliza `flush ruleset`**.

Isso é importante porque o Docker mantém suas próprias chains de firewall/NAT. Um `flush ruleset` global remove essas chains e pode interromper publicação de portas e comunicação dos containers.

Para manutenção, somente a tabela específica do homelab deve ser recarregada.

Exemplo:

```bash
sudo nft delete table inet homelab
sudo nft -f /etc/nftables-homelab.conf
```

Assim, as chains gerenciadas pelo Docker permanecem intactas.

### Docker networking

Serviços que precisam se comunicar internamente utilizam redes Docker dedicadas.

Exemplos:

```text
caddy-net
dns-net
```

O Caddy utiliza:

```text
172.29.0.250
```

O ambiente DNS utiliza:

```text
Unbound: 172.30.0.2
Pi-hole: 172.30.0.3
```

Isso reduz dependência de endereços Docker dinâmicos em componentes onde o endereço é utilizado por configurações ou regras de firewall.

### Credenciais

Credenciais não são armazenadas diretamente nos arquivos versionados.

São utilizadas variáveis de ambiente, por exemplo:

```text
PIHOLE_PASSWORD
BESZEL_AGENT_TOKEN
SPEEDTEST_TRACKER_APP_KEY
```

Os valores reais permanecem fora do Git.

---

## Tecnologias

Principais tecnologias utilizadas:

- Debian
- Linux
- Docker
- Docker Compose
- Git
- GitHub
- GitHub Actions
- nftables
- Caddy
- Pi-hole
- Unbound
- Tailscale
- Home Assistant
- Portainer
- Uptime Kuma
- Beszel
- Dozzle
- Scrutiny
- Vaultwarden
- rclone
- PowerShell
- Bash
- YAML

---

## Roadmap

### Concluído

- [x] Debian headless
- [x] Docker
- [x] Docker Compose
- [x] IP estático
- [x] DNS interno
- [x] Pi-hole
- [x] Unbound
- [x] HTTPS interno
- [x] Caddy
- [x] Monitoramento
- [x] Dashboard
- [x] SMART monitoring
- [x] Speedtest
- [x] Gerenciamento de containers
- [x] Acesso remoto com Tailscale
- [x] Backup local e remoto
- [x] Vaultwarden
- [x] Home Assistant
- [x] Integração Alexa / Emulated Hue
- [x] Hardening SSH
- [x] Firewall com nftables
- [x] Remoção de portas administrativas desnecessárias
- [x] Redes Docker dedicadas para DNS
- [x] IP fixo do Caddy
- [x] Infrastructure as Code
- [x] CI no GitHub

### Próximos estudos

- [ ] VLANs
- [ ] Segmentação IoT
- [ ] Router/firewall dedicado
- [ ] Melhorias de observabilidade
- [ ] Testes automatizados de restore
- [ ] Pinning de versões críticas dos containers

Uma evolução futura possível é utilizar um roteador/firewall dedicado para assumir DHCP, segmentação e políticas de rede, permitindo maior controle sobre DNS e dispositivos IoT.

---

## Fluxo DevOps

O projeto segue um fluxo simples de infraestrutura versionada:

```text
Mudança
   │
   ▼
Teste no Homelab
   │
   ▼
Validação
   │
   ▼
Atualização do IaC
   │
   ▼
Git
   │
   ▼
GitHub
   │
   ▼
CI
```

O objetivo é tratar mudanças de infraestrutura como código, mantendo histórico, documentação e possibilidade de reprodução.

Incidentes encontrados durante testes e reinicializações são utilizados para melhorar a resiliência do ambiente e atualizar o IaC.

---

## Troubleshooting aplicado

Durante a evolução do laboratório, problemas reais de infraestrutura são tratados como parte do aprendizado.

Um exemplo foi uma falha de resolução DNS após alterações de firewall.

A investigação passou por:

```text
Cliente
  ↓
Pi-hole
  ↓
Unbound
  ↓
Docker networking
  ↓
Firewall/NAT
  ↓
Internet
```

Foi identificado que uma recarga global do nftables removia chains NAT gerenciadas pelo Docker.

Containers já em execução podiam continuar funcionando parcialmente, mas operações de restart ou recriação falhavam ao tentar reconstruir os mapeamentos de portas.

A solução incluiu:

- remover `flush ruleset` da configuração global;
- isolar as regras próprias na tabela `inet homelab`;
- recarregar somente a tabela do homelab;
- criar uma rede Docker dedicada para DNS;
- definir IP fixo para o Unbound;
- remover dependência de IP Docker dinâmico;
- validar o ambiente através de reboot completo.

O ambiente foi testado após reinicialização, confirmando recuperação automática dos containers, DNS, reverse proxy e regras de firewall.

---

## Autor

**Lenilson Santiago Nunes**

Infrastructure / IT Operations

Projeto desenvolvido como laboratório prático de infraestrutura, redes, Linux, containers, segurança, automação e observabilidade.
