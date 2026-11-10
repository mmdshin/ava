-- Editing content through the API: optimistic locking, who changed
-- what, and settings such as the publishing freeze.

-- revision: bumped on every change; an edit must send the revision it
-- started from, so two editors can't silently overwrite each other.
alter table care_plans
    add column revision   int not null default 1,
    add column updated_by bigint references users (id) on delete set null;

alter table quizzes
    add column revision   int not null default 1,
    add column updated_at timestamptz not null default now(),
    add column updated_by bigint references users (id) on delete set null;

alter table quiz_questions
    add column revision   int not null default 1,
    add column updated_at timestamptz not null default now(),
    add column updated_by bigint references users (id) on delete set null;

alter table gordon_domains
    add column revision   int not null default 1,
    add column updated_at timestamptz not null default now(),
    add column updated_by bigint references users (id) on delete set null;

alter table gordon_findings
    add column revision   int not null default 1,
    add column updated_at timestamptz not null default now(),
    add column updated_by bigint references users (id) on delete set null;

-- Every change made through the API (and every publish), with the
-- entity before and after, for the version history and the thesis.
create table audit_log (
    id          bigserial primary key,
    at          timestamptz not null default now(),
    user_id     bigint references users (id) on delete set null,
    user_email  text not null default '',
    action      text not null,   -- create, update, archive, restore, reorder, publish, …
    entity      text not null,   -- care_plan, quiz, question, domain, finding, tag, settings, user
    entity_id   text not null default '',
    before      jsonb,
    after       jsonb
);
create index audit_log_entity on audit_log (entity, entity_id, at desc);
create index audit_log_at on audit_log (at desc);

create table settings (
    key        text primary key,
    value      jsonb not null,
    updated_at timestamptz not null default now(),
    updated_by bigint references users (id) on delete set null
);
