/* ==========================================================================
   app.js — PARAGON-MB watchlist-realtime v0.1 · comfortable variant
   ==========================================================================
   · vanilla JS 전용. React/npm/번들러 0.
   · 상태 토글 데모 UI, 행 렌더링, 실시간 하이라이트 데모, mock 데이터
   · copy 객체 centralize — HTML 하드코딩 0건 (Constraint 8 + Plan §6.5)
   · Plan §11 절대 기준선 준수 — 폰트·컬러·모션·레이아웃 임의 변경 0건
   ========================================================================== */

/* === SECTION: COPY — 모든 UI 텍스트 centralize (copy.md SSOT → JS 구현) === */
const COPY = {
  // 헤더 장 상태 라벨 (Plan §6.2 한국 증권 관례)
  marketPre:        '장전',
  marketOpen:       '장중',
  marketClose:      '장마감',
  lastUpdated:      '갱신',

  // 헤더 연결 상태
  wsDisconnected:   '실시간 연결 끊김 — 재연결 중',
  tokenRefreshing:  '인증 갱신 중',
  authFailed:       '인증이 만료되었습니다 — 앱을 재시작해 주세요',
  networkError:     '네트워크 연결을 확인해 주세요',
  retryButton:      '다시 시도',

  // W1 빈 상태
  emptyMessage:     '아직 등록된 종목이 없습니다',
  emptyCta:         '+ 종목 추가',

  // W2 목록
  addButton:        '+ 종목 추가',
  deleteAriaLabel:  '삭제',
  afterHoursLabel:  '종가',
  deleteToast:      '삭제됨',
  undoButton:       '되돌리기',
  toastSeparator:   '·',

  // W3 종목 추가 폼
  formTitle:        '종목 추가',
  inputPlaceholder: '예: 005930',
  inputLabel:       '종목코드',
  submitButton:     '등록',
  cancelButton:     '취소',

  // W3 인라인 에러 (Plan §6.4 SSOT)
  errorInvalidCode:    '등록할 수 없는 종목코드입니다',
  errorDuplicate:      '이미 등록된 종목입니다',
  errorLimitExceeded:  '관심종목은 최대 20개까지 등록할 수 있습니다',
  errorNetwork:        '네트워크 연결을 확인해 주세요',
};

/* === SECTION: MOCK DATA ================================================== */
// 부호 잠금: dir 'up'=red(▲+), 'down'=blue(▼−), 'neutral'=slate(-)
// 가격 정밀도: 정수(원) 단위, 소수점 없음 (KRW)
const MOCK_SYMBOLS = [
  { code: '005930', name: '삼성전자',   price: 73400,  changeAmt: 1200,  changePct:  1.66, dir: 'up' },
  { code: '000660', name: 'SK하이닉스', price: 184500, changeAmt: -3500, changePct: -1.86, dir: 'down' },
  { code: '035420', name: 'NAVER',      price: 161500, changeAmt: 0,     changePct:  0.00, dir: 'neutral' },
  { code: '005380', name: '현대차',     price: 214000, changeAmt: 2500,  changePct:  1.18, dir: 'up' },
  { code: '035720', name: '카카오',     price: 36450,  changeAmt: -850,  changePct: -2.28, dir: 'down' },
  { code: '051910', name: 'LG화학',     price: 289500, changeAmt: 1500,  changePct:  0.52, dir: 'up' },
];

/* === SECTION: STATE ======================================================= */
let appState = {
  view:        'w2-normal',   // 현재 활성 뷰 키
  symbols:     [...MOCK_SYMBOLS],
  deletedItem: null,          // 되돌리기용
  toastTimer:  null,
};

/* === SECTION: DOM REFS ==================================================== */
const $ = (sel) => document.querySelector(sel);
const $$ = (sel) => document.querySelectorAll(sel);

// 뷰 컨테이너
const viewEmpty  = $('#view-empty');
const viewList   = $('#view-list');
const viewAdd    = $('#view-add');

// 헤더
const marketLabel   = $('#market-label');
const marketTime    = $('#market-time');
const badgeSlot     = $('#badge-slot');
const headerBanner  = $('#header-banner');

// 목록
const symbolList    = $('#symbol-list');

// 폼
const symbolInput   = $('#symbol-input');
const inlineError   = $('#inline-error');
const btnSubmit     = $('#btn-submit');

// 토스트
const toast        = $('#toast');
const toastMsg     = $('#toast-msg');
const toastUndo    = $('#toast-undo');

/* === SECTION: VIEW MANAGER ================================================ */
const VIEWS = {
  'w1-empty':         showEmptyState,
  'w2-normal':        () => showListState('normal'),
  'w2-loading':       () => showListState('loading'),
  'w2-ws-disconnected': () => showListState('ws-disconnected'),
  'w2-token-refreshing': () => showListState('token-refreshing'),
  'w2-auth-failed':   () => showListState('auth-failed'),
  'w2-network-error': () => showListState('network-error'),
  'w3-add':           showAddForm,
  // 에러 변형은 폼 내부에서 처리
  'w3-error-invalid': () => showAddForm('invalid'),
  'w3-error-duplicate': () => showAddForm('duplicate'),
  'w3-error-limit':   () => showAddForm('limit'),
  'w3-error-network': () => showAddForm('network'),
};

function switchView(key) {
  appState.view = key;
  // 데모 버튼 active 상태 갱신
  $$('.demo-btn[data-view]').forEach(btn => {
    btn.classList.toggle('active', btn.dataset.view === key);
  });
  if (VIEWS[key]) VIEWS[key]();
}

function activateSection(el) {
  [viewEmpty, viewList, viewAdd].forEach(v => {
    if (v) { v.classList.remove('active'); }
  });
  if (el) el.classList.add('active');
}

/* === SECTION: W1 EMPTY STATE ============================================== */
function showEmptyState() {
  activateSection(viewEmpty);
  setHeader('normal');
  renderEmpty();
}

function renderEmpty() {
  if (!viewEmpty) return;
  viewEmpty.innerHTML = `
    <div class="view-empty">
      <svg class="empty-icon" viewBox="0 0 40 40" fill="none" xmlns="http://www.w3.org/2000/svg"
           role="img" aria-label="빈 관심종목">
        <rect x="4" y="8" width="32" height="24" rx="3" stroke="currentColor" stroke-width="1.5" fill="none"/>
        <line x1="4" y1="15" x2="36" y2="15" stroke="currentColor" stroke-width="1" stroke-dasharray="2 2"/>
        <line x1="12" y1="21" x2="28" y2="21" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" opacity="0.4"/>
        <line x1="14" y1="25.5" x2="26" y2="25.5" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" opacity="0.25"/>
      </svg>
      <p class="empty-message">${COPY.emptyMessage}</p>
    </div>
  `;
}

/* === SECTION: W2 LIST STATE =============================================== */
function showListState(subState) {
  activateSection(viewList);
  setHeader(subState);
  if (subState === 'loading') {
    renderSkeletons();
  } else {
    // network-error: 기존 캐시값 목록 유지 (wireframe §5 W2 — 완전 빈 화면 금지)
    renderSymbols(subState === 'ws-disconnected' || subState === 'auth-failed' || subState === 'token-refreshing' || subState === 'normal' || subState === 'network-error');
  }
}

function setHeader(subState) {
  if (!marketLabel) return;

  // 장 상태 라벨 (데모: normal=장중, ws-disconnected=장중 유지, network-error=장중 유지)
  const labelMap = { 'normal': COPY.marketOpen, 'loading': COPY.marketOpen,
                     'ws-disconnected': COPY.marketOpen, 'token-refreshing': COPY.marketOpen,
                     'auth-failed': COPY.marketClose, 'after-hours': COPY.marketClose,
                     'network-error': COPY.marketOpen };
  marketLabel.textContent = labelMap[subState] || COPY.marketOpen;

  // 갱신 시각
  const now = new Date();
  const hms = now.toLocaleTimeString('ko-KR', { hour: '2-digit', minute: '2-digit', second: '2-digit', hour12: false });
  if (marketTime) marketTime.textContent = `${COPY.lastUpdated} ${hms}`;

  // 배지 슬롯 초기화
  if (badgeSlot) badgeSlot.innerHTML = '';
  if (headerBanner) { headerBanner.className = 'header-banner'; headerBanner.textContent = ''; }

  // 상태별 배지 + 배너 세팅
  if (subState === 'ws-disconnected') {
    badgeSlot.innerHTML = `<span class="badge badge-warning" role="status" aria-label="연결 끊김 경고">!</span>`;
    if (headerBanner) {
      headerBanner.classList.add('ws-warn', 'active');
      headerBanner.textContent = COPY.wsDisconnected;
    }
  } else if (subState === 'token-refreshing') {
    badgeSlot.innerHTML = `<div class="spinner" role="status" aria-label="${COPY.tokenRefreshing}"></div>`;
    if (headerBanner) {
      headerBanner.classList.add('ws-warn', 'active');
      headerBanner.textContent = COPY.tokenRefreshing;
    }
  } else if (subState === 'auth-failed') {
    badgeSlot.innerHTML = `<span class="badge badge-error" role="alert" aria-label="인증 오류">!</span>`;
    if (headerBanner) {
      headerBanner.classList.add('auth-fail', 'active');
      headerBanner.textContent = COPY.authFailed;
    }
  } else if (subState === 'network-error') {
    // wireframe §5 W2 network-error: 헤더 아래 배너 + 재시도 버튼 (auth-failed 위치·스타일 재사용)
    badgeSlot.innerHTML = `<span class="badge badge-error" role="alert" aria-label="네트워크 오류">!</span>`;
    if (headerBanner) {
      headerBanner.classList.add('network-err', 'active');
      // 텍스트 + 재시도 버튼 — COPY 경유 (하드코딩 0건)
      const msgSpan = document.createElement('span');
      msgSpan.textContent = COPY.networkError;
      const retryBtn = document.createElement('button');
      retryBtn.className = 'btn-network-retry';
      retryBtn.textContent = COPY.retryButton;
      // 재시도 클릭: loading 전환 → 1.2s 후 normal 복귀 (시각 피드백, 정적 no-op 금지)
      retryBtn.addEventListener('click', () => {
        stopHighlightDemo();
        switchView('w2-loading');
        setTimeout(() => {
          switchView('w2-normal');
          startHighlightDemo();
        }, 1200);
      });
      headerBanner.appendChild(msgSpan);
      headerBanner.appendChild(retryBtn);
    }
  }
}

/* === SECTION: RENDER SYMBOLS ============================================== */
function renderSymbols(isAfterHours) {
  if (!symbolList) return;
  symbolList.innerHTML = '';

  const symbols = appState.symbols.length > 0 ? appState.symbols : MOCK_SYMBOLS;

  symbols.forEach((sym, idx) => {
    const row = buildSymbolRow(sym, isAfterHours);
    symbolList.appendChild(row);
  });
}

function buildSymbolRow(sym, isAfterHours) {
  const row = document.createElement('div');
  row.className = 'symbol-row' + (isAfterHours ? ' after-hours' : '');
  row.dataset.code = sym.code;
  row.setAttribute('role', 'listitem');
  row.setAttribute('tabindex', '0');

  // 부호 심볼 + 색 클래스
  const dirSymbol = sym.dir === 'up' ? '▲' : sym.dir === 'down' ? '▼' : '-';
  const colorCls  = `color-${sym.dir}`;

  // 현재가 색 — comfortable variant에서 등락색 적용 (Plan §4.3 ★ 핵심 차이)
  const priceCls = `current-price ${sym.dir}`;

  // 수치 포맷 (tabular-nums 보조, 정수 KRW)
  const priceStr    = sym.price.toLocaleString('ko-KR');
  const changeAmt   = sym.changeAmt >= 0 ? `+${Math.abs(sym.changeAmt).toLocaleString('ko-KR')}원` : `-${Math.abs(sym.changeAmt).toLocaleString('ko-KR')}원`;
  const changePct   = sym.changePct >= 0 ? `+${sym.changePct.toFixed(2)}%` : `${sym.changePct.toFixed(2)}%`;
  if (sym.dir === 'neutral') {
    // 보합: 부호 없이
  }

  const afterHoursBadge = isAfterHours
    ? `<span class="after-hours-badge">${COPY.afterHoursLabel}</span>` : '';

  row.innerHTML = `
    <div class="row-left">
      <span class="symbol-name">${escapeHtml(sym.name)}</span>
      <span class="symbol-code">${escapeHtml(sym.code)}</span>
    </div>
    <div class="row-right">
      <span class="${priceCls}">${afterHoursBadge}${priceStr}</span>
      <div class="change-row">
        <span class="change-symbol ${colorCls}">${dirSymbol}</span>
        <span class="change-pct ${colorCls}">${changePct}</span>
        <span class="change-amt ${colorCls}">${changeAmt}</span>
      </div>
    </div>
    <button class="delete-btn" aria-label="${COPY.deleteAriaLabel} ${escapeHtml(sym.name)}" data-code="${escapeHtml(sym.code)}">
      <svg width="14" height="14" viewBox="0 0 14 14" fill="none" xmlns="http://www.w3.org/2000/svg">
        <line x1="2" y1="2" x2="12" y2="12" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/>
        <line x1="12" y1="2" x2="2" y2="12" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/>
      </svg>
    </button>
  `;

  // 삭제 버튼 이벤트
  row.querySelector('.delete-btn').addEventListener('click', (e) => {
    e.stopPropagation();
    handleDelete(sym.code);
  });

  // 키보드 Delete
  row.addEventListener('keydown', (e) => {
    if (e.key === 'Delete') handleDelete(sym.code);
  });

  return row;
}

/* === SECTION: SKELETON ROWS =============================================== */
function renderSkeletons() {
  if (!symbolList) return;
  symbolList.innerHTML = '';
  for (let i = 0; i < 5; i++) {
    const row = document.createElement('div');
    row.className = 'skeleton-row';
    row.setAttribute('aria-hidden', 'true');
    row.innerHTML = `
      <div class="skeleton-left">
        <div class="skeleton-bar sk-name"></div>
        <div class="skeleton-bar sk-code"></div>
      </div>
      <div class="skeleton-right">
        <div class="skeleton-bar sk-price"></div>
        <div class="skeleton-bar sk-change"></div>
      </div>
    `;
    symbolList.appendChild(row);
  }
}

/* === SECTION: DELETE + TOAST ============================================== */
function handleDelete(code) {
  const idx = appState.symbols.findIndex(s => s.code === code);
  if (idx < 0) return;

  appState.deletedItem = { sym: appState.symbols[idx], idx };
  appState.symbols.splice(idx, 1);

  if (appState.symbols.length === 0) {
    switchView('w1-empty');
  } else {
    renderSymbols(false);
  }
  showToast();
}

function showToast() {
  if (!toast) return;
  if (appState.toastTimer) { clearTimeout(appState.toastTimer); }
  toast.classList.remove('hide');
  toast.classList.add('active');

  if (toastMsg) toastMsg.textContent = COPY.deleteToast;
  if (toastUndo) toastUndo.textContent = COPY.undoButton;

  appState.toastTimer = setTimeout(hideToast, 3000);
}

function hideToast() {
  if (!toast) return;
  toast.classList.add('hide');
  setTimeout(() => { toast.classList.remove('active', 'hide'); }, 250);
}

function undoDelete() {
  if (!appState.deletedItem) return;
  const { sym, idx } = appState.deletedItem;
  appState.symbols.splice(idx, 0, sym);
  appState.deletedItem = null;
  hideToast();
  if (appState.toastTimer) clearTimeout(appState.toastTimer);
  switchView('w2-normal');
}

/* === SECTION: W3 ADD FORM ================================================= */
function showAddForm(errorType) {
  activateSection(viewAdd);
  renderAddForm(errorType);
}

function renderAddForm(errorType) {
  if (!viewAdd) return;

  viewAdd.innerHTML = `
    <div class="form-header">
      <span class="form-title">${COPY.formTitle}</span>
      <button class="btn-cancel-header" id="btn-cancel-header">${COPY.cancelButton}</button>
    </div>
    <div class="form-body">
      <label class="input-label" for="symbol-input">${COPY.inputLabel}</label>
      <input id="symbol-input" class="symbol-input${errorType ? ' error-state' : ''}"
             type="text" inputmode="numeric"
             placeholder="${COPY.inputPlaceholder}"
             maxlength="6"
             autocomplete="off"
             aria-describedby="inline-error"/>
      <span id="inline-error" class="inline-error${errorType ? ' active' : ''}" role="alert">
        ${getErrorCopy(errorType)}
      </span>
      <div class="form-action-row">
        <button class="btn-submit" id="btn-submit">
          <span class="btn-text">${COPY.submitButton}</span>
          <span class="btn-spinner" aria-hidden="true"></span>
        </button>
        <button class="btn-cancel" id="btn-cancel">${COPY.cancelButton}</button>
      </div>
    </div>
  `;

  // 취소 버튼
  const cancelBtns = viewAdd.querySelectorAll('#btn-cancel-header, #btn-cancel');
  cancelBtns.forEach(btn => btn.addEventListener('click', () => {
    switchView(appState.symbols.length > 0 ? 'w2-normal' : 'w1-empty');
  }));

  // 등록 버튼 (loading 데모 — 500ms 후 성공 또는 에러)
  const submitBtn = viewAdd.querySelector('#btn-submit');
  const input     = viewAdd.querySelector('#symbol-input');
  if (submitBtn && input) {
    const doSubmit = () => {
      submitBtn.classList.add('loading');
      submitBtn.disabled = true;
      if (input) input.disabled = true;
      setTimeout(() => {
        submitBtn.classList.remove('loading');
        submitBtn.disabled = false;
        if (input) input.disabled = false;
        // 데모: 성공 시뮬레이션
        const code = input.value.trim();
        if (code.length === 6) {
          const newSym = { code, name: `종목 ${code}`, price: 50000, changeAmt: 300, changePct: 0.60, dir: 'up' };
          appState.symbols.push(newSym);
          switchView('w2-normal');
        } else {
          renderAddForm('invalid');
        }
      }, 500);
    };
    submitBtn.addEventListener('click', doSubmit);
    input.addEventListener('keydown', (e) => { if (e.key === 'Enter') doSubmit(); });
    // 자동 포커스
    setTimeout(() => { if (input) input.focus(); }, 50);
  }

  // Escape 키 = 취소
  document.addEventListener('keydown', escHandler);
}

function getErrorCopy(errorType) {
  const map = {
    invalid:   COPY.errorInvalidCode,
    duplicate: COPY.errorDuplicate,
    limit:     COPY.errorLimitExceeded,
    network:   COPY.errorNetwork,
  };
  return map[errorType] || '';
}

function escHandler(e) {
  if (e.key === 'Escape' && appState.view.startsWith('w3')) {
    document.removeEventListener('keydown', escHandler);
    switchView(appState.symbols.length > 0 ? 'w2-normal' : 'w1-empty');
  }
}

/* === SECTION: REALTIME HIGHLIGHT DEMO =====================================
   핵심 모션 — Plan §5.1 OQ-4 확정
   animation-recipes §3 호버 마이크로인터랙션 + §8 배경 패턴 응용
   classList.add('highlight-up') → 300ms 후 remove (단방향 fade-out, 깜빡임 0건)
   ========================================================================= */
function triggerHighlight() {
  if (!symbolList) return;
  const rows = symbolList.querySelectorAll('.symbol-row');
  if (rows.length === 0) return;

  // 랜덤 행 선택
  const idx = Math.floor(Math.random() * rows.length);
  const row = rows[idx];

  // 랜덤 방향 (데모)
  const hlClass = Math.random() > 0.5 ? 'highlight-up' : 'highlight-down';

  // 이전 하이라이트 즉시 제거 (동시 실행 방지)
  row.classList.remove('highlight-up', 'highlight-down');

  // reflow 강제 후 클래스 추가 (animation 재시작 보장)
  void row.offsetWidth;
  row.classList.add(hlClass);

  // 300ms 후 클래스 제거 (Plan §5.1: "300ms 후 remove 패턴")
  setTimeout(() => row.classList.remove(hlClass), 300);
}

// 자동 시뮬레이션: 1.5초마다 랜덤 행 하이라이트 (장중 상태 시만)
let highlightInterval = null;

function startHighlightDemo() {
  stopHighlightDemo();
  highlightInterval = setInterval(() => {
    if (appState.view === 'w2-normal') triggerHighlight();
  }, 1500);
}

function stopHighlightDemo() {
  if (highlightInterval) { clearInterval(highlightInterval); highlightInterval = null; }
}

/* === SECTION: DEMO CONTROL BAR ============================================ */
function initDemoBar() {
  const bar = $('#demo-bar');
  if (!bar) return;

  const DEMO_STATES = [
    { key: 'w1-empty',            label: 'W1 빈 상태' },
    { key: 'w2-normal',           label: 'W2 장중' },
    { key: 'w2-loading',          label: 'W2 로딩' },
    { key: 'w2-ws-disconnected',  label: 'W2 연결끊김' },
    { key: 'w2-token-refreshing', label: 'W2 인증갱신' },
    { key: 'w2-auth-failed',      label: 'W2 인증실패' },
    { key: 'w2-network-error',    label: 'W2 네트워크오류' },
    { key: 'w3-add',              label: 'W3 등록폼' },
    { key: 'w3-error-invalid',    label: 'W3 잘못된코드' },
    { key: 'w3-error-duplicate',  label: 'W3 중복' },
    { key: 'w3-error-limit',      label: 'W3 한도초과' },
    { key: 'w3-error-network',    label: 'W3 네트워크' },
    // 삭제 토스트는 별도 버튼
  ];

  bar.innerHTML = `<span class="demo-label">상태:</span>
    ${DEMO_STATES.map(s =>
      `<button class="demo-btn" data-view="${s.key}">${s.label}</button>`
    ).join('')}
    <button class="demo-btn" id="demo-toast-btn">삭제 토스트</button>
    <button class="demo-btn" id="demo-highlight-btn">하이라이트 1회</button>
  `;

  bar.querySelectorAll('.demo-btn[data-view]').forEach(btn => {
    btn.addEventListener('click', () => {
      stopHighlightDemo();
      switchView(btn.dataset.view);
      if (btn.dataset.view === 'w2-normal') startHighlightDemo();
    });
  });

  const toastDemoBtn = bar.querySelector('#demo-toast-btn');
  if (toastDemoBtn) {
    toastDemoBtn.addEventListener('click', () => {
      // 삭제 토스트 데모 — 임시 item 등록
      appState.deletedItem = { sym: MOCK_SYMBOLS[0], idx: 0 };
      showToast();
    });
  }

  const hlDemoBtn = bar.querySelector('#demo-highlight-btn');
  if (hlDemoBtn) {
    hlDemoBtn.addEventListener('click', () => {
      if (appState.view === 'w2-normal') triggerHighlight();
    });
  }
}

/* === SECTION: TOAST UNDO BINDING ========================================== */
function initToastUndo() {
  const undoBtn = document.getElementById('toast-undo');
  if (undoBtn) undoBtn.addEventListener('click', undoDelete);
}

/* === SECTION: INIT ========================================================= */
function init() {
  initDemoBar();
  initToastUndo();

  // 기본 뷰: W2 장중 (종목 있음)
  appState.symbols = [...MOCK_SYMBOLS];
  switchView('w2-normal');
  startHighlightDemo();
}

document.addEventListener('DOMContentLoaded', init);

/* === SECTION: UTILS ======================================================= */
function escapeHtml(str) {
  if (!str) return '';
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}
