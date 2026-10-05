create extension if not exists pgcrypto with schema extensions;

-- Function: Resolve login identifier (bisa username, nama, atau email)
create or replace function public.resolve_user_email(p_identifier text)
returns text
language plpgsql
security definer
stable
set search_path = public, auth, extensions
as $$
declare
  v_email text;
  v_clean text;
begin
  if p_identifier is null or trim(p_identifier) = '' then
    return '';
  end if;

  p_identifier := trim(p_identifier);

  -- 1. Cek jika cocok persis dengan email
  select email into v_email
  from auth.users
  where lower(email) = lower(p_identifier)
  limit 1;

  if v_email is not null then
    return v_email;
  end if;

  -- 2. Cek jika identifier ditambah @cashflow.app
  select email into v_email
  from auth.users
  where lower(email) = lower(p_identifier || '@cashflow.app')
  limit 1;

  if v_email is not null then
    return v_email;
  end if;

  -- 3. Cek berdasarkan username di user_metadata
  select email into v_email
  from auth.users
  where lower(coalesce(raw_user_meta_data->>'username', '')) = lower(p_identifier)
  limit 1;

  if v_email is not null then
    return v_email;
  end if;

  -- 4. Cek berdasarkan nama di user_metadata atau profiles
  select u.email into v_email
  from auth.users u
  left join public.profiles p on p.id = u.id
  where lower(coalesce(u.raw_user_meta_data->>'name', '')) = lower(p_identifier)
     or lower(coalesce(p.name, '')) = lower(p_identifier)
  limit 1;

  if v_email is not null then
    return v_email;
  end if;

  -- Fallback default: format clean + @cashflow.app
  v_clean := regexp_replace(lower(p_identifier), '[^a-z0-9_.-]', '', 'g');
  if v_clean = '' then
    return p_identifier;
  end if;
  return v_clean || '@cashflow.app';
end;
$$;

-- Function: Admin Reset Password User
create or replace function public.admin_set_user_password(p_target uuid, p_new_password text)
returns void
language plpgsql
security definer
set search_path = public, auth, extensions
as $$
begin
  if not public.is_admin() then
    raise exception 'Akses ditolak: bukan admin';
  end if;

  if length(p_new_password) < 6 then
    raise exception 'Password minimal 6 karakter';
  end if;

  update auth.users
  set encrypted_password = crypt(p_new_password, gen_salt('bf', 10)),
      updated_at = now()
  where id = p_target;

  if not found then
    raise exception 'User tidak ditemukan';
  end if;
end;
$$;

grant execute on function public.resolve_user_email(text) to anon, authenticated;
grant execute on function public.admin_set_user_password(uuid, text) to authenticated;
