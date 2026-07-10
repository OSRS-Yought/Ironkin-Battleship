-- =====================================================================
--  Battleship Bingo — Supabase schema
--  Paste this whole file into the Supabase SQL Editor and run it once.
-- =====================================================================

-- ---------- tables ----------

create table if not exists members (
  id           uuid primary key references auth.users(id) on delete cascade,
  discord_id   text,
  username     text,
  display_name text,
  avatar_url   text,
  is_admin     boolean not null default false,
  created_at   timestamptz not null default now()
);

create table if not exists board (
  id         int primary key default 1,
  title      text not null default 'Battleship Bingo',
  cols       int  not null default 10,
  rows       int  not null default 10,
  locked     boolean not null default false,
  updated_at timestamptz not null default now(),
  constraint board_is_singleton check (id = 1)
);

insert into board (id) values (1) on conflict (id) do nothing;

create table if not exists tiles (
  id          uuid primary key default gen_random_uuid(),
  pos         int  not null,                       -- 0-based grid position
  name        text not null default '',
  qty         int  not null default 1,
  image       text,                                -- data: URL of the cropped slice
  status      text not null default 'open',        -- open | hit | splash
  resolved_by uuid references members(id) on delete set null,
  resolved_at timestamptz,
  notes       text not null default '',
  updated_at  timestamptz not null default now(),
  constraint tiles_status_valid check (status in ('open','hit','splash'))
);

create unique index if not exists tiles_pos_idx on tiles(pos);

create table if not exists assignments (
  tile_id    uuid not null references tiles(id) on delete cascade,
  member_id  uuid not null references members(id) on delete cascade,
  added_by   uuid references members(id) on delete set null,
  created_at timestamptz not null default now(),
  primary key (tile_id, member_id)
);

create index if not exists assignments_member_idx on assignments(member_id);

-- ---------- helper: is the caller an admin? ----------

create or replace function is_admin()
returns boolean
language sql
security definer
set search_path = public
as $$
  select coalesce((select m.is_admin from members m where m.id = auth.uid()), false);
$$;

-- ---------- row level security ----------
-- No secrets live in this database. Everyone signed in can read everything
-- and everyone signed in can claim/unclaim tiles and call hits.
-- Only admins can create, delete, or shuffle tiles, or change board settings.

alter table members     enable row level security;
alter table board       enable row level security;
alter table tiles       enable row level security;
alter table assignments enable row level security;

-- members
drop policy if exists members_read   on members;
drop policy if exists members_insert on members;
drop policy if exists members_update on members;

create policy members_read   on members for select to authenticated using (true);
create policy members_insert on members for insert to authenticated with check (id = auth.uid());
create policy members_update on members for update to authenticated
  using (id = auth.uid() or is_admin())
  with check (id = auth.uid() or is_admin());

-- board
drop policy if exists board_read   on board;
drop policy if exists board_update on board;

create policy board_read   on board for select to authenticated using (true);
create policy board_update on board for update to authenticated using (is_admin()) with check (is_admin());

-- tiles
drop policy if exists tiles_read   on tiles;
drop policy if exists tiles_insert on tiles;
drop policy if exists tiles_update on tiles;
drop policy if exists tiles_delete on tiles;

create policy tiles_read   on tiles for select to authenticated using (true);
create policy tiles_insert on tiles for insert to authenticated with check (is_admin());
create policy tiles_delete on tiles for delete to authenticated using (is_admin());
-- any signed-in member may mark a hit/splash, edit notes, or rename a tile
create policy tiles_update on tiles for update to authenticated using (true) with check (true);

-- assignments
drop policy if exists assign_read   on assignments;
drop policy if exists assign_insert on assignments;
drop policy if exists assign_delete on assignments;

create policy assign_read   on assignments for select to authenticated using (true);
-- note: added_by must be you, but member_id may be anyone.
-- that is deliberate: you can put a teammate on a tile for them.
create policy assign_insert on assignments for insert to authenticated with check (added_by = auth.uid());
create policy assign_delete on assignments for delete to authenticated using (true);

-- ---------- realtime ----------

alter publication supabase_realtime add table tiles;
alter publication supabase_realtime add table assignments;
alter publication supabase_realtime add table members;
alter publication supabase_realtime add table board;

-- tiles/assignments deletes need full row data for realtime to broadcast them
alter table tiles       replica identity full;
alter table assignments replica identity full;

-- ---------- shuffle ----------
-- Reshuffles which task sits in which cell. Admin only.
-- Tile identity (and its history) travels with the task, not the cell.

create or replace function shuffle_board()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_admin() then
    raise exception 'shuffle_board: admin only';
  end if;

  -- park positions out of range so the unique index does not trip mid-update
  update tiles set pos = pos + 100000;

  with shuffled as (
    select id, (row_number() over (order by random())) - 1 as new_pos
    from tiles
  )
  update tiles t
     set pos = s.new_pos, updated_at = now()
    from shuffled s
   where t.id = s.id;
end;
$$;

-- =====================================================================
--  AFTER YOUR FIRST LOGIN, make yourself an admin:
--    update members set is_admin = true where username = 'your_discord_username';
-- =====================================================================
