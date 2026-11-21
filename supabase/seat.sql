-- 자리 뽑기 — Supabase 설정
-- Supabase 대시보드 → SQL Editor에 통째로 붙여넣고 Run (한 번만, 다시 실행해도 괜찮아요)
-- schema.sql(드레스코드)과 별개라 드레스코드 결과에는 영향이 없어요.
--
-- 명단이나 자리 수를 바꾸면 아래 dc_seat_draw 함수의 v_names / v_seats 와
-- seat/index.html 의 CONFIG 를 같이 고쳐야 해요.

-- 1) 결과 테이블
create table if not exists public.dc_seats (
  name text primary key,                         -- 한 사람당 한 줄 → 1인 1회
  seat int  not null unique check (seat >= 1),   -- 한 자리에 한 사람
  ord  int  not null,                            -- 뽑은 순서
  at   timestamptz not null default now()
);

-- 2) 보안: 누구나 결과는 볼 수 있지만, 직접 쓰기/수정/삭제는 불가
alter table public.dc_seats enable row level security;
revoke insert, update, delete, truncate on public.dc_seats from anon, authenticated;
grant select on public.dc_seats to anon, authenticated;
drop policy if exists "dc_seats read" on public.dc_seats;
create policy "dc_seats read" on public.dc_seats
  for select to anon, authenticated using (true);

-- 3) 자리 뽑기 함수: 이 함수로만 결과가 추가돼요
create or replace function public.dc_seat_draw(p_name text)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_names text[] := array['지우맘','주아맘','윤이맘','리우맘','이수맘','나윤맘','유나맘','하연맘','도연맘'];
  v_seats int    := 9;
  v_pool  int[];
  v_pick  int;
  v_row   public.dc_seats;
begin
  if p_name is null or not (p_name = any(v_names)) then
    raise exception '명단에 없는 이름이에요.';
  end if;

  -- 동시에 눌러도 한 명씩 처리
  perform pg_advisory_xact_lock(hashtext('dc_seat_draw'));

  select * into v_row from public.dc_seats where name = p_name;
  if found then
    return json_build_object('already', true, 'result', row_to_json(v_row));
  end if;

  -- 아직 아무도 안 앉은 자리
  select coalesce(array_agg(s), '{}') into v_pool
  from generate_series(1, v_seats) s
  where s not in (select seat from public.dc_seats);

  if coalesce(array_length(v_pool, 1), 0) = 0 then
    raise exception '자리가 모두 찼어요.';
  end if;

  v_pick := v_pool[1 + floor(random() * array_length(v_pool, 1))::int];

  insert into public.dc_seats (name, seat, ord)
  values (p_name, v_pick, (select count(*) + 1 from public.dc_seats))
  returning * into v_row;

  return json_build_object('already', false, 'result', row_to_json(v_row));
end;
$$;

revoke all on function public.dc_seat_draw(text) from public;
grant execute on function public.dc_seat_draw(text) to anon, authenticated;

-- 4) 실시간 반영
do $$
begin
  alter publication supabase_realtime add table public.dc_seats;
exception when duplicate_object then null;
end $$;

-- 결과 초기화가 필요하면 SQL Editor에서 이 한 줄만 실행:
--   truncate public.dc_seats;
