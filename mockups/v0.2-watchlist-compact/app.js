/* === SECTION: copy-object ===
 * PARAGON-MB compact variant v0.2 — app.js
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
    wordmark:   'PARAGON',
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
 * up/down/neutral 부호 혼합 — 색 검증용
 * changeAmt 절대값 + 방향심볼 2단 렌더 (오너 오버라이드 4) */

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
  toastSymbol: null,
  highlightTimers: {},
  addErrorKey: null,
  addLoading: false,
  clockTimer: null,
  highlightDemo: null,
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

/* 등락액 절대값 + 천단위 콤마 (부호는 방향심볼이 표현 — 오너 오버라이드 4) */
function fmtAmtAbs(n) {
  return Math.abs(n).toLocaleString('ko-KR');
}

function fmtSymbol(dir) {
  if (dir === 'up')   return '▲';
  if (dir === 'down') return '▼';
  return '−';
}

function nowHHMMSS() {
  return new Date().toLocaleTimeString('ko-KR', {
    hour: '2-digit', minute: '2-digit', second: '2-digit', hour12: false,
  });
}

/* === SECTION: gem-builder ===
 * PARAGON 보석 마크 — 4면 패싯 SVG (인라인, 4 polygon)
 * 컬러 보석 (인앱 워드마크용): TL #7DB7FB / TR #3B82F6 / BL #2563EB / BR #1E40AF
 * 그라데이션·외곽선·그림자·글로우 금지 (§2.2 Don't)
 * 마름모 꼭짓점: top(5,0) right(10,7) bottom(5,14) left(0,7) center(5,7) */

function buildGemSVG(w, h) {
  /* w=10, h=14 기본. CSS .wordmark-gem이 크기 제어하므로 100% 사용 */
  const vw = w || 10;
  const vh = h || 14;
  const cx = vw / 2;
  const cy = vh / 2;
  const t  = `${cx},0`;
  const r  = `${vw},${cy}`;
  const b  = `${cx},${vh}`;
  const l  = `0,${cy}`;
  const c  = `${cx},${cy}`;
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${vw} ${vh}" width="${vw}" height="${vh}" aria-hidden="true" focusable="false">
    <polygon points="${t} ${l} ${c}" fill="var(--gem-highlight)"/>
    <polygon points="${t} ${r} ${c}" fill="var(--gem-base)"/>
    <polygon points="${l} ${b} ${c}" fill="var(--gem-mid-dark)"/>
    <polygon points="${r} ${b} ${c}" fill="var(--gem-shadow)"/>
  </svg>`;
}

/* 모노크롬 보석 SVG — 메뉴바 아이콘 전용 (오너 정제 3)
 * hue 0, 명도만 다른 백색/회색조 4면. 라이팅 좌상단.
 * 토큰: --gem-mono-tl/tr/bl/br (tokens.md §B — gem-mono)
 * 그라데이션·외곽선·글로우 금지 (§2.2 Don't — 모노크롬도 동일 적용)
 * macOS template image 방식: 라이트 메뉴바에서 OS가 자동 반전 — Swift 처리 */
function buildGemMonoSVG(w, h) {
  const vw = w || 10;
  const vh = h || 14;
  const cx = vw / 2;
  const cy = vh / 2;
  const t  = `${cx},0`;
  const r  = `${vw},${cy}`;
  const b  = `${cx},${vh}`;
  const l  = `0,${cy}`;
  const c  = `${cx},${cy}`;
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${vw} ${vh}" width="${vw}" height="${vh}" aria-hidden="true" focusable="false">
    <polygon points="${t} ${l} ${c}" fill="var(--gem-mono-tl)"/>
    <polygon points="${t} ${r} ${c}" fill="var(--gem-mono-tr)"/>
    <polygon points="${l} ${b} ${c}" fill="var(--gem-mono-bl)"/>
    <polygon points="${r} ${b} ${c}" fill="var(--gem-mono-br)"/>
  </svg>`;
}

/* === SECTION: wordmark-builder ===
 * PARAGON 워드마크 렌더
 * P◇RAGON — 두 번째 셀(A 위치)이 보석 마크
 * §2.1: 7글자 균등 셀, weight 500, 전체 대문자, 시스템 산세리프
 * 브랜드존 규칙: 데이터색(등락색) 미사용 */

function buildWordmark() {
  /* "PARAGON" 분해: P, [gem], R, A, G, O, N
     첫 번째 A를 보석으로 교체 */
  const letters = ['P', null, 'R', 'A', 'G', 'O', 'N'];
  const frag = document.createDocumentFragment();

  letters.forEach((ch) => {
    const cell = document.createElement('span');
    if (ch === null) {
      /* 보석 셀 */
      cell.className = 'wordmark-gem';
      cell.innerHTML = buildGemSVG(10, 14);
    } else {
      cell.className = 'wordmark-letter';
      cell.textContent = ch;
    }
    frag.appendChild(cell);
  });

  return frag;
}

/* === SECTION: render-header ===
 * 오너 정제 2: 1줄 통합 헤더
 * 좌→우: 워드마크 · 장상태+시각"기준" (.header-status-text) · 배지슬롯 · + 버튼
 * 예: "장중 14:23:05 기준" / "장마감 종가 기준" / "장전 14:23:05 기준" */

function renderHeader() {
  const ms         = STATE.marketState;
  const ls         = STATE.listState;
  const statusText = document.getElementById('header-status-text');
  const badgeSlot  = document.getElementById('header-badge-slot');
  const alertBanner = document.getElementById('header-alert');

  /* 통합 상태 텍스트: "장중 14:23:05 기준" / "장마감 종가 기준" / "장전 14:23:05 기준" */
  const marketLabel = COPY.market[ms] || COPY.market.open;
  if (ms === 'closed') {
    statusText.textContent = `${marketLabel} ${COPY.header.closingRef}`;
  } else {
    statusText.textContent = `${marketLabel} ${COPY.header.updated(nowHHMMSS())}`;
  }

  /* 배지 슬롯 초기화 */
  badgeSlot.innerHTML = '';
  alertBanner.className = 'header-alert';
  alertBanner.innerHTML = '';
  alertBanner.style.display = 'none';

  if (ls === 'ws-disconnected') {
    const badge = document.createElement('span');
    badge.className = 'status-badge warning';
    badge.setAttribute('aria-label', COPY.status.wsDisconnected);
    badge.textContent = '⚠';
    badgeSlot.appendChild(badge);
    alertBanner.className = 'header-alert warning';
    alertBanner.textContent = COPY.status.wsDisconnected;
    alertBanner.style.display = 'flex';

  } else if (ls === 'token-refreshing') {
    const spinner = document.createElement('span');
    spinner.className = 'status-spinner';
    spinner.setAttribute('aria-label', COPY.status.tokenRefreshing);
    badgeSlot.appendChild(spinner);
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
    const badge = document.createElement('span');
    badge.className = 'status-badge error';
    badge.setAttribute('aria-label', COPY.status.networkError);
    badge.textContent = '!';
    badgeSlot.appendChild(badge);
    alertBanner.className = 'header-alert network-error';
    const msgSpan = document.createElement('span');
    msgSpan.className = 'network-error-msg';
    msgSpan.textContent = COPY.status.networkError;
    const retryBtn = document.createElement('button');
    retryBtn.className = 'btn-network-retry';
    retryBtn.textContent = COPY.status.networkRetry;
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

/* === SECTION: render-list ===
 * 오너 오버라이드 3: .row-price 등락색 적용
 * 오너 오버라이드 4: .row-change 2단 스택 렌더
 *   1단: 등락률 (.change-pct)
 *   2단: ▲▼- + 등락액 절대값 (.change-amt-line)
 *   3중 인코딩(색+부호(%의-)+심볼(▼)) 유지 */

function renderList() {
  const listEl = document.getElementById('symbol-list-container');
  listEl.innerHTML = '';

  if (STATE.listState === 'loading') {
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

    /* 등락액: 절대값 + 천단위 콤마. 부호는 방향심볼이 표현 */
    const amtDisplay = fmtAmtAbs(sym.changeAmt);

    row.innerHTML = `
      <span class="row-name">${sym.name}</span>
      ${closingBadge}
      <div class="row-data">
        <span class="row-price ${sym.dir}">${fmtPrice(sym.price)}</span>
        <span class="row-change ${sym.dir}">
          <span class="change-pct">${fmtPct(sym.changePct)}</span>
          <span class="change-amt-line">${fmtSymbol(sym.dir)} ${amtDisplay}</span>
        </span>
      </div>
      <button
        class="btn-delete-row"
        aria-label="${COPY.a11y.deleteSymbol(sym.name)}"
        data-code="${sym.code}"
      >×</button>
    `;

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
 * 오너 오버라이드 4: 등락액도 함께 갱신 */

function triggerHighlight(code, dir) {
  const row = document.querySelector(`.symbol-row[data-code="${code}"]`);
  if (!row) return;

  row.classList.remove('highlight-up', 'highlight-down');
  void row.offsetWidth; /* force reflow */

  const cls = dir === 'up' ? 'highlight-up' : 'highlight-down';
  row.classList.add(cls);

  if (STATE.highlightTimers[code]) {
    clearTimeout(STATE.highlightTimers[code]);
  }

  STATE.highlightTimers[code] = setTimeout(() => {
    row.classList.remove(cls);
    delete STATE.highlightTimers[code];
  }, 300);
}

/* 자동 하이라이트 데모: 2초마다 랜덤 행 값 변경 시뮬레이션
 * 오너 오버라이드 4: pct·symbol·등락액 모두 갱신 */
function startHighlightDemo() {
  stopHighlightDemo();
  STATE.highlightDemo = setInterval(() => {
    if (STATE.view !== 'list' || STATE.listState !== 'normal' || STATE.symbols.length === 0) return;
    const idx = Math.floor(Math.random() * STATE.symbols.length);
    const sym = STATE.symbols[idx];
    const dir = Math.random() > 0.5 ? 'up' : 'down';
    const delta = Math.round(sym.price * 0.003 * (dir === 'up' ? 1 : -1));
    sym.price     += delta;
    sym.changeAmt += delta;
    sym.changePct  = parseFloat((sym.changePct + (dir === 'up' ? 0.05 : -0.05)).toFixed(2));
    sym.dir        = dir;

    const row = document.querySelector(`.symbol-row[data-code="${sym.code}"]`);
    if (row) {
      /* 현재가 + 색 */
      const priceEl   = row.querySelector('.row-price');
      /* 등락 컨테이너 */
      const changeEl  = row.querySelector('.row-change');
      /* 1단: 등락률 */
      const pctEl     = row.querySelector('.change-pct');
      /* 2단: 방향심볼 + 등락액 */
      const amtEl     = row.querySelector('.change-amt-line');

      if (priceEl) {
        priceEl.textContent = fmtPrice(sym.price);
        priceEl.className = `row-price ${sym.dir}`;
      }
      if (changeEl) {
        changeEl.className = `row-change ${sym.dir}`;
      }
      if (pctEl) {
        pctEl.textContent = fmtPct(sym.changePct);
      }
      if (amtEl) {
        amtEl.textContent = `${fmtSymbol(sym.dir)} ${fmtAmtAbs(sym.changeAmt)}`;
      }
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
  const input     = document.getElementById('add-input');
  const errorEl   = document.getElementById('add-error');
  const submitBtn = document.getElementById('btn-submit');
  const code      = input.value.trim().toUpperCase();

  input.classList.remove('has-error');
  errorEl.classList.remove('visible');
  errorEl.textContent = '';

  if (!code) return;

  if (STATE.symbols.length >= 20) {
    showAddError(input, errorEl, COPY.error.limitExceeded);
    return;
  }

  if (STATE.symbols.find((s) => s.code === code)) {
    showAddError(input, errorEl, COPY.error.duplicate);
    return;
  }

  if (!/^\d{6}$/.test(code)) {
    showAddError(input, errorEl, COPY.error.invalidCode);
    return;
  }

  STATE.addLoading = true;
  submitBtn.disabled = true;
  submitBtn.classList.add('loading');

  setTimeout(() => {
    STATE.addLoading = false;
    submitBtn.disabled = false;
    submitBtn.classList.remove('loading');

    const newSym = {
      code,
      name:      `종목 ${code}`,
      price:     50000,
      changePct: 0.00,
      changeAmt: 0,
      dir:       'neutral',
    };
    STATE.symbols.push(newSym);
    switchView('list');
  }, 800);
}

function showAddForm_errorByKey(key) {
  const input   = document.getElementById('add-input');
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

  const addBtn = document.getElementById('btn-add-header');
  const headerStatusText = document.getElementById('header-status-text');

  if (view === 'add') {
    /* add 뷰: 상태텍스트를 "종목 추가"로 교체, + 버튼 숨김 */
    headerStatusText.textContent = COPY.addForm.title;
    addBtn.style.display = 'none';
    const input = document.getElementById('add-input');
    if (input) setTimeout(() => input.focus(), 50);
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
          renderHeader();
          renderList();
          startHighlightDemo();
        }, 1500);
      } else {
        renderList();
        if (STATE.listState === 'normal') startHighlightDemo();
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
 * 브라우저 데모용 상태 셀렉터 */

const DEMO_STATES = [
  { label: 'W1 빈 상태',         action: () => setDemoState('empty') },
  { label: 'W2 장중 목록',       action: () => setDemoState('list-open') },
  { label: 'W2 로딩',           action: () => setDemoState('list-loading') },
  { label: 'W2 연결 끊김',       action: () => setDemoState('list-ws-disconnected') },
  { label: 'W2 인증 갱신 중',    action: () => setDemoState('list-token-refreshing') },
  { label: 'W2 인증 실패',       action: () => setDemoState('list-auth-failed') },
  { label: 'W2 네트워크 오류',   action: () => setDemoState('list-network-error') },
  { label: 'W2 장전',           action: () => setDemoState('list-preOpen') },
  { label: 'W2 장마감',         action: () => setDemoState('list-closed') },
  { label: 'W3 종목 추가',       action: () => setDemoState('add') },
  { label: 'W3 에러: 잘못된코드', action: () => setDemoState('add-error-invalidCode') },
  { label: 'W3 에러: 중복',      action: () => setDemoState('add-error-duplicate') },
  { label: 'W3 에러: 한도초과',  action: () => setDemoState('add-error-limitExceeded') },
  { label: 'W3 에러: 네트워크',  action: () => setDemoState('add-error-network') },
  { label: '토스트 데모',        action: () => setDemoState('toast-demo') },
];

function setDemoState(key) {
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

function initWordmark() {
  /* 워드마크 슬롯에 동적 렌더 */
  const slot = document.getElementById('wordmark-slot');
  if (!slot) return;
  slot.appendChild(buildWordmark());

  /* 빈 상태 보석 아이콘 — 브랜드 일관성 (오너 오버라이드 2 권장사항) */
  const gemEl = document.getElementById('empty-gem-icon');
  if (gemEl) {
    gemEl.innerHTML = buildGemSVG(18, 24);
  }

  /* 메뉴바 시뮬레이션 모노크롬 보석 아이콘 (오너 정제 3) */
  const monoSlot = document.getElementById('menubar-gem-mono');
  if (monoSlot) {
    monoSlot.innerHTML = buildGemMonoSVG(10, 14);
  }
}

function initDemoControls() {
  const container = document.getElementById('demo-controls');
  const stateKeys = [
    'empty','list-open','list-loading','list-ws-disconnected',
    'list-token-refreshing','list-auth-failed','list-network-error',
    'list-preOpen','list-closed',
    'add','add-error-invalidCode','add-error-duplicate','add-error-limitExceeded',
    'add-error-network','toast-demo',
  ];
  DEMO_STATES.forEach(({ label, action }, i) => {
    const btn = document.createElement('button');
    btn.className = 'demo-btn';
    btn.textContent = label;
    btn.dataset.key = stateKeys[i];
    btn.addEventListener('click', action);
    container.appendChild(btn);
  });
}

function initEventListeners() {
  document.getElementById('btn-add-header').addEventListener('click', () => {
    switchView('add');
  });

  document.getElementById('btn-empty-cta').addEventListener('click', () => {
    switchView('add');
  });

  document.getElementById('btn-submit').addEventListener('click', submitAddForm);

  document.getElementById('btn-cancel').addEventListener('click', () => {
    if (STATE.symbols.length > 0) {
      STATE.listState = 'normal';
      switchView('list');
    } else {
      switchView('empty');
    }
  });

  document.getElementById('add-input').addEventListener('keydown', (e) => {
    if (e.key === 'Enter')  { e.preventDefault(); submitAddForm(); }
    if (e.key === 'Escape') { document.getElementById('btn-cancel').click(); }
  });

  document.getElementById('symbol-list-container').addEventListener('keydown', (e) => {
    if (e.key === 'Delete' || e.key === 'Backspace') {
      const row = document.activeElement.closest('.symbol-row');
      if (row) deleteSymbol(row.dataset.code);
    }
  });
}

document.addEventListener('DOMContentLoaded', () => {
  initWordmark();
  initDemoControls();
  initEventListeners();
  startClock();

  /* 초기 상태: W2 장중 목록 */
  STATE.symbols = [...MOCK_SYMBOLS];
  STATE.listState = 'normal';
  STATE.marketState = 'open';
  switchView('list');

  const firstBtn = document.querySelector('.demo-btn[data-key="list-open"]');
  if (firstBtn) firstBtn.classList.add('active');
});
