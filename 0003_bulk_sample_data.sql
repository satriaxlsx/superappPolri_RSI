BEGIN;

-- 1. Insert 30 users (D1)
WITH locales AS (
    SELECT ARRAY['id-ID', 'su-ID', 'jv-ID']::text[] AS arr
),
first_names AS (
    SELECT ARRAY[
        'Budi', 'Siti', 'Agus', 'Dewi', 'Rizky', 'Ayu', 'Dimas', 'Putri', 'Hendra', 'Nadia',
        'Fajar', 'Ratna', 'Yusuf', 'Lestari', 'Bagus', 'Indah', 'Wahyu', 'Tari', 'Raka', 'Melati',
        'Dian', 'Arif', 'Sari', 'Gilang', 'Wulan', 'Teguh', 'Fitri', 'Aldi', 'Intan', 'Bayu'
    ]::text[] AS arr
),
last_names AS (
    SELECT ARRAY[
        'Santoso', 'Wijaya', 'Pratama', 'Kusuma', 'Hidayat', 'Nugroho', 'Setiawan', 'Rahmawati', 'Permana', 'Saputra'
    ]::text[] AS arr
),
inserted_users AS (
    INSERT INTO users (nik_hash, full_name, phone_number, preferred_locale)
    SELECT
        encode(digest(format('327301230490%04s', g), 'sha256'), 'hex'),
        fn.arr[1 + ((g - 1) % array_length(fn.arr, 1))] || ' ' || ln.arr[1 + ((g * 3 - 1) % array_length(ln.arr, 1))],
        format('+62812%08s', 10000000 + g),
        loc.arr[1 + ((g - 1) % array_length(loc.arr, 1))]
    FROM generate_series(1, 30) AS g
    CROSS JOIN locales loc
    CROSS JOIN first_names fn
    CROSS JOIN last_names ln
    ON CONFLICT (nik_hash) DO UPDATE
        SET preferred_locale = EXCLUDED.preferred_locale
    RETURNING id, preferred_locale
),
ranked_users AS (
    SELECT
        id,
        preferred_locale,
        ROW_NUMBER() OVER (ORDER BY id) AS rn
    FROM inserted_users
),

-- 2. Insert 30 document verifications (D2) - 1 per user
doc_types AS (
    SELECT ARRAY['KTP', 'SIM', 'STNK', 'KK']::text[] AS arr
),
doc_statuses AS (
    SELECT ARRAY['VERIFIED', 'VERIFIED', 'PENDING', 'FLAGGED']::text[] AS arr
),
inserted_docs AS (
    INSERT INTO document_verifications (
        user_id,
        doc_type,
        ocr_confidence,
        liveness_score,
        verification_status,
        external_ref_status
    )
    SELECT
        ru.id,
        dt.arr[1 + ((ru.rn - 1) % array_length(dt.arr, 1))],
        round((75.0 + random() * 24.5)::numeric, 2),
        round((70.0 + random() * 29.5)::numeric, 2),
        ds.arr[1 + ((ru.rn - 1) % array_length(ds.arr, 1))],
        CASE
            WHEN (ru.rn % 5) = 0 THEN 'DUKCAPIL_PENDING'
            ELSE 'DUKCAPIL_MATCH'
        END
    FROM ranked_users ru
    CROSS JOIN doc_types dt
    CROSS JOIN doc_statuses ds
    RETURNING id, user_id
),

-- 3. Insert 30 multimodal incident reports (D3) - 1 per user
triage_statuses AS (
    SELECT ARRAY['QUEUED', 'DISPATCHED', 'FLAG_REVIEW', 'RESOLVED']::text[] AS arr
),
units AS (
    SELECT ARRAY[
        'Polres Bandung - Unit Gakkum',
        'Polresta Bandung - SPKT',
        'Polda Jabar - Command Center',
        'Polsek Bojongsoang - Patroli'
    ]::text[] AS arr
),
inserted_reports AS (
    INSERT INTO incident_reports (
        user_id,
        raw_text,
        transcript_text,
        detected_language,
        cross_modal_score,
        priority_score,
        latitude,
        longitude,
        triage_status,
        assigned_unit
    )
    SELECT
        ru.id,
        format('Laporan insiden #%s: kepadatan lalu lintas dan kondisi jalan di titik pantau.', ru.rn),
        CASE ru.preferred_locale
            WHEN 'su-ID' THEN format('Laporkeun kajadian ka-%s di jalan utama, peryogi perhatian.', ru.rn)
            WHEN 'jv-ID' THEN format('Kula nglaporaken kedadean nomer %s wonten margi ageng.', ru.rn)
            ELSE format('Melaporkan kejadian nomor %s di area sekitar.', ru.rn)
        END,
        ru.preferred_locale,
        round((55.0 + random() * 44.0)::numeric, 2),
        round((2.0 + random() * 7.8)::numeric, 2),
        round((-6.995000 + (random() * 0.040000))::numeric, 6),
        round((107.610000 + (random() * 0.045000))::numeric, 6),
        ts.arr[1 + ((ru.rn - 1) % array_length(ts.arr, 1))],
        u.arr[1 + ((ru.rn - 1) % array_length(u.arr, 1))]
    FROM ranked_users ru
    CROSS JOIN triage_statuses ts
    CROSS JOIN units u
    RETURNING id
),
ranked_reports AS (
    SELECT
        id,
        ROW_NUMBER() OVER (ORDER BY id) AS rn
    FROM inserted_reports
)

-- 4. Insert 30 report attachments - 1 per report
INSERT INTO report_attachments (
    report_id,
    modality,
    storage_uri,
    mime_type,
    file_size_bytes
)
SELECT
    rr.id,
    CASE (rr.rn % 3)
        WHEN 1 THEN 'IMAGE'
        WHEN 2 THEN 'AUDIO'
        ELSE 'VIDEO'
    END,
    CASE (rr.rn % 3)
        WHEN 1 THEN format('s3://polri-evidence-dev/reports/ev-%02s.jpg', rr.rn)
        WHEN 2 THEN format('s3://polri-evidence-dev/reports/voice-%02s.wav', rr.rn)
        ELSE format('s3://polri-evidence-dev/reports/clip-%02s.mp4', rr.rn)
    END,
    CASE (rr.rn % 3)
        WHEN 1 THEN 'image/jpeg'
        WHEN 2 THEN 'audio/wav'
        ELSE 'video/mp4'
    END,
    (250000 + (rr.rn * 125000))::bigint
FROM ranked_reports rr;

COMMIT;
