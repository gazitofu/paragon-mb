/* === SECTION: copy-object ===
 * PARAGON-MB compact variant — app.js
 * copy.md SSOT → 렌더링용 centralize. HTML 하드코딩 0건.
 * Plan §6.5 mockup 한정 카피 정책 정합. */

const COPY = {
  market: {
    preOpen: '장전',
    open:    '장중',
    closed:  '장마감',
  },
  header: {
    updated:    (t) => `${t} 기준`,
    closingRef: '종가 기준',
  },
  status: {
    wsDisconnected:  '실시간 연결 끊김 — 재연결 중',
    tokenRefreshing: '인증 갱신 중',
    authFailed:      '인증이 만료되었습니다 — 앱을 재시작해 주세요',
    networkError:    '네트워크 연결을 확인해 주세요',
    networkRetry:    '다시 시도',
  },
  empty: {
    message: '아직 등록된 종목이 없습니다',
    cta:     '+ 종목 추가',
  },
  list: {
    closingBadge:  '종가',
    addButton:     '+',
    deleteTooltip: '삭제',
  },
  toast: {
    deleted: '삭제됨',
    undo:    '되돌리기',
  },
  addForm: {
    title:       '종목 추가',
    placeholder: '예: 005930',
    submit:      '등록',
    cancel:      '취소',
  },
  error: {
    invalidCode:    '등록할 수 없는 종목코드입니다',
    duplicate:      '이미 등록된 종목입니다',
    limitExceeded:  '관심종목은 최대 20개까지 등록할 수 있습니다',
    network:        '네트워크 연결을 확인해 주세요',
  },
  a11y: {
    loading:      '시세 불러오는 중',
    addSymbol:    '종목 추가',
    deleteSymbol: (name) => `${name} 삭제`,
  },
};

/* === SECTION: mock-data ===
 * 목업 전용 mock 데이터 (real WS/REST 미연결)
 * up/down/neutral 부호 혼합 — 색 검증용 */

const MOCK_SYMBOLS = [
  { code: '005930', name: '삼성전자',   price: 75400,  changePct: +1.89, changeAmt: +1400,  dir: 'up' },
  { code: '000660', name: 'SK하이닉스', price: 187500, changePct: -2.14, changeAmt: -4100,  dir: 'down' },
  { code: '035420', name: 'NAVER',      price: 163500, changePct: +0.62, changeAmt: +1000,  dir: 'up' },
  { code: '035720', name: '카카오',      price: 37450,  changePct: 0.00,  changeAmt: 0,      dir: 'neutral' },
  { code: '051910', name: 'LG화학',      price: 298000, changePct: -1.00, changeAmt: -3000,  dir: 'down' },
  { code: '006400', name: '삼성SDI',     price: 382000, changePct: +0.53, changeAmt: +2000,  dir: 'up' },
  { code: '003550', name: 'LG',          price: 71200,  changePct: -0.42, changeAmt: -300,   dir: 'down' },
  { code: '017670', name: 'SK텔레콤',    price: 53200,  changePct: +0.19, changeAmt: +100,   dir: 'up' },
];

/* === SECTION: state ===
 * 앱 상태. view: 'empty' | 'list' | 'add'
 * listState: 'normal' | 'loading' | 'ws-disconnected' | 'token-refreshing' | 'auth-failed' | 'network-error'
 * marketState: 'preOpen' | 'open' | 'closed' */

const STATE = {
  view: 'empty',
  listState: 'normal',
  marketState: 'open',
  symbols: [],
  toastTimer: null,
  toastSymbol: null,   // 삭제된 종목 (되돌리기용)
  highlightTimers: {}, // code → timer id
  addErrorKey: null,
  addLoading: false,
  clockTimer: null,
};

/* === SECTION: format-helpers === */

function fmtPrice(n) {
  return n.toLocaleString('ko-KR');
}

function fmtPct(n) {
  const abs = Math.abs(n).toFixed(2);
  if (n > 0)  return `+${abs}%`;
  if (n < 0)  return `${n.toFixed(2)}%`;
  return `0.00%`;
}

function fmtAmt(n) {
  const abs = Math.abs(n).toLocaleString('ko-KR');
  if (n > 0)  return `+${abs}`;
  if (n < 0)  return `${n.toLocaleString('ko-KR')}`;
  return `0`;
}

function fmtSymbol(dir) {
  if (dir === 'up')      return '▲';
  if (dir === 'down')    return '▼';
  return '−';
}

function nowHHMMSS() {
  return new Date().toLocaleTimeString('ko-KR', {
    hour: '2-digit', minute: '2-digit', second: '2-digit', hour12: false,
  });
}

/* === SECTION: render-header === */

function renderHeader() {
  const ms    = STATE.marketState;
  const ls    = STATE.listState;
  const label = document.getElementById('header-market-label');
  const updated = document.getElementById('header-updated');
  const badgeSlot = document.getElementById('header-badge-slot');
  const alertBanner = document.getElementById('header-alert');

  // 장 상태 라벨
  label.textContent = COPY.market[ms] || COPY.market.open;

  // 갱신 시각
  if (ms === 'closed') {
    updated.textContent = COPY.header.closingRef;
  } else {
    updated.textContent = COPY.header.updated(nowHHMMSS());
  }

  // 배지 슬롯 초기화
  badgeSlot.innerHTML = '';
  alertBanner.className = 'header-alert';
  alertBanner.innerHTML = '';
  alertBanner.style.display = 'none';

  if (ls === 'ws-disconnected') {
    // 헤더 우측 amber 배지 (Plan §7)
    const badge = document.createElement('span');
    badge.className = 'status-badge warning';
    badge.setAttribute('aria-label', COPY.status.wsDisconnected);
    badge.textContent = '⚠';
    badgeSlot.appendChild(badge);
    // 인라인 경고 텍스트 (헤더 아래)
    alertBanner.className = 'header-alert warning';
    alertBanner.textContent = COPY.status.wsDisconnected;
    alertBanner.style.display = 'flex';

  } else if (ls === 'token-refreshing') {
    // 파란 spinner
    const spinner = document.createElement('span');
    spinner.className = 'status-spinner';
    spinner.setAttribute('aria-label', COPY.status.tokenRefreshing);
    badgeSlot.appendChild(spinner);
    // CSS 클래스 경유 — 인라인 hex/style 0건
    alertBanner.className = 'header-alert info';
    alertBanner.textContent = COPY.status.tokenRefreshing;
    alertBanner.style.display = 'flex';

  } else if (ls === 'auth-failed') {
    const badge = document.createElement('span');
    badge.className = 'status-badge error';
    badge.setAttribute('aria-label', COPY.status.authFailed);
    badge.textContent = '!';
    badgeSlot.appendChild(badge);
    alertBanner.className = 'header-alert error';
    alertBanner.textContent = COPY.status.authFailed;
    alertBanner.style.display = 'flex';

  } else if (ls === 'network-error') {
    // 헤더 아래 network-error 배너 + 재시도 버튼 (wireframe §5 W2 SSOT)
    // auth-failed 배너 위치·스타일 재사용, 재시도 버튼 추가가 차이점
    const badge = document.createElement('span');
    badge.className = 'status-badge error';
    badge.setAttribute('aria-label', COPY.status.networkError);
    badge.textContent = '!';
    badgeSlot.appendChild(badge);
    alertBanner.className = 'header-alert network-error';
    // 텍스트 + 재시도 버튼 (COPY 경유 — 하드코딩 0건)
    const msgSpan = document.createElement('span');
    msgSpan.className = 'network-error-msg';
    msgSpan.textContent = COPY.status.networkError;
    const retryBtn = document.createElement('button');
    retryBtn.className = 'btn-network-retry';
    retryBtn.textContent = COPY.status.networkRetry;
    // 재시도 클릭: loading → 1.2s 후 normal 목록 복귀 (목업 시연용 시각 피드백)
    retryBtn.addEventListener('click', () => {
      STATE.listState = 'loading';
      STATE.symbols = [];
      renderHeader();
      renderList();
      setTimeout(() => {
        STATE.listState = 'normal';
        STATE.symbols = [...MOCK_SYMBOLS];
        renderHeader();
        renderList();
        startHighlightDemo();
      }, 1200);
    });
    alertBanner.appendChild(msgSpan);
    alertBanner.appendChild(retryBtn);
    alertBanner.style.display = 'flex';
  }
}

/* === SECTION: render-list === */

function renderList() {
  const listEl = document.getElementById('symbol-list-container');
  listEl.innerHTML = '';

  if (STATE.listState === 'loading') {
    // 스켈레톤 행 8개
    for (let i = 0; i < 8; i++) {
      const row = document.createElement('div');
      row.className = 'skeleton-row';
      row.setAttribute('aria-label', COPY.a11y.loading);
      row.innerHTML = `
        <div class="skeleton-block skeleton-name"></div>
        <div class="skeleton-block skeleton-price"></div>
        <div class="skeleton-block skeleton-change"></div>
      `;
      listEl.appendChild(row);
    }
    return;
  }

  // 목록 렌더
  const isClosed = (STATE.marketState !== 'open');
  STATE.symbols.forEach((sym) => {
    const row = document.createElement('div');
    row.className = 'symbol-row' + (isClosed ? ' market-closed' : '');
    row.dataset.code = sym.code;
    row.setAttribute('tabindex', '0');
    row.setAttribute('role', 'row');

    const closingBadge = isClosed
      ? `<span class="badge-closing">${COPY.list.closingBadge}</span>`
      : '';

    row.innerHTML = `
      <span class="row-name">${sym.name}</span>
      ${closingBadge}
      <div class="row-data">
        <span class="row-price">${fmtPrice(sym.price)}</span>
        <span class="row-change ${sym.dir}">
          <span class="change-symbol">${fmtSymbol(sym.dir)}</span>
          <span class="change-pct">${fmtPct(sym.changePct)}</span>
        </span>
      </div>
      <button
        class="btn-delete-row"
        aria-label="${COPY.a11y.deleteSymbol(sym.name)}"
        data-code="${sym.code}"
      >×</button>
    `;

    // 삭제 버튼 클릭
    row.querySelector('.btn-delete-row').addEventListener('click', (e) => {
      e.stopPropagation();
      deleteSymbol(sym.code);
    });

    listEl.appendChild(row);
  });
}

/* === SECTION: highlight-demo ===
 * 실시간 갱신 하이라이트 데모 (Plan §5.1 핵심 모션)
 * animation-recipes §3 호버 마이크로인터랙션 응용
 * classList.add('highlight-up') → 300ms 후 remove (단방향 fade-out, 깜빡임 금지) */

function triggerHighlight(code, dir) {
  const row = document.querySelector(`.symbol-row[data-code="${code}"]`);
  if (!row) return;

  // 기존 하이라이트 클래스 즉시 제거 후 reflow
  row.classList.remove('highlight-up', 'highlight-down');
  void row.offsetWidth; // force reflow

  const cls = dir === 'up' ? 'highlight-up' : 'highlight-down';
  row.classList.add(cls);

  // 기존 타이머 클리어
  if (STATE.highlightTimers[code]) {
    clearTimeout(STATE.highlightTimers[code]);
  }

  STATE.highlightTimers[code] = setTimeout(() => {
    row.classList.remove(cls);
    delete STATE.highlightTimers[code];
  }, 300);
}

/* 자동 하이라이트 데모: 2초마다 랜덤 행 값 변경 시뮬레이션 */
function startHighlightDemo() {
  stopHighlightDemo();
  STATE.highlightDemo = setInterval(() => {
    if (STATE.view !== 'list' || STATE.listState !== 'normal' || STATE.symbols.length === 0) return;
    const idx = Math.floor(Math.random() * STATE.symbols.length);
    const sym = STATE.symbols[idx];
    const dir = Math.random() > 0.5 ? 'up' : 'down';
    // 값을 살짝 변경
    const delta = Math.round(sym.price * 0.003 * (dir === 'up' ? 1 : -1));
    sym.price += delta;
    sym.changeAmt += delta;
    sym.changePct = parseFloat((sym.changePct + (dir === 'up' ? 0.05 : -0.05)).toFixed(2));
    sym.dir = dir;
    // 행 수치만 업데이트 (재렌더 없이)
    const row = document.querySelector(`.symbol-row[data-code="${sym.code}"]`);
    if (row) {
      const priceEl  = row.querySelector('.row-price');
      const changeEl = row.querySelector('.row-change');
      const symEl    = row.querySelector('.change-symbol');
      const pctEl    = row.querySelector('.change-pct');
      if (priceEl)  priceEl.textContent = fmtPrice(sym.price);
      if (changeEl) {
        changeEl.className = `row-change ${sym.dir}`;
      }
      if (symEl)    symEl.textContent = fmtSymbol(sym.dir);
      if (pctEl)    pctEl.textContent = fmtPct(sym.changePct);
    }
    triggerHighlight(sym.code, dir);
  }, 2000);
}

function stopHighlightDemo() {
  if (STATE.highlightDemo) {
    clearInterval(STATE.highlightDemo);
    STATE.highlightDemo = null;
  }
}

/* === SECTION: symbol-crud === */

function deleteSymbol(code) {
  const idx = STATE.symbols.findIndex((s) => s.code === code);
  if (idx === -1) return;

  STATE.toastSymbol = { ...STATE.symbols[idx], idx };
  STATE.symbols.splice(idx, 1);

  if (STATE.symbols.length === 0) {
    switchView('empty');
  } else {
    renderList();
  }

  showToast();
}

function undoDelete() {
  if (!STATE.toastSymbol) return;
  const { idx, ...sym } = STATE.toastSymbol;
  STATE.symbols.splice(Math.min(idx, STATE.symbols.length), 0, sym);
  STATE.toastSymbol = null;
  hideToast(true);
  if (STATE.view === 'empty') {
    switchView('list');
  } else {
    renderList();
  }
}

/* === SECTION: toast-control ===
 * 토스트 slide-up 등장 + 3s 자동 소멸 (Plan §5.4)
 * animation-recipes §8 toastIn/toastOut 적용 */

function showToast() {
  const slot = document.getElementById('toast-slot');
  slot.innerHTML = '';

  const toast = document.createElement('div');
  toast.className = 'toast';
  toast.setAttribute('role', 'status');
  toast.setAttribute('aria-live', 'polite');
  toast.innerHTML = `
    <span class="toast-text">${COPY.toast.deleted}</span>
    <button class="btn-undo">${COPY.toast.undo}</button>
  `;
  toast.querySelector('.btn-undo').addEventListener('click', undoDelete);
  slot.appendChild(toast);

  // 3s 자동 소멸
  if (STATE.toastTimer) clearTimeout(STATE.toastTimer);
  STATE.toastTimer = setTimeout(() => hideToast(false), 3000);
}

function hideToast(immediate) {
  const slot = document.getElementById('toast-slot');
  const toast = slot.querySelector('.toast');
  if (!toast) return;
  if (immediate) {
    slot.innerHTML = '';
    return;
  }
  toast.classList.add('hiding');
  setTimeout(() => { slot.innerHTML = ''; }, 220);
  if (STATE.toastTimer) {
    clearTimeout(STATE.toastTimer);
    STATE.toastTimer = null;
  }
}

/* === SECTION: add-form-logic === */

function submitAddForm() {
  const input = document.getElementById('add-input');
  const errorEl = document.getElementById('add-error');
  const submitBtn = document.getElementById('btn-submit');
  const code = input.value.trim().toUpperCase();

  // 에러 초기화
  input.classList.remove('has-error');
  errorEl.classList.remove('visible');
  errorEl.textContent = '';

  if (!code) return;

  // 한도 초과 검사
  if (STATE.symbols.length >= 20) {
    showAddError(input, errorEl, COPY.error.limitExceeded);
    return;
  }

  // 중복 검사
  if (STATE.symbols.find((s) => s.code === code)) {
    showAddError(input, errorEl, COPY.error.duplicate);
    return;
  }

  // 유효 코드 검사 (mock: 6자리 숫자)
  if (!/^\d{6}$/.test(code)) {
    showAddError(input, errorEl, COPY.error.invalidCode);
    return;
  }

  // loading 시뮬레이션 (Plan §4.2 W3 loading 상태)
  STATE.addLoading = true;
  submitBtn.disabled = true;
  submitBtn.classList.add('loading');

  setTimeout(() => {
    STATE.addLoading = false;
    submitBtn.disabled = false;
    submitBtn.classList.remove('loading');

    // mock 성공: 새 종목 추가
    const newSym = {
      code,
      name: `종목 ${code}`,
      price: 50000,
      changePct: 0.00,
      changeAmt: 0,
      dir: 'neutral',
    };
    STATE.symbols.push(newSym);
    switchView('list');
  }, 800);
}

function showAddForm_errorByKey(key) {
  const input = document.getElementById('add-input');
  const errorEl = document.getElementById('add-error');
  showAddError(input, errorEl, COPY.error[key] || '');
}

function showAddError(input, errorEl, msg) {
  input.classList.add('has-error');
  errorEl.textContent = msg;
  errorEl.classList.add('visible');
  input.focus();
}

/* === SECTION: view-switch ===
 * 뷰 전환 (W1/W2/W3). opacity fade-in 0.18s (Plan §5.3) */

function switchView(view) {
  stopHighlightDemo();
  STATE.view = view;

  const views = {
    empty: document.getElementById('view-empty'),
    list:  document.getElementById('view-list'),
    add:   document.getElementById('view-add'),
  };

  Object.entries(views).forEach(([k, el]) => {
    el.classList.toggle('active', k === view);
  });

  // 헤더 + 버튼 업데이트
  const addBtn = document.getElementById('btn-add-header');
  const headerTitle = document.getElementById('header-market-label');

  if (view === 'add') {
    headerTitle.textContent = COPY.addForm.title;
    addBtn.style.display = 'none';
    const input = document.getElementById('add-input');
    if (input) setTimeout(() => input.focus(), 50);
    // 에러 초기화
    const errorEl = document.getElementById('add-error');
    const inputEl = document.getElementById('add-input');
    if (errorEl) { errorEl.classList.remove('visible'); errorEl.textContent = ''; }
    if (inputEl) { inputEl.classList.remove('has-error'); inputEl.value = ''; }
  } else {
    addBtn.style.display = '';
    renderHeader();
    if (view === 'list') {
      if (STATE.listState === 'loading') {
        renderList();
        setTimeout(() => {
          STATE.listState = 'normal';
          STATE.symbols = [...MOCK_SYMBOLS];
          renderList();
          startHighlightDemo();
        }, 1500);
      } else {
        renderList();
        if (STATE.listState === 'normal') startHighlightDemo();
        // network-error: 목록 유지 (캐시값) — highlightDemo는 중단 상태 유지
      }
    }
  }
}

/* === SECTION: clock === */

function startClock() {
  stopClock();
  STATE.clockTimer = setInterval(() => {
    if (STATE.view !== 'list' || STATE.marketState === 'closed') return;
    renderHeader();
  }, 1000);
}

function stopClock() {
  if (STATE.clockTimer) {
    clearInterval(STATE.clockTimer);
    STATE.clockTimer = null;
  }
}

/* === SECTION: demo-controls ===
 * 브라우저 데모용 상태 셀렉터 — 상단 버튼으로 모든 상태 토글 */

const DEMO_STATES = [
  { label: 'W1 빈 상태',           action: () => setDemoState('empty') },
  { label: 'W2 장중 목록',          action: () => setDemoState('list-open') },
  { label: 'W2 로딩',              action: () => setDemoState('list-loading') },
  { label: 'W2 연결 끊김',          action: () => setDemoState('list-ws-disconnected') },
  { label: 'W2 인증 갱신 중',       action: () => setDemoState('list-token-refreshing') },
  { label: 'W2 인증 실패',          action: () => setDemoState('list-auth-failed') },
  { label: 'W2 네트워크 오류',       action: () => setDemoState('list-network-error') },
  { label: 'W2 장전',              action: () => setDemoState('list-preOpen') },
  { label: 'W2 장마감',            action: () => setDemoState('list-closed') },
  { label: 'W3 종목 추가',          action: () => setDemoState('add') },
  { label: 'W3 에러: 잘못된코드',   action: () => setDemoState('add-error-invalidCode') },
  { label: 'W3 에러: 중복',         action: () => setDemoState('add-error-duplicate') },
  { label: 'W3 에러: 한도초과',     action: () => setDemoState('add-error-limitExceeded') },
  { label: 'W3 에러: 네트워크',     action: () => setDemoState('add-error-network') },
  { label: '토스트 데모',           action: () => setDemoState('toast-demo') },
];

function setDemoState(key) {
  // 데모 버튼 활성 표시
  document.querySelectorAll('.demo-btn').forEach((b) => b.classList.remove('active'));
  const btn = document.querySelector(`.demo-btn[data-key="${key}"]`);
  if (btn) btn.classList.add('active');

  hideToast(true);

  if (key === 'empty') {
    STATE.symbols = [];
    STATE.listState = 'normal';
    STATE.marketState = 'open';
    switchView('empty');

  } else if (key === 'list-open') {
    STATE.symbols = [...MOCK_SYMBOLS];
    STATE.listState = 'normal';
    STATE.marketState = 'open';
    switchView('list');

  } else if (key === 'list-loading') {
    STATE.symbols = [];
    STATE.listState = 'loading';
    STATE.marketState = 'open';
    switchView('list');

  } else if (key === 'list-ws-disconnected') {
    STATE.symbols = [...MOCK_SYMBOLS];
    STATE.listState = 'ws-disconnected';
    STATE.marketState = 'open';
    switchView('list');
    renderHeader();

  } else if (key === 'list-token-refreshing') {
    STATE.symbols = [...MOCK_SYMBOLS];
    STATE.listState = 'token-refreshing';
    STATE.marketState = 'open';
    switchView('list');
    renderHeader();

  } else if (key === 'list-auth-failed') {
    STATE.symbols = [...MOCK_SYMBOLS];
    STATE.listState = 'auth-failed';
    STATE.marketState = 'open';
    switchView('list');
    renderHeader();

  } else if (key === 'list-network-error') {
    // W2 network-error: 캐시값(기존 목록) 유지 + 헤더 아래 배너 + 재시도 버튼
    // wireframe §5 W2 SSOT — 완전 빈 화면 금지
    STATE.symbols = [...MOCK_SYMBOLS];
    STATE.listState = 'network-error';
    STATE.marketState = 'open';
    switchView('list');
    renderHeader();

  } else if (key === 'list-preOpen') {
    STATE.symbols = [...MOCK_SYMBOLS];
    STATE.listState = 'normal';
    STATE.marketState = 'preOpen';
    switchView('list');
    renderHeader();

  } else if (key === 'list-closed') {
    STATE.symbols = [...MOCK_SYMBOLS];
    STATE.listState = 'normal';
    STATE.marketState = 'closed';
    switchView('list');
    renderHeader();

  } else if (key === 'add') {
    STATE.symbols = [...MOCK_SYMBOLS];
    STATE.listState = 'normal';
    STATE.marketState = 'open';
    switchView('add');

  } else if (key.startsWith('add-error-')) {
    const errorKey = key.replace('add-error-', '');
    STATE.symbols = errorKey === 'limitExceeded'
      ? Array.from({ length: 20 }, (_, i) => ({ ...MOCK_SYMBOLS[0], code: String(100000 + i) }))
      : [...MOCK_SYMBOLS];
    STATE.listState = 'normal';
    STATE.marketState = 'open';
    switchView('add');
    setTimeout(() => showAddForm_errorByKey(errorKey), 80);

  } else if (key === 'toast-demo') {
    STATE.symbols = [...MOCK_SYMBOLS];
    STATE.listState = 'normal';
    STATE.marketState = 'open';
    switchView('list');
    setTimeout(() => deleteSymbol(MOCK_SYMBOLS[0].code), 300);
  }
}

/* === SECTION: init === */

function initDemoControls() {
  const container = document.getElementById('demo-controls');
  DEMO_STATES.forEach(({ label, action }, i) => {
    const key = DEMO_STATES[i].label
      .replace(/\s+/g, '-')
      .replace(/[^\w가-힣-]/g, '');
    const btn = document.createElement('button');
    btn.className = 'demo-btn';
    btn.textContent = label;
    // data-key를 상태 key로 저장
    const stateKey = [
      'empty','list-open','list-loading','list-ws-disconnected',
      'list-token-refreshing','list-auth-failed','list-network-error',
      'list-preOpen','list-closed',
      'add','add-error-invalidCode','add-error-duplicate','add-error-limitExceeded',
      'add-error-network','toast-demo',
    ][i];
    btn.dataset.key = stateKey;
    btn.addEventListener('click', action);
    container.appendChild(btn);
  });
}

function initEventListeners() {
  // 헤더 "+" 버튼
  document.getElementById('btn-add-header').addEventListener('click', () => {
    switchView('add');
  });

  // W1 CTA
  document.getElementById('btn-empty-cta').addEventListener('click', () => {
    switchView('add');
  });

  // W3 등록 버튼
  document.getElementById('btn-submit').addEventListener('click', submitAddForm);

  // W3 취소 버튼
  document.getElementById('btn-cancel').addEventListener('click', () => {
    if (STATE.symbols.length > 0) {
      STATE.listState = 'normal';
      switchView('list');
    } else {
      switchView('empty');
    }
  });

  // W3 Return 키
  document.getElementById('add-input').addEventListener('keydown', (e) => {
    if (e.key === 'Enter') { e.preventDefault(); submitAddForm(); }
    if (e.key === 'Escape') {
      document.getElementById('btn-cancel').click();
    }
  });

  // W2 키보드 삭제 (포커스된 행)
  document.getElementById('symbol-list-container').addEventListener('keydown', (e) => {
    if (e.key === 'Delete' || e.key === 'Backspace') {
      const row = document.activeElement.closest('.symbol-row');
      if (row) deleteSymbol(row.dataset.code);
    }
  });
}

document.addEventListener('DOMContentLoaded', () => {
  initDemoControls();
  initEventListeners();
  startClock();

  // 초기 상태: W2 장중 목록
  STATE.symbols = [...MOCK_SYMBOLS];
  STATE.listState = 'normal';
  STATE.marketState = 'open';
  switchView('list');

  // 초기 데모 버튼 활성
  const firstBtn = document.querySelector('.demo-btn[data-key="list-open"]');
  if (firstBtn) firstBtn.classList.add('active');
});
