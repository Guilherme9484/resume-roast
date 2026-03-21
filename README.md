# Resume Roast — Back-end N8N

Back-end **100% stateless** em n8n + Postgres para análise e geração de currículos com IA (Groq qwen3-32b).

---

## Arquitetura

```
POST /upload-resume
  → Extract PDF → Groq AI Agent → Parse JSON
  → Postgres INSERT resume_roasts
  → Retorna análise completa ao front

POST /chat
  → Valida body → Postgres GET resume_roasts (contexto)
  → Groq AI Agent (memória Postgres por resume_id)
  → Parse final_resume → Postgres INSERT resume_finals
  → Retorna { done, message, curriculo }
```

---

## Estrutura do Repositório

```
resume-roast/
├── sql/
│   ├── create_table.sql           → SQL legado (arquivo histórico)
│   └── create_tables.sql          → Schema atual com resume_roasts + resume_finals + view
├── fluxos-n8n/
│   ├── fluxo1-upload-resume.json  → Fluxo 1: upload + análise → Postgres
│   ├── fluxo2-gerar-curriculo.json → Fluxo 2 (legado / referência)
│   ├── fluxo2-webhook-pagamento.json → Webhook de pagamento Pix
│   ├── fluxo3-chat-perguntas.json → Fluxo 3: chat + geração → Postgres
│   └── node-insert-resume_roasts.json → Nó de referência
├── docs/
│   └── fluxograma.md              → Fluxograma Mermaid + exemplos de JSON
└── README.md
```

---

## Banco de Dados (Postgres)

### Por que Postgres em vez de DataTable do N8N?

| | DataTable N8N | Postgres |
|---|---|---|
| Tipagem | Só `string` | `INTEGER`, `JSONB`, `TIMESTAMPTZ`, etc. |
| Relacionamentos (FK) | Não | Sim (resume_finals → resume_roasts) |
| Multi-serviço | Não | Campo `source_service` escala para N projetos |
| Performance | Limitada | Índices, views, queries complexas |
| SQL real | Não | `ON CONFLICT`, `JOIN`, `GROUP BY`, `VIEW` |

### Tabelas

**`resume_roasts`** — análise do Fluxo 1
| Coluna | Tipo | Descrição |
|---|---|---|
| `resume_id` | UUID UNIQUE | UUID gerado no front |
| `source_service` | TEXT | `'resume-roast'` (futuro: outros serviços) |
| `employability_score` | INTEGER 0-100 | Score de empregabilidade |
| `ats_rejection_chance` | INTEGER 0-100 | % de rejeição ATS |
| `hook_message` | TEXT | Frase de impacto sobre o maior problema |
| `brutal_roast` | TEXT | Crítica completa da IA |
| `red_flags` | JSONB | Array de 3 problemas |
| `improvement_tips` | JSONB | Array de 5 dicas |
| `rewritten_summary` | TEXT | Summary reescrito pela IA |
| `questions` | JSONB | Array de 10 perguntas estratégicas |
| `original_text` | TEXT | Texto extraído do PDF |
| `status` | TEXT | `pending` / `analyzed` / `pending_payment` / `paid` / `error` |

**`resume_finals`** — currículo gerado pelo Fluxo 3
| Coluna | Tipo | Descrição |
|---|---|---|
| `resume_id` | UUID UNIQUE FK | FK → resume_roasts |
| `summary` | TEXT | Summary profissional |
| `experience` | JSONB | `[{company, role, period, achievements[]}]` |
| `skills` | JSONB | Array de skills |
| `education` | JSONB | `[{institution, degree, year}]` |
| `certifications` | JSONB | Array de certificações |
| `differentials` | TEXT | Diferencial único do candidato |
| `status` | TEXT | `pending_payment` / `paid` / `cancelled` |
| `payment_id` | TEXT | ID da transação Pix |

**`vw_resume_pipeline`** — view para analytics/dashboard
```sql
SELECT resume_id, source_service, employability_score, analysis_status,
       payment_status, paid_at, submitted_at, resume_generated_at
FROM vw_resume_pipeline;
```

---

## Setup

### 1. Criar as tabelas no Postgres

```sql
-- Execute o arquivo sql/create_tables.sql no seu Postgres
\i sql/create_tables.sql
```

### 2. Importar os Fluxos no N8N

1. N8N → **Workflows → ⋮ → Import from File**
2. Importe `fluxo1-upload-resume.json`
3. Importe `fluxo3-chat-perguntas.json`

### 3. Configurar Credentials

- **Groq API** → credential ID `Zs2d3aQggFKHeg1h` (modelo: `qwen/qwen3-32b`)
- **Postgres** → credential ID `BgdlaXsBdEjEwstv` (mesmo usado pela memória do Agent)

### 4. Ativar os workflows

---

## Endpoints

| Método | Path | Descrição |
|---|---|---|
| `POST` | `/webhook/upload-resume?id={uuid}` | Recebe PDF, analisa com IA, salva no Postgres |
| `POST` | `/webhook/chat` | Chat com Agent, gera currículo, salva no Postgres |

### POST /upload-resume

**Content-Type:** `multipart/form-data`
- Query: `?id=<uuid-gerado-no-front>`
- Body: arquivo PDF no campo `file`

**Response:**
```json
{
  "resume_id": "uuid",
  "employability_score": 35,
  "ats_rejection_chance": 90,
  "hook_message": "...",
  "brutal_roast": "...",
  "red_flags": ["...", "...", "..."],
  "improvement_tips": ["...", "...", "...", "...", "..."],
  "rewritten_summary": "...",
  "questions": ["Q1", "Q2", ..., "Q10"]
}
```

### POST /chat

**Content-Type:** `application/json`
```json
{
  "resume_id": "uuid-do-upload",
  "message": "Respostas numeradas do usuário"
}
```

**Response (em andamento):**
```json
{ "resume_id": "uuid", "done": false, "message": "Próxima pergunta", "curriculo": null }
```

**Response (currículo pronto):**
```json
{
  "resume_id": "uuid",
  "done": true,
  "message": null,
  "curriculo": {
    "summary": "...",
    "experience": [{"company": "...", "role": "...", "period": "...", "achievements": ["..."]}],
    "skills": ["..."],
    "education": [{"institution": "...", "degree": "...", "year": "..."}],
    "certifications": ["..."],
    "differentials": "..."
  }
}
```

---

## Próximos passos

- [ ] Fluxo de pagamento Pix: webhook atualiza `resume_finals.status = 'paid'`
- [ ] Adicionar campo `selected_template` em `resume_finals`
- [ ] Dashboard de analytics usando `vw_resume_pipeline`
- [ ] Rate limiting por IP no webhook de upload
