CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- D1: Citizen / User Accounts
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nik_hash VARCHAR(64) NOT NULL UNIQUE,
    full_name VARCHAR(150) NOT NULL,
    phone_number VARCHAR(20),
    preferred_locale VARCHAR(10) NOT NULL DEFAULT 'id-ID',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- D2: OCR Document Verification Records
CREATE TABLE IF NOT EXISTS document_verifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    doc_type VARCHAR(20) NOT NULL CHECK (doc_type IN ('KTP', 'SIM', 'STNK', 'KK')),
    ocr_confidence NUMERIC(5,2) CHECK (ocr_confidence >= 0 AND ocr_confidence <= 100),
    liveness_score NUMERIC(5,2) CHECK (liveness_score >= 0 AND liveness_score <= 100),
    verification_status VARCHAR(25) NOT NULL DEFAULT 'PENDING'
        CHECK (verification_status IN ('PENDING', 'VERIFIED', 'FLAGGED', 'REJECTED')),
    external_ref_status VARCHAR(50),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- D3: Multimodal Incident Reports & Triage
CREATE TABLE IF NOT EXISTS incident_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    raw_text TEXT,
    transcript_text TEXT,
    detected_language VARCHAR(15),
    cross_modal_score NUMERIC(5,2),
    priority_score NUMERIC(4,2) CHECK (priority_score >= 1.0 AND priority_score <= 10.0),
    latitude NUMERIC(9,6),
    longitude NUMERIC(9,6),
    triage_status VARCHAR(25) NOT NULL DEFAULT 'QUEUED'
        CHECK (triage_status IN ('QUEUED', 'FLAG_REVIEW', 'DISPATCHED', 'RESOLVED')),
    assigned_unit VARCHAR(100),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Attached Multimodal Evidence (Images, Video, Audio)
CREATE TABLE IF NOT EXISTS report_attachments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    report_id UUID NOT NULL REFERENCES incident_reports(id) ON DELETE CASCADE,
    modality VARCHAR(15) NOT NULL CHECK (modality IN ('IMAGE', 'VIDEO', 'AUDIO')),
    storage_uri TEXT NOT NULL,
    mime_type VARCHAR(50) NOT NULL,
    file_size_bytes BIGINT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_reports_priority_status
    ON incident_reports (priority_score DESC, triage_status);

CREATE INDEX IF NOT EXISTS idx_reports_created_at
    ON incident_reports (created_at DESC);

CREATE INDEX IF NOT EXISTS idx_doc_verifications_user_id
    ON document_verifications (user_id);

CREATE INDEX IF NOT EXISTS idx_report_attachments_report_id
    ON report_attachments (report_id);
