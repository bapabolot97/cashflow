-- ============================================================
--  CashFlow — Admin Panel Setup
--  Jalankan SETELAH supabase-setup.sql
--  Cara: https://supabase.com/dashboard/project/xmgdrigxjiazmseyspup/sql/new
--        paste semua, klik RUN
-- ============================================================

-- ---------- TABEL: profiles ----------
-- Menyimpan role tiap user. User pertama yang daftar otomatis jadi admin.
create table if not exists public.profiles (
  id         uuid primary key references auth.users(id) on delete cascade,
  email      text,
  name       text,
  role       text not null default 'user' check (role in ('admin','user')),
  banned     boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists idx_prof_role on public.profiles (role);

-- ---------- TRIGGER: auto-bikin profile saat user daftar ----------
-- User pertama (tabel masih kosong) -> role 'admin', sisanya 'user'.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  is_first boolean;
begin
  select not exists (select 1 from public.profiles) into is_first;

  insert into public.profiles (id, email, name, role)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'name', split_part(new.email,'@',1)),
    case when is_first then 'admin' else 'user' end
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------- BACKFILL: user yang sudah ada ----------
-- Kalau sudah ada user sebelum trigger ini dibuat, isi profile-nya.
-- User paling lama -> admin, sisanya -> user.
insert into public.profiles (id, email, name, role)
select
  u.id,
  u.email,
  coalesce(u.raw_user_meta_data->>'name', split_part(u.email,'@',1)),
  case when u.id = (select id from auth.users order by created_at asc limit 1)
       then 'admin' else 'user' end
from auth.users u
on conflict (id) do nothing;

-- ---------- FUNGSI BANTU: cek admin ----------
-- security definer supaya bisa dibaca dari dalam policy tanpa rekursi.
create or replace function public.is_admin()
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin' and banned = false
  );
$$;

-- ---------- RLS: profiles ----------
alter table public.profiles enable row level security;

-- tiap user bisa baca profile-nya sendiri
drop policy if exists prof_self_read on public.profiles;
create policy prof_self_read on public.profiles
  for select using (auth.uid() = id);

-- admin bisa baca SEMUA profile
drop policy if exists prof_admin_read on public.profiles;
create policy prof_admin_read on public.profiles
  for select using (public.is_admin());

-- admin bisa ubah role / ban user lain
drop policy if exists prof_admin_update on public.profiles;
create policy prof_admin_update on public.profiles
  for update using (public.is_admin()) with check (public.is_admin());

-- user bisa update nama sendiri (tapi bukan role-nya — dijaga trigger di bawah)
drop policy if exists prof_self_update on public.profiles;
create policy prof_self_update on public.profiles
  for update using (auth.uid() = id) with check (auth.uid() = id);

-- ---------- PROTEKSI: user biasa tidak bisa naikkan role sendiri ----------
create or replace function public.protect_role()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- kalau yang update bukan admin, role & banned tidak boleh berubah
  if not public.is_admin() then
    new.role   := old.role;
    new.banned := old.banned;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_protect_role on public.profiles;
create trigger trg_protect_role
  before update on public.profiles
  for each row execute function public.protect_role();

-- ---------- RLS TAMBAHAN: admin bisa baca semua data user ----------
-- Tanpa ini, admin cuma lihat profile-nya, bukan transaksi orang lain.

drop policy if exists tx_admin_read on public.transactions;
create policy tx_admin_read on public.transactions
  for select using (public.is_admin());

drop policy if exists cat_admin_read on public.categories;
create policy cat_admin_read on public.categories
  for select using (public.is_admin());

drop policy if exists bud_admin_read on public.budgets;
create policy bud_admin_read on public.budgets
  for select using (public.is_admin());

drop policy if exists rec_admin_read on public.recurring;
create policy rec_admin_read on public.recurring
  for select using (public.is_admin());

drop policy if exists wal_admin_read on public.wallets;
create policy wal_admin_read on public.wallets
  for select using (public.is_admin());

drop policy if exists prt_admin_read on public.portfolio;
create policy prt_admin_read on public.portfolio
  for select using (public.is_admin());

drop policy if exists set_admin_read on public.settings;
create policy set_admin_read on public.settings
  for select using (public.is_admin());

-- ---------- RLS TAMBAHAN: admin bisa hapus data user (kelola user) ----------
drop policy if exists tx_admin_del on public.transactions;
create policy tx_admin_del on public.transactions
  for delete using (public.is_admin());

drop policy if exists cat_admin_del on public.categories;
create policy cat_admin_del on public.categories
  for delete using (public.is_admin());

drop policy if exists bud_admin_del on public.budgets;
create policy bud_admin_del on public.budgets
  for delete using (public.is_admin());

drop policy if exists rec_admin_del on public.recurring;
create policy rec_admin_del on public.recurring
  for delete using (public.is_admin());

drop policy if exists wal_admin_del on public.wallets;
create policy wal_admin_del on public.wallets
  for delete using (public.is_admin());

drop policy if exists prt_admin_del on public.portfolio;
create policy prt_admin_del on public.portfolio
  for delete using (public.is_admin());

drop policy if exists set_admin_del on public.settings;
create policy set_admin_del on public.settings
  for delete using (public.is_admin());

-- ---------- FUNGSI: statistik global (dipanggil admin panel) ----------
create or replace function public.admin_stats()
returns json
language plpgsql
security definer
stable
set search_path = public
as $$
declare
  result json;
begin
  if not public.is_admin() then
    raise exception 'Akses ditolak: bukan admin';
  end if;

  select json_build_object(
    'total_users',     (select count(*) from public.profiles),
    'total_banned',    (select count(*) from public.profiles where banned),
    'total_admins',    (select count(*) from public.profiles where role = 'admin'),
    'total_tx',        (select count(*) from public.transactions),
    'total_income',    (select coalesce(sum(amount),0) from public.transactions where type = 'inc'),
    'total_expense',   (select coalesce(sum(amount),0) from public.transactions where type = 'exp'),
    'total_wallets',   (select count(*) from public.wallets),
    'total_budgets',   (select count(*) from public.budgets),
    'active_7d',       (select count(distinct user_id) from public.transactions where date >= current_date - 7)
  ) into result;

  return result;
end;
$$;

-- ---------- FUNGSI: daftar semua user + ringkasan datanya ----------
create or replace function public.admin_users()
returns table (
  id          uuid,
  email       text,
  name        text,
  role        text,
  banned      boolean,
  created_at  timestamptz,
  tx_count    bigint,
  tx_income   numeric,
  tx_expense  numeric,
  last_active date
)
language plpgsql
security definer
stable
set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'Akses ditolak: bukan admin';
  end if;

  return query
  select
    p.id, p.email, p.name, p.role, p.banned, p.created_at,
    coalesce(t.cnt, 0)::bigint,
    coalesce(t.inc, 0),
    coalesce(t.exp, 0),
    t.last_date
  from public.profiles p
  left join (
    select user_id,
           count(*) as cnt,
           sum(case when type='inc' then amount else 0 end) as inc,
           sum(case when type='exp' then amount else 0 end) as exp,
           max(date) as last_date
    from public.transactions
    group by user_id
  ) t on t.user_id = p.id
  order by p.created_at asc;
end;
$$;

-- ---------- FUNGSI: admin ubah role user ----------
create or replace function public.admin_set_role(target uuid, new_role text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'Akses ditolak: bukan admin';
  end if;
  if new_role not in ('admin','user') then
    raise exception 'Role tidak valid';
  end if;
  -- jangan biarkan admin terakhir diturunkan
  if new_role = 'user' and (select count(*) from public.profiles where role='admin') <= 1
     and (select role from public.profiles where id = target) = 'admin' then
    raise exception 'Tidak bisa menurunkan admin terakhir';
  end if;
  update public.profiles set role = new_role where id = target;
end;
$$;

-- ---------- FUNGSI: admin ban / unban user ----------
create or replace function public.admin_set_ban(target uuid, val boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'Akses ditolak: bukan admin';
  end if;
  if target = auth.uid() then
    raise exception 'Tidak bisa ban diri sendiri';
  end if;
  update public.profiles set banned = val where id = target;
end;
$$;

-- ---------- FUNGSI: admin hapus semua data satu user ----------
create or replace function public.admin_purge_user(target uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'Akses ditolak: bukan admin';
  end if;
  if target = auth.uid() then
    raise exception 'Tidak bisa hapus data sendiri';
  end if;
  delete from public.transactions where user_id = target;
  delete from public.categories   where user_id = target;
  delete from public.budgets      where user_id = target;
  delete from public.recurring    where user_id = target;
  delete from public.wallets      where user_id = target;
  delete from public.portfolio    where user_id = target;
  delete from public.settings     where user_id = target;
end;
$$;

-- ---------- IZIN EKSEKUSI ----------
grant execute on function public.is_admin()            to authenticated;
grant execute on function public.admin_stats()         to authenticated;
grant execute on function public.admin_users()         to authenticated;
grant execute on function public.admin_set_role(uuid, text)  to authenticated;
grant execute on function public.admin_set_ban(uuid, boolean) to authenticated;
grant execute on function public.admin_purge_user(uuid)      to authenticated;

-- ============================================================
--  SELESAI.
--  User PERTAMA yang daftar otomatis jadi admin.
--  Kalau sudah ada user, yang paling lama jadi admin.
-- ============================================================
