-- Accounts, sessions and each user's own data.

create table users (
    id            bigserial primary key,
    email         text not null,
    display_name  text not null default '',
    -- PBKDF2-SHA256: "pbkdf2-sha256$<iterations>$<salt b64>$<hash b64>"
    password_hash text not null,
    -- nurse: uses the app; editor: edits content; reviewer: also
    -- publishes; admin: also manages users.
    role          text not null default 'nurse'
                  check (role in ('nurse', 'editor', 'reviewer', 'admin')),
    created_at    timestamptz not null default now(),
    last_login_at timestamptz
);
create unique index users_email on users (lower(email));

-- Login sessions. Only a SHA-256 of the token is stored, so a database
-- leak doesn't expose usable tokens.
create table sessions (
    token_hash   bytea primary key,
    user_id      bigint not null references users (id) on delete cascade,
    created_at   timestamptz not null default now(),
    last_used_at timestamptz not null default now(),
    expires_at   timestamptz not null,
    user_agent   text not null default ''
);
create index sessions_user on sessions (user_id);

-- ------------------------------------------------------------ user data
-- References to content use the stable content ids. No foreign keys to
-- the content tables: archived or renamed content must never break or
-- delete someone's data; the app simply skips ids it doesn't know.

create table user_favorites (
    user_id    bigint not null references users (id) on delete cascade,
    plan_id    text   not null,
    created_at timestamptz not null default now(),
    primary key (user_id, plan_id)
);

create table user_notes (
    user_id    bigint not null references users (id) on delete cascade,
    plan_id    text   not null,
    text       text   not null check (btrim(text) <> '' and length(text) <= 5000),
    updated_at timestamptz not null default now(),
    primary key (user_id, plan_id)
);

create table user_recent_plans (
    user_id   bigint not null references users (id) on delete cascade,
    plan_id   text   not null,
    viewed_at timestamptz not null default now(),
    primary key (user_id, plan_id)
);

-- One finished quiz. quiz_id is the quiz's id, or 'mistakes' for the
-- "review my mistakes" practice.
create table quiz_attempts (
    id          bigserial primary key,
    user_id     bigint not null references users (id) on delete cascade,
    quiz_id     text   not null,
    mode        text   not null check (mode in ('practice', 'exam')),
    score       int    not null check (score >= 0),
    total       int    not null check (total > 0 and score <= total),
    finished_at timestamptz not null default now()
);
create index quiz_attempts_user on quiz_attempts (user_id, quiz_id);

-- Right or wrong per question; the latest answer to each question
-- decides whether it is in the user's "mistakes".
create table quiz_attempt_answers (
    attempt_id  bigint  not null references quiz_attempts (id) on delete cascade,
    question_id text    not null,
    correct     boolean not null,
    primary key (attempt_id, question_id)
);
create index quiz_attempt_answers_question on quiz_attempt_answers (question_id);
