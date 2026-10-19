# ALL MDM — imagem Docker

Imagem do [Headwind MDM](https://h-mdm.com) (código aberto, Apache 2.0) com a marca da **ALL Tecnologias**.
Fork de [h-mdm/hmdm-docker](https://github.com/h-mdm/hmdm-docker); o README original está em [README.headwind.md](README.headwind.md).

São três repositórios que trabalham juntos:

| Repositório | Gera | Publicado em |
|---|---|---|
| [all-mdm-server](https://github.com/allexandercaneschi/all-mdm-server) | Painel com a marca ALL (`.war`) | Releases do repositório |
| [all-mdm-android](https://github.com/allexandercaneschi/all-mdm-android) | Agente ALL MDM (`.apk` assinado) | Releases do repositório |
| **all-mdm** (este) | Imagem Docker que junta os dois | `ghcr.io/allexandercaneschi/all-mdm` |

## O que muda em relação à imagem da Headwind

- Baixa o painel e o agente dos Releases da ALL, não do site da Headwind.
- Na primeira instalação, cadastra o agente ALL (`br.com.alltecnologias.mdm`) como app padrão das configurações.
- Nome, fornecedor e link da ALL no painel (`BRAND_*`).
- **Proxy reverso:** `PUBLIC_PROTOCOL` separa o protocolo público (`https`) do protocolo do Tomcat (`http`).
  Sem isso, os celulares recebem links `http://` quebrados.
- Parâmetros da ALL e o `SHARED_SECRET` são reaplicados a cada subida, inclusive em instalações existentes.
- Ao trocar a versão da imagem, o painel novo é implantado sozinho (antes exigia `FORCE_RECONFIGURE`).
- `docker-compose.yaml` pronto para Portainer: PostgreSQL externo, porta 8800, volumes nomeados, sem certbot.

## Primeira publicação (uma vez)

1. **Agente Android:** siga o [ALL-MDM.md do all-mdm-android](https://github.com/allexandercaneschi/all-mdm-android/blob/all-branding/ALL-MDM.md)
   para criar a chave de assinatura e os secrets. Depois crie a tag `v6.40-all.1`.
2. **Painel:** no all-mdm-server, crie a tag `v5.41.1-all.1`.
3. **Imagem:** aqui, confira no `Dockerfile` se `HMDM_URL`, `AGENT_VERSION` e `AGENT_URL` apontam
   para as versões publicadas e crie a tag `v5.41.1-all.1`.
4. No GitHub, em **Packages → all-mdm**, deixe o pacote público ou faça login no ghcr.io no servidor.

## Subir no Portainer

1. **Stacks → Add stack**, cole o `docker-compose.yaml` e cadastre as variáveis do `.env.example`.
2. **Proxy reverso:** `https://mdm.alltecnologias.com.br` → `http://<host>:8800`.
3. **Porta 31000/TCP:** encaminhe direto para o host (é o push MQTT dos celulares, não passa pelo proxy HTTP).
4. Acesse o painel e entre com `admin` / `admin`. O painel obriga a troca da senha no primeiro acesso.

> **Banco já usado com a imagem da Headwind?** A carga inicial só roda em banco vazio. Como o banco
> `mdm` ainda é de teste, o mais simples é apagá-lo e criá-lo de novo antes de subir a imagem ALL,
> para que o agente ALL já venha cadastrado.

## Variáveis principais

| Variável | Padrão | Para que serve |
|---|---|---|
| `SQL_HOST`, `SQL_PORT`, `SQL_BASE`, `SQL_USER`, `SQL_PASS` | — | Banco PostgreSQL |
| `BASE_DOMAIN` | — | Domínio público do painel |
| `PROTOCOL` / `PUBLIC_PROTOCOL` | `http` / `https` (no compose) | Protocolo do Tomcat / protocolo público |
| `PROXY_ADDRESSES` | vazio | IPs do proxy, para registrar o IP real dos celulares |
| `SHARED_SECRET` | — | Segredo entre painel e agente; igual ao secret `ALL_MDM_SHARED_SECRET` do Android |
| `BRAND_NAME`, `BRAND_VENDOR`, `BRAND_LINK` | ALL MDM, ALL Tecnologias, site | Marca exibida no painel |
| `AGENT_PKG`, `AGENT_NAME`, `AGENT_VERSION`, `AGENT_URL` | agente ALL | Agente cadastrado na primeira instalação |

## Atualizar

- **Painel:** nova tag no all-mdm-server → ajuste `HMDM_URL` no `Dockerfile` → nova tag aqui →
  no Portainer, troque `IMAGE_TAG` e atualize a stack.
- **Agente:** nova tag no all-mdm-android → envie o APK em **Aplicativos → ALL MDM → Adicionar versão**
  e escolha a versão nas configurações. Os celulares atualizam sozinhos.

> Não use **Verificar atualizações** dentro do painel: ele baixa a versão original da Headwind e apaga a marca.
