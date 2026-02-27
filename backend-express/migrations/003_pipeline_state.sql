-- Pipeline state table for tracking document processing progress
-- Enables persistence across server restarts and provides audit trail
-- for document pipeline execution.
--
-- The in-memory Map remains the primary store for active pipelines;
-- this table is the recovery mechanism for server restarts.

CREATE TABLE IF NOT EXISTS pipeline_state (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  document_id text NOT NULL,
  user_id text NOT NULL,
  document_type text,
  file_name text,
  status text NOT NULL DEFAULT 'uploaded',
  steps jsonb DEFAULT '{}',
  extracted_text text,
  classification_results jsonb,
  analysis_results jsonb,
  case_id uuid REFERENCES case_files(id) ON DELETE SET NULL,
  error jsonb,
  retry_count integer DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Look up pipeline by document_id (primary access pattern)
CREATE INDEX IF NOT EXISTS idx_pipeline_state_document ON pipeline_state(document_id);

-- Filter pipelines by user and status (dashboard queries)
CREATE INDEX IF NOT EXISTS idx_pipeline_state_user_status ON pipeline_state(user_id, status);

-- Trigger to auto-update updated_at on row modification
-- (reuses the trigger function created in 002_case_files_and_classifications.sql)
CREATE TRIGGER set_pipeline_state_updated_at
  BEFORE UPDATE ON pipeline_state
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();
