-- D1: Citizen / User Accounts
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nik_hash VARCHAR(64) NOT NULL UNIQUE, -- Store hashed/tokenized NIK per UU PDP principles
    full_name VARCHAR(150) NOT NULL,
    phone_number VARCHAR(20),
    preferred_locale VARCHAR(10) DEFAULT 'id-ID', -- Supports id-ID, su-ID, jv-ID, etc.
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- D2: OCR Document Verification Records
CREATE TABLE document_verifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    doc_type VARCHAR(20) NOT NULL CHECK (doc_type IN ('KTP', 'SIM', 'STNK', 'KK')),
    ocr_confidence NUMERIC(5,2) CHECK (ocr_confidence >= 0 AND ocr_confidence <= 100),
    liveness_score NUMERIC(5,2) CHECK (liveness_score >= 0 AND liveness_score <= 100),
    verification_status VARCHAR(25) NOT NULL DEFAULT 'PENDING', -- PENDING, VERIFIED, FLAGGED, REJECTED
    external_ref_status VARCHAR(50), -- Dukcapil / Korlantas check summary
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- D3: Multimodal Incident Reports & Triage
CREATE TABLE incident_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    raw_text TEXT,
    transcript_text TEXT,          -- Output from STT (incl. regional dialects)
    detected_language VARCHAR(15),
    cross_modal_score NUMERIC(5,2), -- Alignment score between text & visual/audio evidence
    priority_score NUMERIC(4,2) CHECK (priority_score >= 1.0 AND priority_score <= 10.0),
    latitude NUMERIC(9,6),
    longitude NUMERIC(9,6),
    triage_status VARCHAR(25) NOT NULL DEFAULT 'QUEUED', -- QUEUED, FLAG_REVIEW, DISPATCHED, RESOLVED
    assigned_unit VARCHAR(100),    -- Target Polres / Polda / Command Center
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Attached Multimodal Evidence (Images, Video, Audio)
CREATE TABLE report_attachments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    report_id UUID NOT NULL REFERENCES incident_reports(id) ON DELETE CASCADE,
    modality VARCHAR(15) NOT NULL CHECK (modality IN ('IMAGE', 'VIDEO', 'AUDIO')),
    storage_uri TEXT NOT NULL,
    mime_type VARCHAR(50) NOT NULL,
    file_size_bytes BIGINT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_reports_priority_status ON incident_reports (priority_score DESC, triage_status);
CREATE INDEX idx_reports_created_at ON incident_reports (created_at DESC);
