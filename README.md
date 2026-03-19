# 🔥 Resume Roast — Back-end N8N

Back-end **100% stateless** em n8n para análise de currículos com GPT-4o.

---

## Arquitetura

```
POST /upload-resume  →  GPT-4o analisa PDF  →  Resultado completo  →  Armazena no n8n
                                                       ↓
                                              Front exibe resultado
                                                       ↓
                                         Usuário escolhe: Grátis ou Premium
                                                       ↓
POST /gerar-curriculo  →  Busca análise  →  GPT-4o reescreve  →  Entrega currículo novo
```

---

## Estrutura do Repositório

```
resume-roast/
├── sql/
│   └── create_table.sql                  → SQL legado (PostgreSQL) — não usado nesta versão
├── fluxos-n8n/
│   ├── fluxo1-upload-resume.json         → Importe direto no n8n
│   └── fluxo2-gerar-curriculo.json       → Importe direto no n8n
├── docs/
│   └── fluxograma.md                     → Fluxograma Mermaid + exemplos de JSON
└── README.md
```

---

## Endpoints

| Método | Path | Descrição |
|---|---|---|
| `POST` | `/upload-resume` | Recebe PDF + id, analisa com GPT-4o, retorna resultado completo |
| `POST` | `/gerar-curriculo` | Recebe resume_id, busca análise, gera currículo reescrito |

---

## Setup

### 1. Importar os Fluxos no N8N
1. N8N → **Workflows → ⋮ → Import from File**
2. Importe `fluxo1-upload-resume.json`
3. Importe `fluxo2-gerar-curriculo.json`

### 2. Configurar Credentials
- **OpenAI API Key** → usada nos dois fluxos (Files API + GPT-4o)

### 3. Configurar n8n Data Store
O fluxo usa a **tabela interna do n8n** (`n8n Training Custom Data`).  
Não precisa de banco externo. Os dados ficam dentro do próprio n8n.

> Na interface do nó, crie a tabela com o nome `resume_roasts`.

### 4. Ativar os dois workflows

---

## Fluxo 1 — Upload + Análise

**Input:** `multipart/form-data`
- `file` → PDF do currículo
- `id` → UUID gerado no front (`crypto.randomUUID()`)

**Nós:**
1. Webhook `/upload-resume`
2. Code → valida campos
3. OpenAI Files API → upload do PDF
4. GPT-4o → analisa PDF direto (mais preciso que texto extraído)
5. Code → parse JSON + monta objeto
6. n8n Data Store → INSERT
7. Respond → retorna resultado completo

---

## Fluxo 2 — Geração de Currículo Premium

**Input:** `application/json`
```json
{
  "resume_id": "uuid-do-upload",
  "target_role": "Senior Backend Engineer",   // opcional
  "target_company": "Google"                  // opcional
}
```

**Nós:**
1. Webhook `/gerar-curriculo`
2. Code → valida resume_id
3. n8n Data Store → GET análise original
4. Code → monta prompt rico com contexto + target role/company
5. GPT-4o → gera currículo reescrito completo
6. Code → parse + calcula score_improvement
7. n8n Data Store → UPDATE status=resume_generated
8. Respond → retorna currículo + skills + bullets + ATS keywords

---

## O que a IA entrega

### Fluxo 1 — Análise
| Campo | Descrição |
|---|---|
| `employability_score` | Score 0-100 de empregabilidade |
| `ats_rejection_chance` | % de rejeição por ATS |
| `hook_message` | O maior problema em uma frase |
| `brutal_roast` | Crítica direta e bem-humorada |
| `red_flags` | 3 clichês/problemas encontrados |
| `improvement_tips` | 5 dicas acionáveis e específicas |
| `rewritten_summary` | Summary otimizado para ATS |

### Fluxo 2 — Currículo Reescrito
| Campo | Descrição |
|---|---|
| `new_summary` | Summary profissional novo |
| `key_skills` | 10-15 skills relevantes |
| `experience_bullets` | Bullets no formato STAR com números |
| `certifications_suggestions` | 3 certificações recomendadas |
| `ats_keywords` | 15 keywords para otimização ATS |
| `final_score_prediction` | Score previsto após melhorias |
| `cover_letter_opening` | Abertura forte para cover letter |
| `score_improvement` | Ganho de score (final - original) |

---

## Próximos passos (módulo de pagamento)

- [ ] Adicionar campo `status_pagamento` na tabela
- [ ] Fluxo 3: Webhook do gateway (Stripe/LemonSqueezy) atualiza `status_pagamento = true`
- [ ] Fluxo 1: retorna apenas `teaser_gratis` (bloqueia `brutal_roast` + `improvement_tips`)
- [ ] Fluxo 2: verificar `status_pagamento` antes de gerar o currículo
