-- +goose Up
-- +goose StatementBegin

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================
-- ENUMS
-- ============================================================
CREATE TYPE user_role         AS ENUM ('admin', 'teacher', 'student');
CREATE TYPE gender            AS ENUM ('male', 'female', 'other');
CREATE TYPE attendance_status AS ENUM ('present', 'absent', 'late', 'excused');
CREATE TYPE payment_status    AS ENUM ('pending', 'paid', 'partial', 'overdue');
CREATE TYPE payment_method    AS ENUM ('cash', 'bank_transfer', 'card', 'mobile_money');
CREATE TYPE leave_status      AS ENUM ('pending', 'approved', 'rejected');
CREATE TYPE session_status    AS ENUM ('active', 'expired', 'revoked');

-- ============================================================
-- ACADEMIC YEARS & TERMS
-- ============================================================
CREATE TABLE academic_years (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name        VARCHAR(20) NOT NULL UNIQUE,   -- e.g. "2024/2025"
    start_date  DATE NOT NULL,
    end_date    DATE NOT NULL,
    is_current  BOOLEAN NOT NULL DEFAULT FALSE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_year_dates CHECK (end_date > start_date)
);

CREATE TABLE terms (
    id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    academic_year_id UUID NOT NULL REFERENCES academic_years(id) ON DELETE CASCADE,
    name             VARCHAR(50) NOT NULL,   -- e.g. "First Term"
    term_number      SMALLINT NOT NULL CHECK (term_number BETWEEN 1 AND 4),
    start_date       DATE NOT NULL,
    end_date         DATE NOT NULL,
    is_current       BOOLEAN NOT NULL DEFAULT FALSE,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_term_dates CHECK (end_date > start_date),
    UNIQUE (academic_year_id, term_number)
);

-- ============================================================
-- USERS
-- ============================================================
CREATE TABLE users (
    id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email             VARCHAR(255) NOT NULL UNIQUE,
    password_hash     TEXT NOT NULL,
    role              user_role NOT NULL,
    first_name        VARCHAR(100) NOT NULL,
    last_name         VARCHAR(100) NOT NULL,
    phone             VARCHAR(30),
    gender            gender,
    date_of_birth     DATE,
    address           TEXT,
    profile_pic_url   TEXT,
    is_active         BOOLEAN NOT NULL DEFAULT TRUE,
    is_email_verified BOOLEAN NOT NULL DEFAULT FALSE,
    last_login_at     TIMESTAMPTZ,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- AUTH
-- ============================================================
CREATE TABLE user_sessions (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash  TEXT NOT NULL UNIQUE,
    ip_address  INET,
    user_agent  TEXT,
    status      session_status NOT NULL DEFAULT 'active',
    expires_at  TIMESTAMPTZ NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE password_resets (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash  TEXT NOT NULL UNIQUE,
    expires_at  TIMESTAMPTZ NOT NULL,
    used_at     TIMESTAMPTZ,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- TEACHERS
-- ============================================================
CREATE TABLE teachers (
    id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id       UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    employee_id   VARCHAR(50) UNIQUE,
    qualification VARCHAR(255),
    hire_date     DATE,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- CLASSES
-- ============================================================
CREATE TABLE classes (
    id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name             VARCHAR(50) NOT NULL,       -- e.g. "Grade 10A"
    academic_year_id UUID NOT NULL REFERENCES academic_years(id),
    class_teacher_id UUID REFERENCES teachers(id) ON DELETE SET NULL,
    room_number      VARCHAR(20),
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (name, academic_year_id)
);

-- ============================================================
-- STUDENTS
-- ============================================================
CREATE TABLE students (
    id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id          UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    student_id       VARCHAR(50) NOT NULL UNIQUE,  -- e.g. "STU-2024-001"
    class_id         UUID REFERENCES classes(id) ON DELETE SET NULL,
    academic_year_id UUID REFERENCES academic_years(id),

    -- parent/guardian (no separate login)
    parent_name      VARCHAR(200),
    parent_phone     VARCHAR(30),
    parent_email     VARCHAR(255),
    parent_relation  VARCHAR(50),   -- "Father", "Mother", "Guardian"

    admission_date   DATE,
    blood_group      VARCHAR(5),
    medical_notes    TEXT,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- SUBJECTS
-- ============================================================
CREATE TABLE subjects (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name        VARCHAR(100) NOT NULL,
    code        VARCHAR(20) NOT NULL UNIQUE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- subject assigned to a class, taught by a teacher
CREATE TABLE class_subjects (
    id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    class_id         UUID NOT NULL REFERENCES classes(id) ON DELETE CASCADE,
    subject_id       UUID NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
    teacher_id       UUID REFERENCES teachers(id) ON DELETE SET NULL,
    academic_year_id UUID NOT NULL REFERENCES academic_years(id),
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (class_id, subject_id, academic_year_id)
);

-- ============================================================
-- ATTENDANCE
-- ============================================================
CREATE TABLE attendance (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id  UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    class_id    UUID NOT NULL REFERENCES classes(id),
    term_id     UUID NOT NULL REFERENCES terms(id),
    date        DATE NOT NULL,
    status      attendance_status NOT NULL DEFAULT 'present',
    marked_by   UUID REFERENCES teachers(id),
    remarks     TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (student_id, date)
);

-- ============================================================
-- INTERNAL MARKS  (unit tests / class tests)
-- ============================================================
CREATE TABLE internal_marks (
    id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id       UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    class_subject_id UUID NOT NULL REFERENCES class_subjects(id) ON DELETE CASCADE,
    term_id          UUID NOT NULL REFERENCES terms(id),
    test_name        VARCHAR(100) NOT NULL,   -- e.g. "Unit Test 1", "Class Test 2"
    max_marks        NUMERIC(5,2) NOT NULL DEFAULT 25,
    obtained_marks   NUMERIC(5,2),
    remarks          TEXT,
    entered_by       UUID REFERENCES teachers(id),
    test_date        DATE,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_marks CHECK (obtained_marks IS NULL OR obtained_marks <= max_marks)
);

-- ============================================================
-- FINAL RESULTS  (end of term)
-- ============================================================
CREATE TABLE results (
    id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id       UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    class_subject_id UUID NOT NULL REFERENCES class_subjects(id),
    term_id          UUID NOT NULL REFERENCES terms(id),
    academic_year_id UUID NOT NULL REFERENCES academic_years(id),
    internal_total   NUMERIC(5,2),   -- sum of unit test marks
    exam_score       NUMERIC(5,2),
    total_score      NUMERIC(5,2),
    grade            VARCHAR(5),     -- "A", "B+", etc.
    position         SMALLINT,       -- rank in class for this subject
    remarks          TEXT,
    entered_by       UUID REFERENCES teachers(id),
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (student_id, class_subject_id, term_id)
);

-- ============================================================
-- FEES & PAYMENTS
-- ============================================================
CREATE TABLE fees (
    id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    academic_year_id UUID NOT NULL REFERENCES academic_years(id),
    term_id          UUID REFERENCES terms(id),  -- NULL = full-year fee
    name             VARCHAR(200) NOT NULL,
    amount           NUMERIC(12,2) NOT NULL,
    due_date         DATE,
    description      TEXT,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE student_fees (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id  UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    fee_id      UUID NOT NULL REFERENCES fees(id) ON DELETE CASCADE,
    amount_due  NUMERIC(12,2) NOT NULL,
    amount_paid NUMERIC(12,2) NOT NULL DEFAULT 0,
    status      payment_status NOT NULL DEFAULT 'pending',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (student_id, fee_id)
);

CREATE TABLE payments (
    id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_fee_id UUID NOT NULL REFERENCES student_fees(id) ON DELETE CASCADE,
    student_id     UUID NOT NULL REFERENCES students(id),
    amount         NUMERIC(12,2) NOT NULL CHECK (amount > 0),
    method         payment_method NOT NULL,
    payment_date   DATE NOT NULL DEFAULT CURRENT_DATE,
    reference_no   VARCHAR(100),
    receipt_no     VARCHAR(100) UNIQUE,
    recorded_by    UUID REFERENCES users(id),
    notes          TEXT,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- LEAVE APPLICATIONS
-- ============================================================
CREATE TABLE leave_applications (
    id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id   UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    class_id     UUID NOT NULL REFERENCES classes(id),
    from_date    DATE NOT NULL,
    to_date      DATE NOT NULL,
    reason       TEXT NOT NULL,
    status       leave_status NOT NULL DEFAULT 'pending',
    reviewed_by  UUID REFERENCES teachers(id),
    review_note  TEXT,
    reviewed_at  TIMESTAMPTZ,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_leave_dates CHECK (to_date >= from_date)
);

-- ============================================================
-- INDEXES
-- ============================================================
CREATE INDEX idx_users_email             ON users(email);
CREATE INDEX idx_sessions_user           ON user_sessions(user_id);
CREATE INDEX idx_sessions_expires        ON user_sessions(expires_at);
CREATE INDEX idx_students_class          ON students(class_id);
CREATE INDEX idx_class_subjects_class    ON class_subjects(class_id);
CREATE INDEX idx_class_subjects_teacher  ON class_subjects(teacher_id);
CREATE INDEX idx_attendance_student_date ON attendance(student_id, date);
CREATE INDEX idx_attendance_term         ON attendance(term_id);
CREATE INDEX idx_internal_marks_student  ON internal_marks(student_id);
CREATE INDEX idx_internal_marks_subject  ON internal_marks(class_subject_id);
CREATE INDEX idx_results_student         ON results(student_id);
CREATE INDEX idx_results_term            ON results(term_id);
CREATE INDEX idx_student_fees_student    ON student_fees(student_id);
CREATE INDEX idx_payments_student        ON payments(student_id);
CREATE INDEX idx_leave_student           ON leave_applications(student_id);
CREATE INDEX idx_leave_status            ON leave_applications(status);

-- ============================================================
-- updated_at TRIGGER
-- ============================================================
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DO $$
DECLARE t TEXT;
BEGIN
    FOREACH t IN ARRAY ARRAY[
        'users', 'teachers', 'classes', 'students',
        'attendance', 'internal_marks', 'results',
        'student_fees', 'leave_applications'
    ] LOOP
        EXECUTE format(
            'CREATE TRIGGER trg_updated_at
             BEFORE UPDATE ON %I
             FOR EACH ROW EXECUTE FUNCTION set_updated_at()', t
        );
    END LOOP;
END;
$$;

-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin

DROP TABLE IF EXISTS leave_applications   CASCADE;
DROP TABLE IF EXISTS payments             CASCADE;
DROP TABLE IF EXISTS student_fees         CASCADE;
DROP TABLE IF EXISTS fees                 CASCADE;
DROP TABLE IF EXISTS results              CASCADE;
DROP TABLE IF EXISTS internal_marks       CASCADE;
DROP TABLE IF EXISTS attendance           CASCADE;
DROP TABLE IF EXISTS class_subjects       CASCADE;
DROP TABLE IF EXISTS subjects             CASCADE;
DROP TABLE IF EXISTS students             CASCADE;
DROP TABLE IF EXISTS classes              CASCADE;
DROP TABLE IF EXISTS teachers             CASCADE;
DROP TABLE IF EXISTS password_resets      CASCADE;
DROP TABLE IF EXISTS user_sessions        CASCADE;
DROP TABLE IF EXISTS users                CASCADE;
DROP TABLE IF EXISTS terms                CASCADE;
DROP TABLE IF EXISTS academic_years       CASCADE;

DROP FUNCTION IF EXISTS set_updated_at    CASCADE;

DROP TYPE IF EXISTS session_status        CASCADE;
DROP TYPE IF EXISTS leave_status          CASCADE;
DROP TYPE IF EXISTS payment_method        CASCADE;
DROP TYPE IF EXISTS payment_status        CASCADE;
DROP TYPE IF EXISTS attendance_status     CASCADE;
DROP TYPE IF EXISTS gender                CASCADE;
DROP TYPE IF EXISTS user_role             CASCADE;

-- +goose StatementEnd