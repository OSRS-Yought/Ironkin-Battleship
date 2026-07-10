-- =====================================================================
--  Battleship Bingo — crew allowlist
--  Run this AFTER schema.sql, in the Supabase SQL Editor.
--
--  Before this migration: any Discord account could read and write.
--  After it: only Discord IDs you have explicitly listed can do anything.
--  Enforced in Postgres, so it holds against curl, not just the UI.
-- =====================================================================

create table if not exists allowlist (
  discord_id text primary key,
  note       text,
  added_at   timestamptz not null default now()
);

-- Pull the caller's Discord snowflake out of their JWT.
-- The client cannot forge this — Supabase signs it at login.
create or replace function my_discord_id()
returns text
language sql
stable
as $$
  select coalesce(
    auth.jwt() -> 'user_metadata' ->> 'provider_id',
    auth.jwt() -> 'user_metadata' ->> 'sub'
  );
$$;

-- security definer so it can read allowlist without tripping its own RLS
create or replace function is_crew()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (select 1 from allowlist a where a.discord_id = my_discord_id());
$$;

-- ---------- seed: everyone who has already signed in ----------
-- Run this once so you don't lock yourself out. If you are the only
-- person who has logged in so far, this adds exactly you.

insert into allowlist (discord_id, note)
select discord_id, username from members
where discord_id is not null
on conflict (discord_id) do nothing;

-- ---------- replace every policy with a crew check ----------

alter table allowlist enable row level security;

drop policy if exists allow_read   on allowlist;
drop policy if exists allow_insert on allowlist;
drop policy if exists allow_delete on allowlist;

create policy allow_read   on allowlist for select to authenticated using (is_crew());
create policy allow_insert on allowlist for insert to authenticated with check (is_admin());
create policy allow_delete on allowlist for delete to authenticated using (is_admin());

-- members
drop policy if exists members_read   on members;
drop policy if exists members_insert on members;
drop policy if exists members_update on members;

create policy members_read on members for select to authenticated using (is_crew());
-- you may only create your own row, only with your own Discord id,
-- and only if that id is on the allowlist
create policy members_insert on members for insert to authenticated
  with check (id = auth.uid() and discord_id = my_discord_id() and is_crew());
create policy members_update on members for update to authenticated
  using ((id = auth.uid() or is_admin()) and is_crew())
  with check ((id = auth.uid() or is_admin()) and is_crew());

-- board
drop policy if exists board_read   on board;
drop policy if exists board_update on board;

create policy board_read   on board for select to authenticated using (is_crew());
create policy board_update on board for update to authenticated using (is_admin()) with check (is_admin());

-- tiles
drop policy if exists tiles_read   on tiles;
drop policy if exists tiles_insert on tiles;
drop policy if exists tiles_update on tiles;
drop policy if exists tiles_delete on tiles;

create policy tiles_read   on tiles for select to authenticated using (is_crew());
create policy tiles_insert on tiles for insert to authenticated with check (is_admin());
create policy tiles_delete on tiles for delete to authenticated using (is_admin());
create policy tiles_update on tiles for update to authenticated using (is_crew()) with check (is_crew());

-- assignments
drop policy if exists assign_read   on assignments;
drop policy if exists assign_insert on assignments;
drop policy if exists assign_delete on assignments;

create policy assign_read   on assignments for select to authenticated using (is_crew());
create policy assign_insert on assignments for insert to authenticated with check (added_by = auth.uid() and is_crew());
create policy assign_delete on assignments for delete to authenticated using (is_crew());

alter publication supabase_realtime add table allowlist;

-- =====================================================================
--  Adding crew members
--
--  In Discord: User Settings -> Advanced -> Developer Mode ON.
--  Then right-click a member -> Copy User ID.
--
--    insert into allowlist (discord_id, note) values
--      ('123456789012345678', 'Gimlin'),
--      ('987654321098765432', 'someone else');
--
--  Or use the Setup tab in the app once you are an admin.
--
--  Removing someone:
--    delete from allowlist where discord_id = '123456789012345678';
--    delete from members   where discord_id = '123456789012345678';
--  (the second line drops their claims; the first stops them coming back)
-- =====================================================================
