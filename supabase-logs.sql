-- ============================================================
--  CashFlow — Login History / Audit Logs Setup (Khusus Admin)
-- ============================================================

-- ---------- TABEL: login_logs ----------
create table if not exists public.login_logs (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid references auth.users(id) on delete cascade,
  username    text,
  email       text,
  logged_at   timestamptz not null default now(),
  user_agent  text,
  status      text not null default 'success'
);

create index if not exists idx_login_logs_user on public.login_logs (user_id);
create index if not exists idx_login_logs_time on public.login_logs (logged_at desc);

-- ---------- RLS: login_logs ----------
alter table public.login_logs enable row level security;

-- Admin dapat membaca semua log
drop policy if exists login_logs_admin_read on public.login_logs;
create policy login_logs_admin_read on public.login_logs
  for select using (public.is_admin());

-- Admin dapat menghapus log lama jika perlu
drop policy if exists login_logs_admin_del on public.login_logs;
create policy login_logs_admin_del on public.login_logs
  for delete using (public.is_admin());

-- ---------- FUNGSI: Catat Login Saat User Masuk ----------
create or replace function public.log_user_login(p_agent text default '')
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_email text;
  v_name text;
  v_uname text;
begin
  if auth.uid() is null then
    return;
  end if;

  select 
    email,
    coalesce(raw_user_meta_data->>'name', ''),
    coalesce(raw_user_meta_data->>'username', split_part(email, '@', 1))
  into v_email, v_name, v_uname
  from auth.users
  where id = auth.uid();

  insert into public.login_logs (user_id, username, email, logged_at, user_agent, status)
  values (
    auth.uid(),
    coalesce(nullif(v_uname, ''), split_part(v_email, '@', 1)),
    v_email,
    now(),
    coalesce(nullif(p_agent, ''), 'Web Browser'),
    'success'
  );
end;
$$;

-- ---------- FUNGSI: Ambil Riwayat Login (Khusus Admin) ----------
create or replace function public.admin_get_login_logs(p_limit int default 100)
returns table (
  id          uuid,
  user_id     uuid,
  username    text,
  email       text,
  logged_at   timestamptz,
  user_agent  text,
  status      text,
  role        text
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
    l.id,
    l.user_id,
    coalesce(l.username, split_part(l.email, '@', 1)) as username,
    l.email,
    l.logged_at,
    l.user_agent,
    l.status,
    coalesce(p.role, 'user') as role
  from public.login_logs l
  left join public.profiles p on p.id = l.user_id
  order by l.logged_at desc
  limit p_limit;
end;
$$;

-- ---------- FUNGSI: Bersihkan Log Login (Khusus Admin) ----------
create or replace function public.admin_clear_login_logs()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'Akses ditolak: bukan admin';
  end if;
  delete from public.login_logs;
end;
$$;

-- ---------- IZIN EKSEKUSI ----------
grant execute on function public.log_user_login(text) to authenticated;
grant execute on function public.admin_get_login_logs(int) to authenticated;
grant execute on function public.admin_clear_login_logs() to authenticated;
