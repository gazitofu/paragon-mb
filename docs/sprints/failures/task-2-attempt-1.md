# Task 2 실패 리포트 — attempt 1

- 일자: 2026-06-01
- 태스크: Task 2 (Xcode unit test 타겟 신설, 인프라)
- 시도: 1

## 증상

`xcodebuild test -scheme PARAGON-MB` 실행 시 빌드 단계에서 code sign 에러로 중단. 테스트 케이스 실행에 도달하지 못함.

```
error: Cannot code sign because the target does not have an Info.plist file
and one is not being generated automatically.
Apply an Info.plist file to the target using the INFOPLIST_FILE build setting
or generate one automatically by setting the GENERATE_INFOPLIST_FILE build setting to YES
(recommended). (in target 'PARAGON-MBTests' from project 'PARAGON-MB')
```

## 실패 검증 항목

| 검증 기준 | 결과 |
|---|---|
| `xcodegen generate` EXIT=0 | PASS |
| `xcodebuild test -scheme PARAGON-MB` 스모크 PASS | **FAIL** |
| `swift test` 회귀 없음 | PASS |

## 로그

- xcodegen: `/tmp/qa-task2-xcodegen-1780321902.log` — 4줄, EXIT=0
- xcodebuild: `/tmp/qa-task2-xcodebuild-1780322086.log` — 60줄, EXIT=1
- swift test: `/tmp/qa-task2-swift-test-1780322165.log` — 130줄, EXIT=0

## 영향 파일

- `/Users/gazitofu/Developer/PARAGON-MB/project.yml` — `PARAGON-MBTests` 타겟 settings에 `GENERATE_INFOPLIST_FILE` 또는 `INFOPLIST_FILE` 키 부재

## 확인된 사실

- `project.yml` PARAGON-MBTests settings 블록에 `GENERATE_INFOPLIST_FILE: YES` 및 `INFOPLIST_FILE` 키가 모두 없음
- `xcodegen generate`로 생성된 xcodeproj의 PARAGON-MBTests Debug/Release 빌드 설정 양쪽에 해당 키 미포함 확인
- App 타겟(PARAGON-MB)은 `info.path: App/Info.plist`로 명시되어 있으나 테스트 타겟은 별도 설정 없음
- OPERATIONAL_NOTES에는 "xcodebuild test 성공"으로 기록되어 있으나 실제 현재 project.yml 상태로는 재현 불가
