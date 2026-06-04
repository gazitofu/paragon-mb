# QA Report — kis-migration Task 5

- 날짜: 2026-06-04
- 태스크: project.yml ATS 예외 + AppDelegate KIS 전환 + QuoteService 타입 참조 갱신 (T9+T10)
- 모드: Strict (Auto-Strict: auth/env config 접점)
- 변경 파일: project.yml / App/AppDelegate.swift / Sources/PMCore/Service/QuoteService.swift / docs/OPERATIONAL_NOTES.md
- 선행: reviewer 치명 0 / 권장 0 PASS

## 수용 기준 표

| # | 항목 | 결과 | 비고 |
|---|---|---|---|
| 1 | swift test PMCore 83개 전원 통과 | PASS | 83케이스, exit=0 |
| 2 | xcodebuild test (fresh -derivedDataPath) AppTests 11케이스 빌드+통과 | PASS | TEST SUCCEEDED, exit=0 |
| 3 | ATS Info.plist — ops.koreainvestment.com NSExceptionDomains 존재 | PASS | plutil 확인 |
| 4 | ATS Info.plist — NSAllowsArbitraryLoads 전역 개방 부재 | PASS | grep 0건 |
| 5 | V-B2 env 직접 읽기 흔적 (App/ + Sources/) 0건 | PASS | grep 0건 |
| 6 | V-B2 자격증명 print/로깅 0건 | PASS | grep 0건 |
| 7 | AppDelegate Kiwoom* 참조 잔존 0건 (신규 추가 기준) | PASS | diff +라인 grep 0건 |
| 8 | AppDelegate KISCredential 호출 존재 | PASS | appKey·appSecret·issueToken·issueApprovalKey·lookupName 확인 |
| 9 | scope 잠금 — ViewModel·View diff 0건 | PASS | git diff --stat HEAD: ViewModel/View 0 diff |

## 검증 항목별 상세

### 항목 1+2: 풀 회귀 (PMCore 83개 + AppTests 11개)

실행 명령:
```
xcodegen generate                                  # 재생성
swift test                                         # PMCore 83케이스
xcodebuild test -scheme PARAGON-MB -configuration Debug -derivedDataPath /tmp/qa-task5-dd
```

결과:
- swift test exit=0, 83 Test Cases passed, log: /tmp/qa-task5-swifttest-1780560224.log
- xcodebuild exit=0, ** TEST SUCCEEDED **, 11케이스 전원 passed, log: /tmp/qa-task5-xcodebuild-1780560415.log
- AppTests: AppSmokeTests 1 + WatchlistViewModelRefreshTests 10 = 11케이스
- 캐시 우회: rm -rf /tmp/qa-task5-dd 후 fresh 실행 (T2 attempt1 교훈 적용)

### 항목 3+4: ATS Info.plist 반영 검증

```
plutil -p App/Info.plist
```

출력:
```
"NSAppTransportSecurity" => {
  "NSExceptionDomains" => {
    "ops.koreainvestment.com" => {
      "NSExceptionAllowsInsecureHTTPLoads" => true
    }
  }
}
```

- NSExceptionDomains → ops.koreainvestment.com 존재: PASS
- NSAllowsArbitraryLoads 전역 키: 부재 (grep 0건) PASS

### 항목 5+6: V-B2 사전 체크 (정적)

```
grep -rn "api\.env|KIS_APP_KEY|KIS_APP_SECRET|\.env" App/ Sources/ (tools/ 제외): 0건
grep -rn "print|NSLog|os_log|Logger" App/ Sources/ | grep -i "appKey|token|credential": 0건
```

env 직접 읽기 0건, 자격증명 로깅 0건 — V-B2 정적 통과.

### 항목 7+8: 조립 정합 (AppDelegate)

AppDelegate diff +라인 Kiwoom 참조: 0건 (신규 추가 없음)

제거된 Kiwoom 참조 (diff -라인):
- KiwoomEnvironment.real / KiwoomRESTClient / KiwoomCredential.appKey·appSecret / KiwoomRESTClient.RESTError

존재하는 KIS 호출 (현재 파일):
- KISCredential.appKey / KISCredential.appSecret (line 21-22)
- rest.issueToken(appKey:appSecret:) (line 26)
- rest.issueApprovalKey(appKey:appSecret:) (line 32)
- rest.lookupName(code:token:appKey:appSecret:) (line 47)

### 항목 9: scope 잠금 (V-C4 사전 체크)

git diff --stat HEAD 변경 파일:
- App/AppDelegate.swift (태스크 대상)
- Sources/PMCore/Service/QuoteService.swift (태스크 대상)
- docs/OPERATIONAL_NOTES.md (태스크 대상)
- docs/sprints/SPRINT_PLAN.md (sprint docs)
- project.yml (태스크 대상)

ViewModel / View / DesignTokens / Quote / PriceDirection / MarketClock: diff 0건 — V-C4 PASS

## 비고

- AddSymbolViewModel.swift의 주석(`KiwoomRESTClient.RESTError` 언급)은 미변경 레거시 텍스트 — 이번 태스크 scope 외, 차후 정리 대상.
- Sources/PMCore 내 Kiwoom* 파일(KiwoomEnvironment·KiwoomRESTClient·KiwoomWebSocketClient·KiwoomQuoteParser·KiwoomCredential)은 design.md §전략 "검증 완료 후 정리" 방침에 따라 병존 유지. closeout 시 삭제 예정.

## Units & Signs Audit (PASS 직전 확인)

본 태스크 변경 영역은 조립 루트(DI 배선) + ATS config. 신규 수치 연산/단위 변환 없음.
QuoteService 타입 참조 갱신은 KISRESTClient·KISWebSocketClient 타입명 교체이며 수치 계산 미포함.
Task 3 Audit 7행 (ms·price·change·sign·ratio·expiry·marketClock) 전수 테스트 잠금 — 회귀 0건 확인.

## 최종 판정

**PASS — 전항목 통과**

라이브 검증(V-A*)은 오너 게이트로 본 QA 범위 외.
