# Resume Roast - Fluxograma do Back-end

## Visão Geral

```mermaid
flowchart TD
    subgraph FRONT["🖥️ FRONT-END"]
        A([Usuário faz upload\ndo PDF]) --> B[Gera UUID no front\nid = crypto.randomUUID]
        B --> C[POST /upload-resume\nmultipart: file + id]
    end

    subgraph FLUXO1["⚙️ N8N - FLUXO 1: Processamento"]
        D[Webhook\nPOST /upload-resume] --> E[Extract from File\nPDF → Texto Puro]
        E --> F[OpenAI gpt-4o-mini\nRetorna JSON estrito]
        F --> G[(Postgres INSERT\nresume_roasts\nstatus_pagamento = FALSE)]
        G --> H[Respond to Webhook\nRetorna SOMENTE\nteaser_gratis]
    end

    subgraph BANCO["🗄️ BANCO DE DADOS"]
        I[(Tabela: resume_roasts\n─────────────────\nid VARCHAR PK\nstatus_pagamento BOOLEAN\nteaser_gratis JSONB\nresultado_completo JSONB\ncreated_at / updated_at)]
    end

    subgraph PAGAMENTO["💳 GATEWAY DE PAGAMENTO"]
        J[Stripe / LemonSqueezy\nMercado Pago] --> K[POST /webhook-pagamento\nmetadata.resume_id = id]
    end

    subgraph FLUXO2["⚙️ N8N - FLUXO 2: Liberação"]
        L[Webhook\nPOST /webhook-pagamento] --> M[(Postgres UPDATE\nstatus_pagamento = TRUE\nWHERE id = resume_id)]
        M --> N[Respond 200 OK\npara o gateway]
    end

    subgraph RESULTADO["🔓 FRONT-END - Desbloqueio"]
        O[GET /resultado/:id\nVerifica status_pagamento] --> P{status_pagamento\n= TRUE?}
        P -- SIM --> Q[Exibe resultado_completo\nBrutal Roast + Currículo Reescrito]
        P -- NÃO --> R[Redireciona para\nCheckout]
    end

    C --> D
    H --> |teaser_gratis| FRONT
    G --> |grava| BANCO
    K --> L
    M --> |atualiza| BANCO
    FRONT --> |clica em Pagar| J
```

---

## Fluxo 1 — Detalhado

```mermaid
sequenceDiagram
    participant FE as Front-end
    participant WH as Webhook n8n
    participant PDF as Extract PDF
    participant AI as OpenAI
    participant DB as PostgreSQL

    FE->>WH: POST /upload-resume (multipart: file, id)
    WH->>PDF: Passa binário do PDF
    PDF->>AI: Texto extraído do PDF
    AI->>AI: Processa prompt + gera JSON
    AI->>DB: INSERT resume_roasts (id, teaser, resultado, status=FALSE)
    DB-->>AI: OK
    AI-->>WH: teaser_gratis JSON
    WH-->>FE: HTTP 200 { employability_score, ats_rejection_chance, hook_message }
```

---

## Fluxo 2 — Detalhado

```mermaid
sequenceDiagram
    participant GW as Gateway (Stripe/etc)
    participant WH as Webhook n8n
    participant DB as PostgreSQL
    participant FE as Front-end

    GW->>WH: POST /webhook-pagamento (metadata.resume_id = id)
    WH->>DB: UPDATE resume_roasts SET status_pagamento=TRUE WHERE id=resume_id
    DB-->>WH: OK
    WH-->>GW: HTTP 200 { ok: true }
    FE->>DB: GET /resultado/:id (verifica status_pagamento)
    DB-->>FE: resultado_completo desbloqueado
```

---

## Estrutura do Banco

```mermaid
erDiagram
    RESUME_ROASTS {
        varchar id PK "UUID gerado no front"
        boolean status_pagamento "DEFAULT false"
        jsonb teaser_gratis "isca gratuita"
        jsonb resultado_completo "roast bloqueado"
        timestamptz created_at
        timestamptz updated_at
    }
```

---

## JSON esperado da IA

### `teaser_gratis`
```json
{
  "employability_score": "34/100",
  "ats_rejection_chance": "91%",
  "hook_message": "There is a catastrophic error in your resume that guarantees automatic rejection by 9 out of 10 ATS systems."
}
```

### `resultado_completo`
```json
{
  "brutal_roast": "Your resume looks like it was written by someone who Googled 'how to write a resume' in 2009 and never looked back...",
  "red_flags": ["results-driven", "team player", "synergy"],
  "rewritten_summary": "Senior Software Engineer with 6+ years building scalable distributed systems..."
}
```

---

## Metadados por Gateway

| Gateway | Campo no payload | Path no n8n |
|---|---|---|
| **Stripe** | `metadata.resume_id` | `$json.body.data.object.metadata.resume_id` |
| **LemonSqueezy** | `custom_data.resume_id` | `$json.body.meta.custom_data.resume_id` |
| **Mercado Pago** | `external_reference` | `$json.body.external_reference` |
