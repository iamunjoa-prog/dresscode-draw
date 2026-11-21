# 드레스코드 뽑기 — Claude Code 작업 가이드

동네 엄마 9명이 각자 폰으로 접속해서 드레스코드 색과 자리를 뽑는 모바일 웹앱이에요. 페이지가 두 개예요.
화면은 GitHub Pages(정적 페이지), 결과 저장은 Supabase(Postgres)로 해요.

## 구조

```
index.html           드레스코드 뽑기 (CSS + 캔버스 공 물리 + Supabase 연동). GitHub Pages가 main 브랜치 루트에서 바로 서빙해요.
seat/index.html      자리 뽑기 (카드 뒤집기 + 긴 테이블 배치도). 주소는 /seat/
supabase/schema.sql  드레스코드용: dc_results 테이블, 보안(RLS), 뽑기 함수 dc_draw, 실시간 설정
supabase/seat.sql    자리용: dc_seats 테이블, 보안(RLS), 뽑기 함수 dc_seat_draw, 실시간 설정
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
- 두 페이지 맨 위의 `SUPABASE_URL` / `SUPABASE_KEY`가 비어 있으면 **미리보기 모드**(localStorage 저장)로 돌아가요.
  여기에는 anon(publishable) 키만 넣어요. service_role 키는 절대 넣지 않아요.
- 실시간 반영은 Supabase Realtime(`postgres_changes`)으로 하고, 10초 폴링을 보조로 둬요.
- supabase-js는 jsDelivr CDN에서 버전 고정(`@2.45.4`)으로 불러와요.

## 자리 뽑기 (seat/)

- 긴 테이블 하나: 위쪽 줄 1~4번, 아래쪽 줄 5~8번, 오른쪽 끝자리 9번. `seat/index.html`의 `CONFIG.seats`에 위치가 있어요.
- 드레스코드와 무관하게 완전 랜덤이에요. 배치도에는 드레스코드 결과가 있으면 색 점만 표시해요(`dc_results` 읽기).
- 흐름: 이름 고르기 → 카드 섞기 → 카드 한 장 고르기 → 그때 `dc_seat_draw` 호출 → 카드가 뒤집히며 자리 번호. 어떤 카드를 고르든 자리는 서버가 정해요.
- 카드 섞기·고르기 중에는 폴링/실시간 갱신으로 화면을 다시 그리지 않아요(`phase !== 'idle'`).
- 명단·자리 수를 바꾸면 `seat/index.html`의 `CONFIG`와 `supabase/seat.sql`의 `v_names` / `v_seats`를 같이 고쳐요.
- 결과 초기화: `truncate public.dc_seats;` (드레스코드 결과와 별개)
- `seat/?local=1`: Supabase 없이 폰 한 대로 다같이 뽑는 모드(미리보기 모드와 같은 localStorage 저장, '내 자리' 문구 숨김).

## 배포

- `main`에 push하면 GitHub Pages가 자동으로 다시 배포해요 (1~2분).
- 주소: https://iamunjoa-prog.github.io/dresscode-draw/ , 자리 뽑기는 https://iamunjoa-prog.github.io/dresscode-draw/seat/

## 결과 초기화

공유하기 전에 테스트로 돌렸다면 꼭 초기화해요. Supabase SQL Editor에서:

```sql
truncate public.dc_results;
```

## 작업할 때 확인할 것

- UI를 바꾸면 `SUPABASE_URL`을 비운 복사본을 브라우저에서 열어 미리보기 모드로 9명을 끝까지 뽑아보고, 결과판과 남은 공 개수가 맞는지 확인해요.
- 폰 화면(390px 너비) 기준으로 확인해요.
- SQL을 바꾸면 9명이 동시에 뽑아도 3/3/3으로 나뉘는지, anon이 테이블에 직접 쓸 수 없는지 확인해요.
