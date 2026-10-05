-- ============================================================
--  CashFlow — Admin Feed & Data Viewer Setup
-- ============================================================

create or replace function public.admin_get_all_transactions(
  p_user_id uuid default null,
  p_limit int default 200
)
returns table (
  id             uuid,
  user_id        uuid,
  username       text,
  user_name      text,
  email          text,
  name           text,
  type           text,
  amount         numeric,
  category       uuid,
  category_name  text,
  category_icon  text,
  tx_date        date,
  tx_time        text,
  wallet_id      uuid,
  wallet_name    text,
  note           text,
  created_at     timestamptz
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
    t.id,
    t.user_id,
    coalesce(u.raw_user_meta_data->>'username', split_part(u.email::text, '@', 1))::text as username,
    coalesce(p.name::text, (u.raw_user_meta_data->>'name')::text, split_part(u.email::text, '@', 1))::text as user_name,
    u.email::text as email,
    t.name::text as name,
    t.type::text as type,
    t.amount,
    t.category,
    coalesce(c.name::text, 'Tanpa Kategori')::text as category_name,
    coalesce(c.icon::text, '📝')::text as category_icon,
    t.date as tx_date,
    t.time::text as tx_time,
    t.wallet_id,
    coalesce(w.name::text, '-')::text as wallet_name,
    coalesce(t.note::text, '')::text as note,
    t.created_at
  from public.transactions t
  left join auth.users u on u.id = t.user_id
  left join public.profiles p on p.id = t.user_id
  left join public.categories c on c.id = t.category
  left join public.wallets w on w.id = t.wallet_id
  where (p_user_id is null or t.user_id = p_user_id)
  order by t.created_at desc
  limit p_limit;
end;
$$;

create or replace function public.admin_get_user_full_data(p_target uuid)
returns json
language plpgsql
security definer
stable
set search_path = public
as $$
declare
  v_res json;
begin
  if not public.is_admin() then
    raise exception 'Akses ditolak: bukan admin';
  end if;

  select json_build_object(
    'transactions', (
      select coalesce(json_agg(t order by t.created_at desc), '[]'::json)
      from (
        select 
          t.id, t.user_id, t.name, t.type, t.amount, t.date, t.time, t.wallet_id, t.note, t.created_at,
          coalesce(c.name, 'Lainnya') as category_name, 
          coalesce(c.icon, '📝') as category_icon, 
          coalesce(w.name, '-') as wallet_name
        from public.transactions t
        left join public.categories c on c.id = t.category
        left join public.wallets w on w.id = t.wallet_id
        where t.user_id = p_target
      ) t
    ),
    'wallets', (
      select coalesce(json_agg(w order by w.name asc), '[]'::json)
      from public.wallets w
      where w.user_id = p_target
    ),
    'budgets', (
      select coalesce(json_agg(b order by b.name asc), '[]'::json)
      from public.budgets b
      where b.user_id = p_target
    ),
    'recurring', (
      select coalesce(json_agg(r order by r.name asc), '[]'::json)
      from public.recurring r
      where r.user_id = p_target
    ),
    'portfolio', (
      select coalesce(json_agg(pf order by pf.name asc), '[]'::json)
      from public.portfolio pf
      where pf.user_id = p_target
    )
  ) into v_res;

  return v_res;
end;
$$;

grant execute on function public.admin_get_all_transactions(uuid, int) to authenticated;
grant execute on function public.admin_get_user_full_data(uuid) to authenticated;
