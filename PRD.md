# Dictation Loop — 기획서

## 1. 배경 / 문제 정의

영어 학습자는 보통 Listening / Writing / Speaking을 따로따로 연습한다. 하지만 한 문장을 갖고 **"받아쓰기 → 정답 확인 → 따라 말하기"** 루프를 돌면 세 영역을 동시에 단련할 수 있다는 것이 알려진 학습법이다 ([dailydictation.com](https://dailydictation.com) 의 "200% 활용법").

문제는 이 학습법이 **고도의 자기 통제와 꾸준함**을 요구한다는 것이다:
- 정답을 너무 빨리 보면 안 됨 (Writing 효과 ↓)
- 셰도잉을 매 문장 2-3회 강제해야 함 (Speaking 효과 ↓)
- 1.0x 한 번, 1.5x 한 번 — 두 번 돌려야 함 (대부분 한 번 듣고 끝냄)
- Full transcript는 가장 마지막에만 봐야 함
- **하루 분량이 명확하지 않으면 학습이 산발적으로 끊긴다** — 한 번에 너무 많이 하거나 며칠 안 하거나
- **틀린 문장을 다시 안 풀면 같은 실수 반복**

웹 인터페이스(dailydictation.com)는 이 모든 걸 사용자 의지에 맡긴다.

## 2. 솔루션 / 핵심 가치

**"200% 활용법을 앱이 강제로 시키고, 매일 일정량을 자동 배분해주고, 틀린 건 따로 모아 다시 풀게 하는" 모바일 앱.**

기존 dailydictation.com 콘텐츠를 활용하되, UI / UX 레이어에서 학습 루프 + 일일 페이싱 + 오답 복습을 강제한다:

1. **루프 강제**: Transcript 잠금 / 정답 잠금 / 셰도잉 카운터 / 속도 라운드 (1.0x → 1.5x)
2. **일일 페이싱**: 하루 10문장 자동 배분. 전날 끝낸 곳부터 이어서. 사용자가 고르지 않음.
3. **오답 복습**: 1.0x·1.5x 두 라운드에서 모두 틀린 문장을 별도 오답노트로 모아 재학습.
4. **시각적 동기**: 캘린더에서 일자별 완수 여부를 한눈에. 빈 칸을 채워나가는 만족감.

## 3. 타겟 사용자

- 영어 받아쓰기 학습법을 알지만 혼자선 루프를 못 지키는 학습자
- IELTS / TOEIC / TOEFL 등 시험 청취 대비 중인 사람
- 출퇴근·자투리 시간에 **하루 정해진 분량**을 끊어 가는 학습자
- 새 콘텐츠를 매일 직접 고르기 귀찮아 학습이 끊기는 사람

## 4. 핵심 사용자 플로우

### 4-1. 일일 학습 모드 (메인)

```
홈 (캘린더)
  └─ 오늘 칸 클릭 (또는 "오늘 시작" 버튼)
       └─ 일일 학습 세션 (오늘의 10문장)
            ├─ 1.0x 라운드 — 10문장
            │    └─ 문장당: 듣기 → 받아쓰기 → 채점 → 셰도잉 → 다음
            ├─ 라운드 완료 → 1.5x 시작 안내
            ├─ 1.5x 라운드 — 같은 10문장
            │    └─ 1.0x·1.5x 둘 다 틀린 문장은 오답노트 자동 등록
            └─ 1.5x 완료 → 캘린더 오늘 칸 ✓ 표시 / cursor 다음 10문장으로 진행
```

### 4-2. 자유 학습 모드 (보조)

기존 카테고리 진입 흐름 유지. 일일 페이싱과 무관하게 사용자가 원하는 레슨을 직접 푼다.

### 4-3. 오답노트 모드

```
홈 (오답노트 카드, N문장 표시)
  └─ 오답노트 진입
       └─ 문장 리스트
            └─ 풀기 → 정답 시 오답에서 제거 / 오답 시 유지
```

## 5. 주요 기능

### 5-1. 200% 활용법 매핑 (기존)

| # | 활용법 단계 | 앱 기능 |
|---|---|---|
| 1 | 카테고리 클릭 | 8개 카테고리 / 또는 **일일 학습**(자동 시퀀스) |
| 2 | Dictation 먼저 | Transcript 메뉴 자물쇠 |
| 3 | 첫 dictation 2-3회 듣기 (1.0x) | 재생 카운터 |
| 4 | 정답 보지 말고 받아쓰기 | TextField — Reveal 전 정답 숨김 |
| 5 | 정답 공개 후 셰도잉 2-3회 | "Shadow practice 0/3" 카운터 |
| 2~5 | 한 문장 루프 | Reveal 후에만 Next 활성화 |
| 6 | 1.0x 완료 → 1.5x 재반복 | 라운드 종료 다이얼로그 |
| 7 | Full transcript는 마지막 | 1.5x 완료 시점 잠금 해제 |

### 5-2. 정답 채점 (NEW)

- **비교 규칙**: 입력 vs 정답을 다음 normalize 후 비교한다.
  - 대소문자 무시 (`Hello` == `hello`)
  - 마침표 `.` 무시 (`Hi.` == `Hi`)
  - 다중 공백 → 단일 공백 / 양끝 trim
  - 그 외 구두점(쉼표, 물음표 등)은 일단 유지하여 채점 (Phase 2에서 정책 조정 가능)
- **결과 표시**: Reveal 시 정답 카드 + 사용자 입력 카드. 단어 단위 diff로 OK/틀림 하이라이트.
- **저장**: 문장 단위 결과 (sentenceId × 라운드 → bool)

### 5-3. 일일 학습 / 캘린더 (NEW)

**일일 분량**: 10문장 / 일

**Cursor 정책**:
- 카테고리 우선순위 = `kCategories` 순서 (Short Stories → Daily Conversations → TOEIC → YouTube → IELTS → TOEFL → Spelling Names → Numbers)
- 각 카테고리 안에서는 사이트 노출 순서대로 레슨 진행
- 한 레슨 끝나면 같은 카테고리의 다음 레슨, 카테고리 끝나면 다음 카테고리
- **하루 10문장이 한 레슨에 안 들어가면 다음 레슨으로 자연스레 넘어감** (10문장 = 1.0x + 1.5x 두 번이므로 실 문장 학습 횟수는 20)

**일자별 set 보존**:
- 첫 진입 시 cursor에서 다음 10문장을 추출 → `dailySets[YYYY-MM-DD]`로 저장
- 같은 날 다시 들어와도 같은 set 유지 (랜덤 갱신 X)
- 10문장 모두 1.5x까지 끝낸 시점에 cursor 진행 + 캘린더 ✓

**캘린더 UI**:
- 월간 7×6 그리드
- 미래 날짜: 비활성
- 오늘: 강조 + 진행도(`x/10`)
- 과거 완료(10/10): ✓ + 채워진 색
- 과거 부분 완료: 부분 색칠 / 점
- 과거 미진행: 빈 칸
- 오늘 클릭 → 일일 학습 세션 진입
- 과거 클릭 → 그 날의 set read-only 보기 (Phase 2에서 재학습 가능 검토)

### 5-4. 단어 뜻 즉시 표시 (NEW)

채점 후 **틀린 단어를 탭하면** 그 단어의 뜻을 작은 sheet로 즉시 표시한다.

**소스**: Claude API (Haiku 4.5) — 영한 뜻 + 영영 뜻 + 예문 2개를 한 호출에 받는다.

**모델 선정 근거**:
- Haiku 4.5 = 입력 $1 / 출력 $5 (1M 토큰당). 단어 1회 룩업 ≈ $0.0015
- 단어 룩업은 가벼운 task — Opus/Sonnet 불필요
- 응답 속도 빠름 (UX에 직결)

**JSON 강제 방식**: `output_config.format` (Structured Outputs)
- Assistant prefill / tool use / system 지시문보다 안정적이고 확장성 좋음
- 첫 text 블록이 valid JSON 보장
- 응답 스키마: `{ko: string, en: string, examples: string[]}`
- "exactly 2개"는 스키마로 강제 못 함 (숫자 제약 미지원) → system prompt + 클라이언트 검증

**캐싱 전략**: prompt caching X, 결과 캐시 O
- Haiku 4.5 최소 캐시 prefix = 4096 토큰. 짧은 system prompt(~150 토큰)는 임계 미달 → silent miss
- 대신 **결과를 SharedPreferences에 영구 저장** (`word.toLowerCase()` 키로)
- 같은 단어 두 번째부터는 API 호출 X, 오프라인에서도 작동

**API 키 관리**: `.env` 파일에 `ANTHROPIC_API_KEY` 보관, `flutter_dotenv`로 로드. `.gitignore`로 git 커밋 차단.

### 5-5. 단어장 (NEW)

5-4의 룩업 sheet 하단에 **"단어장에 추가"** 버튼이 있다. 사용자가 명시적으로 누른 단어만 단어장에 들어간다 (자동 수집 X — 의미 있는 큐레이션을 위해).

**설계 결정 — 자동 수집 X / 수동 추가 O**:
- 매 오답 단어를 자동 수집하면 단어장이 노이즈로 가득 참 (오타, 단순 실수, 이미 아는 단어)
- 사용자가 "이 단어는 진짜 모르겠다" 판단 후 명시적으로 추가하면 단어장 품질이 보장됨
- 학습 효과 = 수집량이 아니라 복습 빈도 × 단어 품질

**저장**: SharedPreferences `dd_dict_saved_v1` (`Set<String>`, 소문자 단어 키)
- 5-4의 lookup 캐시(`dd_dict_cache_v1`) 위에 saved 플래그만 얹는 구조 — 데이터 중복 X
- 단어장 진입 시 `_saved` 키로 캐시에서 entry 조회

**UI**:
- 5-4 sheet에 토글 버튼: 미저장 시 "단어장에 추가"(filled), 저장됨 시 "Saved — tap to remove"(outlined)
- 홈 화면에 "단어장 · N words" 카드
- 단어장 화면: 검색 + 카드 리스트 (단어 / 한국어 뜻 / 영영 뜻 / 예문 2개) + 삭제 버튼

### 5-6. 오답노트 (NEW)

**등록 조건**: 같은 문장에서 **1.0x 라운드와 1.5x 라운드 모두 오답** → wrongs에 추가

**제거 조건**: 오답노트 화면에서 다시 풀어 정답 → wrongs에서 제거

**저장 형태**: `Set<sentenceId>` (sentenceId = `{exercisePath}#{position}`)

**UI**:
- 홈 화면에 카드: "오답노트 (N문장)" — N>0일 때만 표시
- 진입 시 문장 리스트
- 풀기 화면은 일일 학습과 같은 패턴 (받아쓰기 → 채점 → 다음). 라운드 개념 X — 한 번에 정답이면 제거.

## 6. 보조 기능

- **Recent 목록** — 홈에 최근 학습 레슨 3개
- **진행도 배지** — 레슨 리스트에서 1.0x / 1.5x 완료 여부
- **즐겨찾기** (P2 UI 노출)
- **카테고리 메타** — 어휘 레벨, 파트 수, 섹션

## 7. 화면 구성

| 화면 | 역할 |
|---|---|
| **HomeScreen** | 통계 배지(🔥📚📝) → 월간 캘린더 → Today 카드 → 오답노트(있을 때) → 단어장 → Favorites → Recent → 카테고리 |
| **DailySessionScreen** | 오늘의 10문장 학습. 1.0x → 1.5x 두 라운드. 오답 자동 등록 |
| **WrongAnswersScreen** | 오답노트 리스트 + 풀이 |
| **WordbookScreen** | 단어장 — 사용자가 수동 추가한 단어 카드 리스트 + 검색 + 삭제 |
| **FavoritesScreen** | 별 표시한 레슨 리스트 — 탭하면 학습 진입, 별 끄면 제거 |
| **ExerciseListScreen** | 한 카테고리 내 레슨 리스트 + 진행도 배지 + 별 토글 |
| **StudySessionScreen** | 자유 학습 모드 (한 레슨 단위, 1.5x는 1.0x 완료 전 잠금) |
| **DictionarySheet (모달)** | 5-4 단어 뜻 sheet — 영한·영영·예문 + 단어장 토글 |

## 8. 데이터 모델

### 정적
- **Category**, **ExerciseSummary**, **Lesson**, **Challenge** — 기존
- **SentenceRef** (NEW): `{exercisePath, sentenceIdx}` — 일일 set / wrongs용. content/audio는 fetch 시점 lazy.

### 로컬 영속 (SharedPreferences)
- **레슨별 라운드 완료**: `Map<exercisePath, Set<{1.0x|1.5x}>>` (기존)
- **즐겨찾기 / Recent** (기존)
- **wrongs** (NEW): `Set<sentenceId>` — 오답노트
- **dailyCursor** (NEW): `{catSlug, exercisePath, sentenceIdx}` — 다음에 가져올 위치
- **dailySets** (NEW): `Map<YYYY-MM-DD, List<sentenceId>>` — 일자별 10문장
- **dailyCompleted** (NEW): `Map<YYYY-MM-DD, Set<sentenceId>>` — 일자별 완수 문장
- **dictionary cache** (NEW): `Map<word.toLowerCase(), {ko, en, examples[]}>` — Claude API 룩업 결과 영구 캐시
- **dictionary saved** (NEW): `Set<word.toLowerCase()>` — 사용자가 단어장에 명시적으로 추가한 단어

sentenceId 형식: `{exercisePath}#{position}`

## 9. 외부 의존성

- **dailydictation.com** — 콘텐츠
- **Claude API (Haiku 4.5)** — 단어 뜻 + 예문 (5-4) + 발음 평가 한국어 코칭 (4차)
- **Azure Speech (Pronunciation Assessment)** — 음소 단위 발음 점수 (4차)
- **just_audio** — 오디오 재생 + 속도 조절 + 사용자 녹음 재생
- **audio_session** — 오디오 포커스 (다른 앱 음악 ducking)
- **record** — 마이크 녹음 (셰도잉, AAC/M4A)
- **path_provider** — 임시 디렉토리 (녹음 파일)
- **shared_preferences** — 로컬 영속 + 단어 뜻 영구 캐시
- **flutter_dotenv** — API 키 로드 (.env)
- **html / http** — 스크래핑 + Claude API 호출

## 10. 기술 스택

- Flutter 3.10+ (Dart 3)
- Material 3 다크 테마
- 안드로이드 우선

## 11. 개발 단계

### 1차 (완료)
- [x] 8개 카테고리 진입 / 레슨 리스트 스크래핑
- [x] 문장 단위 받아쓰기 + 정답 공개 흐름
- [x] 1.0x → 1.5x 라운드 강제
- [x] Transcript 잠금
- [x] 셰도잉 카운터
- [x] 속도별 진행도 / Recent 저장
- [x] audio_session 통합

### 2차 (완료)
- [x] **정답 채점** — normalize 비교 (대소문자·마침표 무시) + 단어 단위 diff
- [x] **오답노트** — 1.0x·1.5x 둘 다 틀린 문장 자동 등록 / 별도 화면 / 풀이로 제거
- [x] **일일 학습 + 캘린더** — 하루 10문장 자동 시퀀스(전날 이어서) / 월간 캘린더 완수 표시
- [x] **홈 재설계** — 캘린더 + Today + 오답노트 + 단어장 + Recent + 카테고리
- [x] **단어 뜻 즉시 표시 (5-4)** — 받아쓰기 후 틀린 단어 탭 → Claude Haiku 4.5 룩업 sheet (영한·영영·예문 2개) + 결과 영구 캐시 + .env 인프라
- [x] **단어장 (5-5)** — 룩업 sheet 하단의 "단어장에 추가" 버튼으로 명시적 큐레이션. 단어장 화면(검색·삭제). 자동 수집 X.

### 3차 (완료)
- [x] **마이크 녹음 / 재생** — 셰도잉 카드에 Record/Stop + Your voice 버튼. AAC(M4A)로 임시 디렉토리에 문장별 녹음, 재생은 `just_audio` 재사용. 다음 문장으로 넘어가면 자동 reset. Android `RECORD_AUDIO` 권한.
- [x] **1.0x 먼저 강제** — StudySessionScreen의 SegmentedButton에서 1.5x segment를 disabled + 자물쇠 아이콘. 1.0x 라운드 완료 전엔 클릭 시 SnackBar로 안내.
- [x] **즐겨찾기 UI 노출** — 레슨 리스트 / 학습 화면 AppBar에 별 토글. 홈에 "Favorites · N lessons" 카드 + FavoritesScreen (탭하면 학습 진입, 별 끄면 제거).
- [x] **학습 통계 / 스트릭** — 홈 최상단에 통계 배지 행: 🔥 연속일수(오늘 미완료여도 어제 기준으로 살아있음) / 📚 누적 완수일수 / 📝 누적 학습 문장수.

### 4차 (진행 중)
- [x] **AI 발음 평가** — Azure Speech "Pronunciation Assessment" + Claude(Haiku 4.5) 한국어 코칭 조합. 셰도잉 카드의 "Check pronunciation" 버튼으로 진입. 16kHz mono PCM WAV로 별도 녹음(기존 m4a 셰도잉 녹음과 분리) → Azure가 음소(phoneme) 단위로 분석 → `pronunciationScore / accuracyScore / fluencyScore / completenessScore` + 단어별 점수·error type → Claude가 한국 화자 특유 패턴(L/R, TH, 끝자음, 모음 길이) 기준으로 짧은 한국어 코칭 생성. Azure F0 무료 5h/월, 그 이후 $1/h.
- [ ] 오프라인 캐시 (스크래핑 결과 로컬 보관) — 사용자 결정으로 보류 (데이터 환경 좋음)
- [ ] iOS / 웹 빌드
- [ ] 자체 콘텐츠 업로드

### 제외 (구현 안 함)
- ~~구간 반복 / 5초 되감기 단축키~~ — 사용자 요청에 따라 범위에서 제외
- ~~틀린 단어 자동 수집~~ — 5-5 단어장은 자동 수집 대신 사용자가 명시적으로 추가하는 방식으로 결정 (단어장 노이즈 방지)

## 12. 리스크 / 고려사항

| 리스크 | 대응 |
|---|---|
| dailydictation.com HTML 구조 변경 | 스크래퍼 모듈 분리, 단일 진입점 |
| 일일 cursor가 막다른 길에 도달 (모든 카테고리 끝) | 처음으로 순환 (Phase 2에서 안내 다이얼로그) |
| 일일 set이 두 레슨에 걸칠 때 오디오 fetch 비용 | 메모리 캐시로 같은 세션 내 중복 방지 |
| 채점 normalize가 너무 관대/엄격 | 1차는 대소문자·마침표만 무시. 사용자 피드백 기반 조정 |
| 하루 10문장 ≠ 한 레슨 단위 → 기존 "레슨 완료" 진행도와 충돌 | 일일 모드와 자유 모드의 진행도를 별개로 보관 |
| 사용자가 며칠 비우면 cursor가 너무 밀림 | cursor는 시간이 아닌 학습량 기반 — 빈 날은 그냥 빈 칸으로 남음 (FOMO 유발) |
| 스크래핑 정책 / 음원 저작권 | 비상업 학습 용도, 다운로드·재배포 X |

## 13. 성공 지표 (가설)

- 일일 10문장 완수일 비율 ≥ 50% (앱 사용일 기준)
- 한 세션에서 1.0x → 1.5x 완주율 ≥ 70%
- 오답노트 재정답률 ≥ 60%
- 7일 리텐션 ≥ 30%
- 30일 리텐션 ≥ 15%
