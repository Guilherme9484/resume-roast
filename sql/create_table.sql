-- ============================================================
-- Resume Roast - Tabela Principal
-- Banco: PostgreSQL (Portainer)
-- ============================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE resume_roasts (
  id                 VARCHAR(36)   PRIMARY KEY,         -- UUID gerado no Front-end
  status_pagamento   BOOLEAN       NOT NULL DEFAULT FALSE,
  teaser_gratis      JSONB,                             -- { employability_score, ats_rejection_chance, hook_message }
  resultado_completo JSONB,                             -- { brutal_roast, red_flags[], rewritten_summary }
  created_at         TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at         TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

-- Índice para lookup rápido no webhook de pagamento
CREATE INDEX idx_resume_roasts_id ON resume_roasts(id);

-- ============================================================
-- Estrutura teaser_gratis (JSONB):
-- {
--   "employability_score": "42/100",
--   "ats_rejection_chance": "87%",
--   "hook_message": "There is a catastrophic error that will get you rejected instantly."
-- }
--
-- Estrutura resultado_completo (JSONB):
-- {
--   "brutal_roast": "Your resume reads like a template nobody wants...",
--   "red_flags": ["results-driven", "team player", "synergy"],
--   "rewritten_summary": "Senior Software Engineer with 5+ years..."
-- }
-- ============================================================
