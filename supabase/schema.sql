-- 드레스코드 뽑기 — Supabase 설정
-- Supabase 대시보드 → SQL Editor에 통째로 붙여넣고 Run (한 번만, 다시 실행해도 괜찮아요)
--
-- 명단·색·인원을 바꾸면 아래 dc_draw 함수의 v_names / v_colors / v_per 와
-- index.html 의 CONFIG 를 같이 고쳐야 해요.

-- 1) 결과 테이블
create table if not exists public.dc_results (
  name  text primary key,                -- 한 사람당 한 줄 → 1인 1회 보장
  color text not null,
  ord   int  not null,                   -- 뽑은 순서
  at    timestamptz not null default now()
);

-- 2) 보안: 누구나 결과는 볼 수 있지만, 직접 쓰기/수정/삭제는 불가
alter table public.dc_results enable row level security;
revoke insert, update, delete, truncate on public.dc_results from anon, authenticated;
grant select on public.dc_results to anon, authenticated;
drop policy if exists "dc_results read" on public.dc_results;
create policy "dc_results read" on public.dc_results
  for select to anon, authenticated using (true);

-- 3) 뽑기 함수: 이 함수로만 결과가 추가돼요
create or replace function public.dc_draw(p_name text)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_names  text[] := array['지우맘','주아맘','윤이맘','리우맘','이수맘','나윤맘','유나맘','하연맘','도연맘'];
  v_colors text[] := array['red','burgundy','lightpink'];
  v_per    int    := 3;
  v_pool   text[] := '{}';
  v_color  text;
  v_used   int;
  v_pick   text;
  v_row    public.dc_results;
begin
  if p_name is null or not (p_name = any(v_names)) then
    raise exception '명단에 없는 이름이에요.';
  end if;

  -- 동시에 눌러도 한 명씩 처리
  perform pg_advisory_xact_lock(hashtext('dc_draw'));

  select * into v_row from public.dc_results where name = p_name;
  if found then
    return json_build_object('already', true, 'result', row_to_json(v_row));
  end if;

  -- 통 안에 남은 공
  foreach v_color in array v_colors loop
    select count(*) into v_used from public.dc_results where color = v_color;
    for i in 1 .. greatest(v_per - v_used, 0) loop
      v_pool := v_pool || v_color;
    end loop;
  end loop;

  if coalesce(array_length(v_pool, 1), 0) = 0 then
    raise exception '공이 모두 뽑혔어요.';
  end if;

  v_pick := v_pool[1 + floor(random() * array_length(v_pool, 1))::int];

  insert into public.dc_results (name, color, ord)
  values (p_name, v_pick, (select count(*) + 1 from public.dc_results))
  returning * into v_row;

  return json_build_object('already', false, 'result', row_to_json(v_row));
end;
$$;

revoke all on function public.dc_draw(text) from public;
grant execute on function public.dc_draw(text) to anon, authenticated;

-- 4) 실시간 반영: 누가 뽑으면 다른 폰에 바로 보이게
do $$
begin
  alter publication supabase_realtime add table public.dc_results;
exception when duplicate_object then null;
end $$;

-- 결과 초기화가 필요하면 SQL Editor에서 이 한 줄만 실행:
--   truncate public.dc_results;
