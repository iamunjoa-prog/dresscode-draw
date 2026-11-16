# 드레스코드 뽑기 — Claude Code 작업 가이드

동네 엄마 9명이 각자 폰으로 접속해서 드레스코드 색을 뽑는 모바일 웹앱이에요.
화면은 GitHub Pages(정적 페이지), 결과 저장은 Supabase(Postgres)로 해요.

## 구조

```
index.html           화면 전체 (CSS + 캔버스 공 물리 + Supabase 연동). GitHub Pages가 main 브랜치 루트에서 바로 서빙해요.
supabase/schema.sql  Supabase SQL Editor에서 한 번 실행: 결과 테이블, 보안(RLS), 뽑기 함수 dc_draw, 실시간 설정
```

## 규칙

- 명단 9명은 고정이고, 한 사람당 1번만 뽑아요. `dc_results.name`이 primary key라 DB에서도 보장돼요.
- 레드·버건디·라이트핑크 공이 3개씩 9개 들어 있는 통에서 하나씩 꺼내는 방식이에요. 그래서 색마다 3명씩 균등하게 나뉘어요.
- 뽑기는 반드시 `dc_draw(p_name)` RPC로만 해요. `pg_advisory_xact_lock`으로 동시에 눌러도 한 명씩 처리돼요.
  anon 역할은 테이블을 읽기만 할 수 있고 insert/update/delete 권한이 없어요.
- 결과 테이블: `dc_results(name, color, ord, at)`. 화면에서는 `ord`를 `order`로 바꿔 써요(`norm()`).
- 명단, 색, 인원을 바꿀 때는 **두 군데**를 같이 고쳐요:
  - `index.html`의 `CONFIG` (화면 표시용)
  - `supabase/schema.sql`의 `dc_draw` 함수 안 `v_names` / `v_colors` / `v_per` → SQL Editor에서 다시 실행
- `index.html` 맨 위의 `SUPABASE_URL` / `SUPABASE_KEY`가 비어 있으면 **미리보기 모드**(localStorage 저장)로 돌아가요.
  여기에는 anon(publishable) 키만 넣어요. service_role 키는 절대 넣지 않아요.
- 실시간 반영은 Supabase Realtime(`postgres_changes`)으로 하고, 10초 폴링을 보조로 둬요.
- supabase-js는 jsDelivr CDN에서 버전 고정(`@2.45.4`)으로 불러와요.

## 배포

- `main`에 push하면 GitHub Pages가 자동으로 다시 배포해요 (1~2분).
- 주소: https://iamunjoa-prog.github.io/dresscode-draw/

## 결과 초기화

공유하기 전에 테스트로 돌렸다면 꼭 초기화해요. Supabase SQL Editor에서:

```sql
truncate public.dc_results;
```

## 작업할 때 확인할 것

- UI를 바꾸면 `SUPABASE_URL`을 비운 상태로 `index.html`을 브라우저에서 열어 미리보기 모드로 9명을 끝까지 뽑아보고, 결과판과 남은 공 개수가 맞는지 확인해요.
- 폰 화면(390px 너비) 기준으로 확인해요.
- SQL을 바꾸면 9명이 동시에 뽑아도 3/3/3으로 나뉘는지, anon이 테이블에 직접 쓸 수 없는지 확인해요.
