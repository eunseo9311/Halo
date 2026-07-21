# Halo — Project Conventions

## 1. Git Branch Strategy

```
main          ← production-ready, protected
develop       ← integration branch (default PR target)
feature/*     ← new features  (e.g. feature/route-scoring)
fix/*         ← bug fixes     (e.g. fix/segment-null-score)
chore/*       ← tooling, deps (e.g. chore/upgrade-flutter)
```

- **Never commit directly to `main` or `develop`**
- Branch from `develop`, PR back to `develop`
- `develop` → `main` via release PR only

## 2. Commit Message Convention (Conventional Commits)

```
<type>(<scope>): <short summary>

[optional body]
[optional footer]
```

**Types:** `feat` | `fix` | `docs` | `style` | `refactor` | `test` | `chore`

**Scopes:** `app` | `server` | `data` | `schema` | `ci` | `docker`

**Examples:**
```
feat(app): add route map screen with color-coded segments
fix(server): handle null WSI score in segment response
chore(data): add ruff lint config
docs(schema): add V1 migration for street_segments table
```

Rules:
- Summary in **imperative mood**, lowercase, no period
- Max 72 chars per line
- Reference GitHub issues: `fixes #42` in footer

## 3. Pull Request Rules

**Title format:** same as commit message (`type(scope): summary`)

**Checklist before merge:**
- [ ] Self-reviewed the diff
- [ ] No secrets or `.env` files committed
- [ ] Tests pass (or noted why skipped for scaffold PRs)
- [ ] `develop` branch merged in (no conflicts)
- [ ] `CONVENTIONS.md` followed

**PR size:** aim for < 400 lines changed. Split large features into smaller PRs.

## 4. Naming Conventions

### Flutter (`app/`)
| Kind | Convention | Example |
|---|---|---|
| File | `snake_case.dart` | `route_map_screen.dart` |
| Class | `UpperCamelCase` | `RouteMapScreen` |
| Variable/function | `lowerCamelCase` | `segmentScore` |
| Constant | `lowerCamelCase` | `defaultZoom` |
| Provider | `<noun>Provider` | `segmentScoreProvider` |

### Spring Boot (`server/`)
| Kind | Convention | Example |
|---|---|---|
| Package | `lower.dot.case` | `com.safesoundla.halo.domain` |
| Class | `UpperCamelCase` | `SegmentScoreService` |
| DTO | `<Entity>Request` / `<Entity>Response` | `SegmentScoreResponse` |
| Repository | `<Entity>Repository` | `SegmentScoreRepository` |
| Controller | `<Entity>Controller` | `SegmentScoreController` |

### Python (`data/`)
| Kind | Convention | Example |
|---|---|---|
| Module/file | `snake_case.py` | `wsi_calculator.py` |
| Class | `UpperCamelCase` | `WsiCalculator` |
| Function/variable | `snake_case` | `calculate_score` |
| Constant | `UPPER_SNAKE_CASE` | `MAX_LIGHTING_SCORE` |

PEP 8 enforced via `ruff`.

## 5. Folder Structure Principle

**Feature-first** (for `app/`) — group by feature, not by layer:

```
lib/
  core/           ← cross-cutting (network, router, theme)
  features/
    route_map/
      data/       ← repository, data source, models
      domain/     ← entities (if needed)
      presentation/ ← screens, widgets, providers
    wsi_score/
      data/
      presentation/
```

**Layer-first** (for `server/`) — domain-driven layers:

```
src/main/kotlin/com/safesoundla/halo/
  domain/         ← entities, value objects (no framework deps)
  application/    ← use cases, service logic
  infrastructure/ ← JPA repos, external clients
  presentation/   ← controllers, DTOs, exception handlers
```

**Layer-first** (for `data/`) — pipeline stages:

```
src/halo_data/
  ingestion/   ← fetch & store raw data from external sources
  processing/  ← clean, transform, join datasets
  scoring/     ← WSI calculation logic
```

## 6. Secrets & Environment Variables

**Rule: never commit secrets.** `.gitignore` covers all `.env*` and profile YAMLs with credentials.

| Component | Mechanism | File |
|---|---|---|
| Flutter | `.env` + `flutter_dotenv` | `app/.env` (gitignored) |
| Spring | `application-{profile}.yml` | `server/src/main/resources/application-local.yml` (gitignored) |
| Python | `.env` + `python-dotenv` | `data/.env` (gitignored) |

Copy from `.env.example` to get started:
```bash
cp app/.env.example app/.env
cp server/src/main/resources/application-local.yml.example server/src/main/resources/application-local.yml
cp data/.env.example data/.env
```

## 7. DB Toggle (`halo.db.enabled`)

**PostgreSQL/JPA/Flyway는 현재 비활성 상태입니다.**

서버는 AI팀이 배치로 생성한 정적 파일(segments.geojson / wsi_scores.json / safezones.geojson)을
메모리에 올려 서빙합니다. DB 없이도 완전히 동작합니다.

### DB를 켜야 할 시점

사용자 피드백, 신고 위치 저장 등 **사용자 데이터 저장 기능** 개발을 시작할 때
`db` Spring 프로파일을 활성화하면 됩니다.

```bash
# 로컬 개발
cd server && SPRING_PROFILES_ACTIVE=local,db ./gradlew bootRun

# Docker
docker-compose --profile db up
```

### 내부 동작

| 상태 | 활성 프로파일 | `halo.db.enabled` | DataSource/JPA/Flyway |
|---|---|---|---|
| 기본 (현재) | `local` | `false` | **비활성** (autoconfigure.exclude) |
| DB 활성 | `local,db` | `true` | 활성, Flyway 마이그레이션 자동 실행 |

관련 파일:
- `application.yml` — `!db` / `db` 프로파일 분기 정의
- `FlywayConfig.kt` — `@ConditionalOnProperty(halo.db.enabled=true)`
- `SegmentScoreService.kt` — `@ConditionalOnProperty(halo.db.enabled=true)` (휴면 중)
- `docker-compose.yml` — `--profile db` 로 DB 서비스 기동

---

## 8. Data Contract: DB Schema & API Spec

### DB Schema Ownership
**Spring Boot (Flyway) owns the schema.**

- Migrations live in `server/src/main/resources/db/migration/`
- Naming: `V{n}__{description}.sql` (e.g. `V1__init_street_segments.sql`)
- Spring Boot applies migrations on startup via Flyway
- Python reads/writes the same tables — no separate migration tool

When Python needs a new column or table:
1. Python dev writes the SQL migration in `server/src/main/resources/db/migration/`
2. Spring dev reviews and merges it
3. Both sides adapt their code in the same PR

### API Spec
- Spring Boot exposes OpenAPI docs at `/swagger-ui.html` (via springdoc-openapi)
- Flutter consumes the API — check `/v3/api-docs` for the JSON spec
- All breaking changes to API shape must update the spec and Flutter model in the same PR

### Component Data Flow
```
[External Data Sources]
        ↓
[Python: ingestion → processing → scoring]
        ↓  (writes to PostgreSQL/PostGIS)
[PostgreSQL + PostGIS]  ←→  [Spring Boot API]
                                    ↓
                            [Flutter App]
```
