# 드레스코드 뽑기 — Claude Code 작업 가이드

동네 엄마 9명이 각자 폰으로 접속해서 드레스코드 색을 뽑는 모바일 웹앱이에요.
Google Apps Script 웹 앱으로 배포하고, clasp로 로컬 코드를 올려요.

## 구조

```
src/
  Code.gs          서버: 명단·색·인원 설정, 뽑기(LockService로 동시성 처리), 결과 저장(ScriptProperties)
  Index.html       화면 전체 (CSS + 캔버스 공 물리 + 4초 폴링)
  appsscript.json  웹 앱 설정 (나로 실행 / 익명 포함 모든 사용자 접근)
```

## 규칙

- 명단 9명은 고정이고, 한 사람당 1번만 뽑아요. 이미 뽑은 이름은 잠겨요.
- 레드·버건디·연핑크 공이 3개씩 9개 들어 있는 통에서 하나씩 꺼내는 방식이에요. 그래서 색마다 3명씩 균등하게 나뉘어요.
- 결과는 ScriptProperties의 `results` 키에 JSON 배열로 저장돼요: `{name, color, order, at}`
- 명단, 색, 인원을 바꿀 때는 `Code.gs`의 `NAMES` / `COLORS` / `PER_COLOR`를 고쳐요. 미리보기용으로 `Index.html`의 `DEMO` 객체에도 같은 값이 들어 있어서 둘 다 맞춰야 해요.
- `Index.html`은 `google.script.run`이 없으면 **미리보기 모드**(localStorage 저장)로 돌아가요. 브라우저에서 파일을 바로 열어서 UI를 확인할 수 있어요.
- Apps Script HtmlService에서는 `<meta viewport>`가 무시돼요. viewport 설정은 `Code.gs`의 `doGet()`에 있는 `addMetaTag`로 해요.
- 파일은 `src/Index.html` 하나로 유지해요. HtmlService에서 별도 JS/CSS 파일을 쓰려면 include 패턴이 필요해서예요.

## 처음 배포

1. https://script.google.com/home/usersettings 에서 **Google Apps Script API를 켜요** (처음 한 번만).
2. `npm install`
3. `npx clasp login` (브라우저에서 구글 로그인)
4. 스크립트를 만들어요 (clasp 버전에 따라 명령이 달라요):
   - v3: `npx clasp create-script --type standalone --title "드레스코드 뽑기" --rootDir src`
   - v2: `npx clasp create --type standalone --title "드레스코드 뽑기" --rootDir src`
   - 그러면 `.clasp.json`이 생기고 `rootDir`이 `src`로 잡혀 있어요.
5. `npx clasp push -f`
6. 배포해요:
   - v3: `npx clasp create-deployment --description "v1"`
   - v2: `npx clasp deploy --description "v1"`
7. 웹 앱 URL은 `https://script.google.com/macros/s/<deploymentId>/exec` 형식이에요. 이 링크를 단톡방에 공유하면 돼요.
   - URL이 권한 오류를 내면 편집기(`npm run open`)에서 `getState`를 한 번 실행해서 권한을 승인하고, 배포 → 배포 관리에서 액세스가 "모든 사용자"인지 확인해요.

## 수정 후 다시 배포 (URL 유지)

새로 배포하면 URL이 바뀌니까, **기존 배포 ID로 업데이트**해요:
- `npx clasp push -f`
- 배포 ID 확인: `npm run deployments`
- v3: `npx clasp update-deployment <deploymentId> --description "v2"`
- v2: `npx clasp deploy -i <deploymentId> --description "v2"`

## 결과 초기화

공유하기 전에 테스트로 돌렸다면 꼭 초기화해요.
- 편집기에서 `resetAll`을 실행하거나, `npx clasp run resetAll`을 써요 (clasp run은 추가 설정이 필요해서 편집기 쪽이 쉬워요).

## 작업할 때 확인할 것

- UI를 바꾸면 `src/Index.html`을 브라우저에서 열어 미리보기 모드로 9명을 끝까지 뽑아보고, 결과판과 남은 공 개수가 맞는지 확인해요.
- 폰 화면(390px 너비) 기준으로 확인해요.
