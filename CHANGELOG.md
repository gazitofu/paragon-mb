# Changelog

## [Unreleased]
- feat: 앱 아이콘 추가 — 브랜드 4면 컷 보석 마크 (Midnight 라운디드 스퀘어, Finder·Launchpad 노출)

## [0.1.0] - 2026-06-05
- fix: KRX 알파뉴메릭 티커(예: 에임드바이오 0009K0) 종목 추가 입력 허용 — 숫자-only 검증을 영숫자로 확장, 소문자 자동 대문자화
- chore: 키움 legacy 제거 — 소스 4파일·테스트 9건·PoC 도구 3종·API_SPEC 부록·Keychain 항목 일괄 정리 (KIS 전환 종결 cleanup)
- feat: 시세 데이터 제공자를 키움증권에서 한국투자증권(KIS) Open API로 전환 — 지정단말기(8050) 제약 제거, 외부 네트워크에서도 시세 조회 가능
- feat: 팝오버 헤더에 수동 새로고침 버튼 추가 — authFailed 등 막힌 상태도 앱 재시작 없이 복구 (⌘R)
- init: PARAGON-MB 프로젝트 초기화 (Vault·Git 분리 부트스트랩)
