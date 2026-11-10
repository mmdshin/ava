-- Disease categories (ACS, CHF, …) become content: editors can add,
-- rename, recolor and remove them instead of them being fixed in code.
--
-- The id is used in care plan ids ("acs-01"), so it can't change once
-- created. "general" is the shared category (plans that apply to every
-- disease); it always exists.

create table categories (
    id         text primary key check (id ~ '^[a-z][a-z0-9]{1,19}$'),
    title      text not null check (btrim(title) <> ''),
    -- Short code shown on cards ("ACS"); empty for none.
    abbr       text not null default '',
    -- Card color, "#RRGGBB".
    color      text not null check (color ~ '^#[0-9A-Fa-f]{6}$'),
    -- A Material icon name from the app's list (see content.CategoryIcons).
    icon       text not null default 'medical_information',
    position   int  not null,
    archived   boolean not null default false,
    revision   int not null default 1,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    updated_by bigint references users (id) on delete set null,
    check (id <> 'general' or not archived)
);

-- The five categories the app used to have built in.
insert into categories (id, title, abbr, color, icon, position) values
    ('acs',     'سندرم کرونری حاد',   'ACS', '#17A398', 'monitor_heart',     0),
    ('chf',     'نارسایی قلبی',       'CHF', '#3D8BFF', 'favorite',          1),
    ('dvt',     'ترومبوز ورید عمقی',  'DVT', '#8B5CF6', 'bloodtype',         2),
    ('mi',      'انفارکتوس میوکارد',  'MI',  '#F2A93E', 'emergency',         3),
    ('general', 'عمومی',              '',    '#EF5875', 'health_and_safety', 4);

-- Care plans and quizzes now point at a category instead of a fixed list.
alter table care_plans
    drop constraint if exists care_plans_id_check,
    drop constraint if exists care_plans_kind_check,
    add constraint care_plans_id_check check (id ~ '^[a-z][a-z0-9]*-[0-9]{2,}$'),
    add constraint care_plans_kind_fkey foreign key (kind) references categories (id) on update cascade;

alter table quizzes
    drop constraint if exists quizzes_kind_check,
    add constraint quizzes_kind_fkey foreign key (kind) references categories (id) on update cascade;
