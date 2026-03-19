# 🔥 Resume Roast — Back-end N8N

Back-end **100% stateless** para o produto Resume Roast.  
O n8n processa o currículo, guarda no banco bloqueado e só libera quando o webhook do pagamento confirmar.

---

## Estrutura do Repositório

```
resume-roast/
├── sql/
│   └── create_table.sql         → SQL da tabela no PostgreSQL
├── fluxos-n8n/
│   ├── fluxo1-upload-resume.json   → Importe direto no n8n
│   └── fluxo2-webhook-pagamento.json → Importe direto no n8n
├── docs/
│   └── fluxograma.md            → Fluxograma completo (Mermaid)
└── README.md
```

---

## Setup Rápido

### 1. Banco de Dados (PostgreSQL — Portainer)
```bash
psql -U seu_usuario -d sua_database -f sql/create_table.sql
```

### 2. Importar os Fluxos no N8N
1. Acesse seu n8n → **Workflows → Import from File**
2. Importe `fluxo1-upload-resume.json`
3. Importe `fluxo2-webhook-pagamento.json`
4. Configure as credentials:
   - **OpenAI** → sua API Key
   - **Postgres** → host/user/pass do seu banco no Portainer
5. Ative ambos os workflows

### 3. Metadados no Checkout (crítico)
Quando criar o link de pagamento no gateway, passe o `id` do currículo:

**Stripe:**
```js
metadata: { resume_id: id }
```

**LemonSqueezy:**
```js
custom_data: { resume_id: id }
```

**Mercado Pago:**
```js
external_reference: id
```

---

## Endpoints

| Método | Path | Descrição |
|---|---|---|
| `POST` | `/upload-resume` | Recebe PDF + id, processa e retorna teaser |
| `POST` | `/webhook-pagamento` | Recebe ping do gateway, libera resultado no banco |

---

## Fluxograma

Veja [docs/fluxograma.md](docs/fluxograma.md) para o fluxograma completo com Mermaid.

---

## Tabela: `resume_roasts`

| Campo | Tipo | Descrição |
|---|---|---|
| `id` | VARCHAR(36) PK | UUID gerado no front-end |
| `status_pagamento` | BOOLEAN | `false` até o pagamento confirmar |
| `teaser_gratis` | JSONB | Score, % rejeição, hook message |
| `resultado_completo` | JSONB | Roast brutal + currículo reescrito |
| `created_at` | TIMESTAMPTZ | Data de criação |
| `updated_at` | TIMESTAMPTZ | Atualizado no webhook de pagamento |
