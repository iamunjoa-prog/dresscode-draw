/**
 * 드레스코드 뽑기 — Google Apps Script 서버
 * - 9명 고정 명단, 1인 1회
 * - 버건디/딥그린/아이보리 공이 3개씩(총 9개) 들어있는 통에서 하나씩 뽑음 → 자동으로 3명씩 균등
 * - 결과는 스크립트 속성에 저장, 모든 폰이 같은 결과판을 봄
 */

const NAMES = ['지우맘', '주아맘', '윤이맘', '리우맘', '이수맘', '나윤맘', '유나맘', '하연맘', '도연맘'];
const COLORS = [
  { id: 'burgundy', name: '버건디', en: 'Burgundy', hex: '#7B1E2E' },
  { id: 'deepgreen', name: '딥그린', en: 'Deep Green', hex: '#1F4D3A' },
  { id: 'ivory', name: '아이보리', en: 'Ivory', hex: '#F2EADB' }
];
const PER_COLOR = 3;
const KEY = 'results';

function doGet() {
  return HtmlService.createHtmlOutputFromFile('Index')
    .setTitle('드레스코드 뽑기')
    .addMetaTag('viewport', 'width=device-width, initial-scale=1, maximum-scale=1');
}

function readResults_() {
  const raw = PropertiesService.getScriptProperties().getProperty(KEY);
  return raw ? JSON.parse(raw) : [];
}

function getState() {
  return { names: NAMES, colors: COLORS, per: PER_COLOR, results: readResults_() };
}

function draw(name) {
  if (NAMES.indexOf(name) < 0) throw new Error('명단에 없는 이름이에요.');
  const lock = LockService.getScriptLock();
  lock.waitLock(15000); // 동시에 눌러도 한 명씩 처리
  try {
    const results = readResults_();
    const existing = results.filter(function (r) { return r.name === name; })[0];
    if (existing) {
      return { already: true, result: existing, state: getStateFrom_(results) };
    }
    // 통 안에 남은 공 목록
    const pool = [];
    COLORS.forEach(function (c) {
      const used = results.filter(function (r) { return r.color === c.id; }).length;
      for (let i = 0; i < PER_COLOR - used; i++) pool.push(c.id);
    });
    if (!pool.length) throw new Error('공이 모두 뽑혔어요.');
    const pick = pool[Math.floor(Math.random() * pool.length)];
    const rec = { name: name, color: pick, order: results.length + 1, at: new Date().toISOString() };
    results.push(rec);
    PropertiesService.getScriptProperties().setProperty(KEY, JSON.stringify(results));
    return { already: false, result: rec, state: getStateFrom_(results) };
  } finally {
    lock.releaseLock();
  }
}

function getStateFrom_(results) {
  return { names: NAMES, colors: COLORS, per: PER_COLOR, results: results };
}

/** 편집기에서 직접 실행: 결과 전체 초기화 */
function resetAll() {
  PropertiesService.getScriptProperties().deleteProperty(KEY);
}
