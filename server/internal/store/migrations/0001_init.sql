-- AvA content schema, version 1.
--
-- Content is stored normalized (one row per plan, section, item,
-- question, option…) so it can be edited piece by piece, with foreign
-- keys and checks guarding integrity. What the app downloads is a
-- published, immutable snapshot in content_versions.

create table tags (
    name       text primary key check (name ~ '^[a-z]+(_[a-z]+)*$'),
    -- Persian description for the admin tag manager (optional).
    label      text not null default '',
    created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------- care plans

create table care_plans (
    id         text primary key check (id ~ '^(acs|chf|dvt|mi|general)-[0-9]{2,}$'),
    kind       text not null check (kind in ('acs', 'chf', 'dvt', 'mi', 'general')),
    title      text not null check (btrim(title) <> ''),
    position   int  not null,
    -- Never delete published content: archive it (ids stay reserved).
    archived   boolean not null default false,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    check (starts_with(id, kind || '-'))
);
create unique index care_plans_title_per_kind
    on care_plans (kind, btrim(title)) where not archived;

create table care_plan_tags (
    plan_id  text not null references care_plans (id) on delete cascade,
    tag      text not null references tags (name) on update cascade,
    position int  not null,
    primary key (plan_id, tag)
);

create table care_plan_sections (
    id       bigserial primary key,
    plan_id  text not null references care_plans (id) on delete cascade,
    position int  not null,
    type     text not null check (type in ('definition', 'relatedTo',
        'definingCharacteristics', 'riskFactors', 'interventions', 'outcomes')),
    -- Only when the heading differs from the type's default label.
    title    text,
    unique (plan_id, position)
);

create table care_plan_section_items (
    section_id bigint not null references care_plan_sections (id) on delete cascade,
    position   int    not null,
    text       text   not null check (btrim(text) <> ''),
    primary key (section_id, position)
);

-- ---------------------------------------------------------- Gordon assessment

create table gordon_domains (
    id       text primary key check (id ~ '^[a-z]+(_[a-z]+)*$'),
    title    text not null check (btrim(title) <> ''),
    position int  not null,
    archived boolean not null default false
);

create table gordon_findings (
    id        text primary key check (id ~ '^[a-z0-9]+(_[a-z0-9]+)*$'),
    domain_id text not null references gordon_domains (id),
    title     text not null check (btrim(title) <> ''),
    position  int  not null,
    archived  boolean not null default false
);

create table gordon_finding_tags (
    finding_id text not null references gordon_findings (id) on delete cascade,
    tag        text not null references tags (name) on update cascade,
    position   int  not null,
    primary key (finding_id, tag)
);

-- -------------------------------------------------------------------- quizzes

create table quizzes (
    id       text primary key,
    title    text not null check (btrim(title) <> ''),
    kind     text check (kind in ('acs', 'chf', 'dvt', 'mi', 'general')),
    position int  not null,
    archived boolean not null default false
);

create table quiz_questions (
    id            text primary key,
    quiz_id       text not null references quizzes (id),
    position      int  not null,
    text          text not null check (btrim(text) <> ''),
    correct_index int  not null check (correct_index >= 0),
    explanation   text,
    hint          text,
    archived      boolean not null default false
);

create table quiz_question_options (
    question_id text not null references quiz_questions (id) on delete cascade,
    position    int  not null,
    text        text not null check (btrim(text) <> ''),
    primary key (question_id, position)
);

-- ------------------------------------------------------------------ publishing

-- Every publish is an immutable snapshot: exactly the JSON the app
-- downloads, plus its hash (used as the HTTP ETag).
create table content_versions (
    version        int primary key check (version > 0),
    schema_version int  not null,
    bundle         text not null,
    sha256         text not null,
    notes          text not null default '',
    published_by   text not null default '',
    published_at   timestamptz not null default now()
);
