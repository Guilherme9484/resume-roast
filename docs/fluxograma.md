# Resume Roast - Fluxograma

## Visão Geral do Sistema

```mermaid
flowchart TD
    subgraph FRONT["🖥️ FRONT-END"]
        A([Usuário faz upload do PDF]) --> B[Gera UUID\ncrypto.randomUUID]
        B --> C[POST /upload-resume\nmultipart: file + id]
    end

    subgraph FLUXO1["⚙️ N8N - FLUXO 1: Análise Completa"]
        D[Webhook\nPOST /upload-resume] --> E[Code\nValida id + binário]
        E --> F[OpenAI Files API\nUpload do PDF]
        F --> G[GPT-4o\nAnalisa PDF direto\nRetorna JSON completo]
        G --> H[Code\nParse + Monta objeto]
        H --> I[(n8n Data Store\nINSERT resume_roasts\nstatus = analyzed)]
        I --> J[Respond 200\nResultado COMPLETO]
    end

    subgraph RESULTADO["📊 FRONT-END - Exibe Resultado"]
        K[Mostra Score\nRoast + Red Flags\nImprovement Tips] --> L{Usuário escolhe}
        L -- Grátis --> M[Exibe improvement_tips\nJá incluído na resposta]
        L -- Premium --> N[POST /gerar-curriculo\nresume_id + target_role]
    end

    subgraph FLUXO2["⚙️ N8N - FLUXO 2: Currículo Premium"]
        O[Webhook\nPOST /gerar-curriculo] --> P[Code\nValida resume_id]
        P --> Q[(n8n Data Store\nGET resume_roasts\nWHERE resume_id)]
        Q --> R[Code\nMonta prompt rico\ncom contexto original]
        R --> S[GPT-4o\nGera currículo reescrito\nnovo summary + skills + bullets]
        S --> T[Code\nParse + calcula\nscore_improvement]
        T --> U[(n8n Data Store\nUPDATE resume_roasts\nstatus = resume_generated)]
        U --> V[Respond 200\nCurrículo Completo]
    end

    C --> D
    J --> |resultado completo| RESULTADO
    N --> O
    V --> |currículo reescrito| FRONT
```

---

## Fluxo 1 — Sequência Detalhada

```mermaid
sequenceDiagram
    participant FE as Front-end
    participant WH as Webhook n8n
    participant OA as OpenAI Files API
    participant GPT as GPT-4o
    participant DS as n8n Data Store

    FE->>WH: POST /upload-resume (multipart: file, id)
    WH->>WH: Code - valida id + extrai binário
    WH->>OA: Upload PDF binário
    OA-->>WH: file_id
    WH->>GPT: Chat Completion (file_id + prompt)
    GPT-->>WH: JSON { employability_score, brutal_roast, red_flags, improvement_tips, rewritten_summary... }
    WH->>WH: Code - parse JSON + monta objeto
    WH->>DS: INSERT resume_roasts (resume_id, todos os campos, status=analyzed)
    DS-->>WH: OK
    WH-->>FE: HTTP 200 - Resultado completo
```

---

## Fluxo 2 — Sequência Detalhada

```mermaid
sequenceDiagram
    participant FE as Front-end
    participant WH as Webhook n8n
    participant DS as n8n Data Store
    participant GPT as GPT-4o

    FE->>WH: POST /gerar-curriculo { resume_id, target_role?, target_company? }
    WH->>WH: Code - valida resume_id
    WH->>DS: GET resume_roasts WHERE resume_id = id
    DS-->>WH: Dados da análise original
    WH->>WH: Code - monta prompt com contexto + target role
    WH->>GPT: Chat Completion (prompt rico com análise original)
    GPT-->>WH: JSON { new_summary, key_skills, experience_bullets, ats_keywords, cover_letter_opening... }
    WH->>WH: Code - parse + calcula score_improvement
    WH->>DS: UPDATE resume_roasts SET new_resume_generated=true, status=resume_generated
    DS-->>WH: OK
    WH-->>FE: HTTP 200 - Currículo reescrito completo
```

---

## Tabela interna n8n: `resume_roasts`

### Campos criados pelo Fluxo 1

| Campo | Tipo | Descrição |
|---|---|---|
| `resume_id` | String | UUID gerado no front-end (chave de busca) |
| `employability_score` | Number | Score 0-100 |
| `ats_rejection_chance` | Number | % de rejeição por ATS |
| `hook_message` | String | Frase do maior problema encontrado |
| `brutal_roast` | String | Parágrafo de crítica |
| `red_flags` | JSON String | Array de 3 clichês/problemas |
| `improvement_tips` | JSON String | Array de 5 dicas acionáveis |
| `rewritten_summary` | String | Summary otimizado |
| `status` | String | `analyzed` |
| `created_at` | String | ISO timestamp |

### Campos adicionados pelo Fluxo 2

| Campo | Tipo | Descrição |
|---|---|---|
| `new_resume_generated` | Boolean | `true` quando o Fluxo 2 rodar |
| `new_summary` | String | Novo summary gerado |
| `key_skills` | JSON String | Array de 10-15 skills |
| `experience_bullets` | JSON String | Array de bullets STAR com números |
| `ats_keywords` | JSON String | Array de 15 keywords para ATS |
| `final_score_prediction` | Number | Score previsto após melhorias |
| `cover_letter_opening` | String | Abertura da cover letter |
| `status` | String | `resume_generated` |

---

## JSON de Resposta por Endpoint

### `POST /upload-resume` → Resposta

```json
{
  "resume_id": "550e8400-e29b-41d4-a716-446655440000",
  "employability_score": 34,
  "ats_rejection_chance": 91,
  "hook_message": "Your resume has a formatting issue that causes automatic rejection by 9 out of 10 ATS systems.",
  "brutal_roast": "This resume reads like it was written by someone who Googled 'resume template 2009' and never looked back...",
  "red_flags": ["results-driven", "team player", "passionate about synergy"],
  "improvement_tips": [
    "Replace buzzwords with specific achievements and numbers",
    "Add a measurable impact to every bullet point",
    "Remove the Objective section and replace with a strong Summary",
    "List your tech stack in a dedicated Skills section",
    "Use reverse chronological order consistently"
  ],
  "rewritten_summary": "Senior Software Engineer with 6+ years building scalable APIs and distributed systems..."
}
```

### `POST /gerar-curriculo` → Resposta

```json
{
  "resume_id": "550e8400-e29b-41d4-a716-446655440000",
  "original_score": 34,
  "final_score_prediction": 87,
  "score_improvement": 53,
  "new_summary": "Senior Backend Engineer with 6+ years building high-performance REST APIs...",
  "key_skills": ["Node.js", "TypeScript", "PostgreSQL", "Docker", "AWS", "Redis", "..."],
  "experience_bullets": [
    "Reduced API response time by 40% by implementing Redis caching layer",
    "Led migration of monolith to microservices serving 50k+ daily users",
    "..."
  ],
  "certifications_suggestions": ["AWS Solutions Architect", "CKA - Kubernetes", "MongoDB Developer"],
  "ats_keywords": ["REST API", "microservices", "CI/CD", "Docker", "Kubernetes", "..."],
  "cover_letter_opening": "With 6+ years architecting backend systems that have scaled to handle millions of requests...",
  "generated_at": "2026-03-19T22:21:00.000Z"
}
```
