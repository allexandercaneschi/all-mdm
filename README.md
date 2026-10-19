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

## Versões

Cada repositório tem um arquivo `ALL_VERSION`. Para lançar uma versão, altere esse arquivo e faça push
na branch `all/main`: o GitHub Actions compila, cria a tag e publica sozinho.

| Repositório | `ALL_VERSION` atual | Publica |
|---|---|---|
| all-mdm-server | `5.41.1-all.1` | `all-mdm-5.41.1-all.1.war` no Releases |
| all-mdm-android | `6.40-all.1` | `all-mdm-agent-6.40-all.1.apk` no Releases (precisa dos secrets da chave) |
| all-mdm (este) | `5.41.1-all.1` | imagem `ghcr.io/allexandercaneschi/all-mdm:5.41.1-all.1` e `:latest` |

Todo push na `all/main` também publica a imagem `:main`, que sempre acompanha a branch (para teste).
Para produção, use a versão fechada (`:5.41.1-all.1`) ou `:latest` (última versão publicada).
No `Dockerfile`, `HMDM_URL`, `AGENT_VERSION` e `AGENT_URL` apontam para as versões publicadas dos outros dois.

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
| `ADMIN_EMAIL` | — | E-mail do usuário `admin` (recuperação de senha) |
| `SMTP_HOST`, `SMTP_PORT`, `SMTP_SSL`, `SMTP_STARTTLS`, `SMTP_USER`, `SMTP_PASS`, `SMTP_FROM` | porta 465 com SSL | Envio de e-mail. `SMTP_PASS` só no Portainer/.env, nunca no repositório |
| `BRAND_NAME`, `BRAND_VENDOR`, `BRAND_LINK` | ALL MDM, ALL Tecnologias, site | Marca exibida no painel |
| `AGENT_PKG`, `AGENT_NAME`, `AGENT_VERSION`, `AGENT_URL` | agente ALL | Agente cadastrado na primeira instalação |

## Atualizar

- **Painel:** suba o `ALL_VERSION` do all-mdm-server → aqui, ajuste `HMDM_URL` no `Dockerfile` e suba o
  `ALL_VERSION` → no Portainer, **Pull and redeploy** da stack (ou troque `IMAGE_TAG`).
- **Agente:** suba o `ALL_VERSION` do all-mdm-android → envie o APK em **Aplicativos → ALL MDM → Adicionar versão**
  e escolha a versão nas configurações. Os celulares atualizam sozinhos.

> Não use **Verificar atualizações** dentro do painel: ele baixa a versão original da Headwind e apaga a marca.
