-- ============================================================
--  CashFlow — Supabase Database Setup
--  Cara pakai:
--    1. Buka https://supabase.com/dashboard/project/xmgdrigxjiazmseyspup/sql/new
--    2. Copy SEMUA isi file ini
--    3. Paste ke SQL Editor, klik RUN (atau Ctrl+Enter)
--    4. Selesai — refresh aplikasi CashFlow
-- ============================================================

-- ---------- TABEL: transactions ----------
create table if not exists public.transactions (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users(id) on delete cascade,
  name         text not null,
  type         text not null check (type in ('inc','exp')),
  amount       numeric not null default 0,
  category     uuid,
  date         date not null default current_date,
  time         text not null default to_char(now(),'HH24:MI'),
  wallet_id    uuid,
  note         text default '',
  recurring_id uuid,
  created_at   timestamptz not null default now()
);

-- ---------- TABEL: categories ----------
create table if not exists public.categories (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users(id) on delete cascade,
  name       text not null,
  icon       text default '📝',
  type       text default 'both' check (type in ('inc','exp','both')),
  color      text default '#007aff',
  created_at timestamptz not null default now()
);

-- ---------- TABEL: budgets (amplop) ----------
create table if not exists public.budgets (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users(id) on delete cascade,
  name       text not null,
  icon       text default '🎒',
  category   uuid,
  amount     numeric not null default 0,
  created_at timestamptz not null default now()
);

-- ---------- TABEL: recurring (tagihan berulang) ----------
create table if not exists public.recurring (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users(id) on delete cascade,
  name       text not null,
  icon       text default '📅',
  amount     numeric not null default 0,
  category   uuid,
  freq       text default 'monthly' check (freq in ('weekly','monthly','yearly')),
  day        int default 1,
  created_at timestamptz not null default now()
);

-- ---------- TABEL: wallets (dompet) ----------
create table if not exists public.wallets (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users(id) on delete cascade,
  name       text not null,
  icon       text default '🏦',
  type       text default 'bank' check (type in ('bank','ewallet','tunai','kartu')),
  balance    numeric not null default 0,
  created_at timestamptz not null default now()
);

-- ---------- TABEL: portfolio (investasi) ----------
create table if not exists public.portfolio (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users(id) on delete cascade,
  name          text not null,
  symbol        text default '',
  type          text default 'saham' check (type in ('saham','crypto','emas','reksa')),
  capital       numeric not null default 0,
  current_value numeric not null default 0,
  created_at    timestamptz not null default now()
);

-- ---------- TABEL: settings (preferensi user) ----------
create table if not exists public.settings (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  app_name   text default 'CashFlow',
  cur_sym    text default 'Rp',
  disp_name  text default '',
  auto_save  boolean default true,
  theme      text default 'light',
  updated_at timestamptz not null default now()
);

-- ---------- INDEX ----------
create index if not exists idx_tx_user_date  on public.transactions (user_id, date desc);
create index if not exists idx_tx_user_cat   on public.transactions (user_id, category);
create index if not exists idx_cat_user      on public.categories   (user_id);
create index if not exists idx_bud_user      on public.budgets      (user_id);
create index if not exists idx_rec_user      on public.recurring    (user_id);
create index if not exists idx_wal_user      on public.wallets      (user_id);
create index if not exists idx_prt_user      on public.portfolio    (user_id);

-- ============================================================
--  ROW LEVEL SECURITY — tiap user cuma bisa lihat datanya sendiri
-- ============================================================
alter table public.transactions enable row level security;
alter table public.categories   enable row level security;
alter table public.budgets      enable row level security;
alter table public.recurring    enable row level security;
alter table public.wallets      enable row level security;
alter table public.portfolio    enable row level security;
alter table public.settings     enable row level security;

-- transactions
drop policy if exists tx_own on public.transactions;
create policy tx_own on public.transactions
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- categories
drop policy if exists cat_own on public.categories;
create policy cat_own on public.categories
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- budgets
drop policy if exists bud_own on public.budgets;
create policy bud_own on public.budgets
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- recurring
drop policy if exists rec_own on public.recurring;
create policy rec_own on public.recurring
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- wallets
drop policy if exists wal_own on public.wallets;
create policy wal_own on public.wallets
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- portfolio
drop policy if exists prt_own on public.portfolio;
create policy prt_own on public.portfolio
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- settings
drop policy if exists set_own on public.settings;
create policy set_own on public.settings
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ============================================================
--  SELESAI. Refresh aplikasi CashFlow, lalu daftar/masuk.
-- ============================================================
