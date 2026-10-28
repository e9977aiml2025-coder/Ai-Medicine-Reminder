ALTER TABLE patients ADD COLUMN IF NOT EXISTS sms_opt_in boolean NOT NULL DEFAULT false;
ALTER TABLE reminders ADD COLUMN IF NOT EXISTS timezone text NOT NULL DEFAULT 'Asia/Kolkata';
CREATE TABLE IF NOT EXISTS sms_logs (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 user_id text NOT NULL,
 reminder_id uuid REFERENCES reminders(id) ON DELETE CASCADE,
 patient_id uuid REFERENCES patients(id) ON DELETE CASCADE,
 phone text,
 message text NOT NULL,
 status text NOT NULL DEFAULT 'pending',
 provider_sid text,
 error_message text,
 sent_at timestamptz,
 created_at timestamptz NOT NULL DEFAULT now()
);