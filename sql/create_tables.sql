-- ═══════════════════════════════════════════════════════════════
-- Resume Roast — Schema PostgreSQL
-- Substitui os DataTables do N8N por Postgres real
-- Arquitetura: multi-serviço (campo source_service para escalar)
-- ═══════════════════════════════════════════════════════════════

-- Extensão para UUID
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ───────────────────────────────────────────────────────────────
-- TABELA 1: resume_roasts
-- Armazena a análise gerada pelo Fluxo 1 (/upload-resume)
-- ───────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS resume_roasts (
  id                  SERIAL PRIMARY KEY,
  resume_id           UUID        NOT NULL UNIQUE,          -- UUID gerado no front-end
  source_service      TEXT        NOT NULL DEFAULT 'resume-roast',  -- escalabilidade multi-serviço

  -- Campos da análise
  employability_score INTEGER     CHECK (employability_score BETWEEN 0 AND 100),
  ats_rejection_chance INTEGER    CHECK (ats_rejection_chance BETWEEN 0 AND 100),
  hook_message        TEXT,
  brutal_roast        TEXT,
  red_flags           JSONB       DEFAULT '[]',             -- array de strings
  improvement_tips    JSONB       DEFAULT '[]',             -- array de strings
  rewritten_summary   TEXT,
  questions           JSONB       DEFAULT '[]',             -- array de 10 perguntas
  original_text       TEXT,                                 -- texto extraído do PDF

  -- Status do fluxo
  status              TEXT        NOT NULL DEFAULT 'pending'
                      CHECK (status IN ('pending', 'analyzed', 'pending_payment', 'paid', 'error')),

  -- Timestamps
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Índices para buscas frequentes
CREATE INDEX IF NOT EXISTS idx_resume_roasts_resume_id    ON resume_roasts (resume_id);
CREATE INDEX IF NOT EXISTS idx_resume_roasts_status       ON resume_roasts (status);
CREATE INDEX IF NOT EXISTS idx_resume_roasts_source       ON resume_roasts (source_service);
CREATE INDEX IF NOT EXISTS idx_resume_roasts_created_at   ON resume_roasts (created_at DESC);

-- Trigger: updated_at automático
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_resume_roasts_updated_at
  BEFORE UPDATE ON resume_roasts
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ───────────────────────────────────────────────────────────────
-- TABELA 2: resume_finals
-- Armazena o currículo gerado pelo Fluxo 3 (/chat)
-- Relacionada com resume_roasts via resume_id
-- ───────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS resume_finals (
  id                  SERIAL PRIMARY KEY,
  resume_id           UUID        NOT NULL UNIQUE,
  source_service      TEXT        NOT NULL DEFAULT 'resume-roast',

  -- Currículo gerado
  summary             TEXT,
  experience          JSONB       DEFAULT '[]',   -- [{company, role, period, achievements[]}]
  skills              JSONB       DEFAULT '[]',   -- array de strings
  education           JSONB       DEFAULT '[]',   -- [{institution, degree, year}]
  certifications      JSONB       DEFAULT '[]',   -- array de strings
  differentials       TEXT,

  -- Metadados de pagamento
  status              TEXT        NOT NULL DEFAULT 'pending_payment'
                      CHECK (status IN ('pending_payment', 'paid', 'cancelled', 'error')),
  payment_id          TEXT,                       -- ID da transação Pix/gateway
  paid_at             TIMESTAMPTZ,

  -- Timestamps
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- FK para resume_roasts
  CONSTRAINT fk_resume_finals_roast
    FOREIGN KEY (resume_id) REFERENCES resume_roasts (resume_id)
    ON DELETE CASCADE
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_resume_finals_resume_id  ON resume_finals (resume_id);
CREATE INDEX IF NOT EXISTS idx_resume_finals_status     ON resume_finals (status);
CREATE INDEX IF NOT EXISTS idx_resume_finals_source     ON resume_finals (source_service);

CREATE TRIGGER trg_resume_finals_updated_at
  BEFORE UPDATE ON resume_finals
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ───────────────────────────────────────────────────────────────
-- VIEW: dashboard rápido (útil para analytics futuros)
-- ───────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW vw_resume_pipeline AS
SELECT
  r.resume_id,
  r.source_service,
  r.employability_score,
  r.ats_rejection_chance,
  r.status                        AS analysis_status,
  f.status                        AS payment_status,
  f.paid_at,
  r.created_at                    AS submitted_at,
  f.created_at                    AS resume_generated_at
FROM resume_roasts r
LEFT JOIN resume_finals f USING (resume_id)
ORDER BY r.created_at DESC;
