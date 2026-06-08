# META-EXPERT-012: Document Lifecycle, Actualization, Rotation, and Archivation v0

Card: S3-R4-C4-S (внетрековая задача)
Agent: [Igniter-Lang Meta Expert]
Role: meta-expert
Date: 2026-05-08
Status: active governance
Supersedes: nothing (new policy)

---

## I. Назначение

Этот документ определяет методологию работы с документацией проекта по трём осям:

- **Актуализация** — как и когда документы обновляются
- **Ротация** — как документы меняют жизненный статус (promoted, deprecated, superseded)
- **Архивация** — когда и как документы уходят в архив, что живёт в `archive/`

Все роли следуют этому словарю. Single source of truth по lifecycle.

---

## II. Диагноз текущего состояния

По состоянию на S3-R4 накопились структурные дисфункции:

```
Симптом                                                  Диагноз
─────────────────────────────────────────────────────────────────────────────
177 track-документов, ни один не в архиве                нет правил архивации
16 proposals со Status: proposal                         lifecycle не закрывается
PROP-026/027 «закрыты» в README, файлы — нет             ротация не выполнена
META-EXPERT-008 «superseded» без явного механизма        ротация не определена
Spec ch4 не обновлялся с S2-R7 (TEMPORAL не отражён)    актуализация не триггерится
Нет per-round обязанностей по lifecycle                  нет системы
─────────────────────────────────────────────────────────────────────────────
current-status.md обновляется каждый раунд               ✅ работает
discussions/ всегда закрываются с маршрутом               ✅ работает
```

Корневая причина: три механизма (актуализация, ротация, архивация) не разграничены.
Нет чёткого ответа на вопросы:
- Кто обновляет этот документ и когда?
- Что означает «устарел» vs «заменён» vs «архивный»?
- Куда уходит документ, когда он больше не нужен в активном пространстве?

---

## III. Принципы

**P1. Три механизма независимы.**
Актуализация — это обновление содержимого живого документа.
Ротация — это изменение его статуса в lifecycle.
Архивация — это физическое перемещение из рабочего пространства.
Документ может актуализироваться без ротации и архивации.

**P2. Каждый тип документа имеет свой lifecycle.**
Track-документ после `done` не обновляется — он неизменен как доказательство.
Spec-глава после каждого раунда с изменениями в коде требует проверки.

**P3. Ответственность фиксирована, не ad hoc.**
За каждый тип документа назначен владелец процесса.
Per-round checklist — это исполняемая обязанность Meta Expert, не «если не забыл».

**P4. Архив — не мусоропровод.**
Документ уходит в архив только по одному из трёх критериев:
- stage close (плановая архивация)
- явная замена другим документом
- доказательство, на которое документ ссылается, устарело

«Старый» ≠ «архивный». Документ S2-R2 может оставаться живым сигналом в S3.

**P5. Status: в файле = факт, не украшение.**
Любое расхождение между Status: в файле и Status: в индексном README — это дефект,
требующий исправления в текущем round.

---

## IV. Типы документов и lifecycle-словарь

### 4.1 `current-status.md` — живая доска

```
Lifecycle:    один документ, всегда active, не ротируется, не архивируется
Владелец:     Meta Expert + Supervisor
```

Не имеет версионирования и состояний. Историческое состояние хранится в git
и в stage-close snapshots. Признак проблемы: не обновлялся > 2 rounds.

---

### 4.2 Track-документы (`docs/tracks/*.md`) — срезовые доказательства

```
Состояния:
  in_progress    слайс идёт, документ пишется
  done           handoff закончен, доказательство зафиксировано
  blocked        явно ждёт разблокировки другим слайсом
  superseded     заменён более поздним треком; поле "Superseded by: <name>"
  archived       перемещён в archive/ при stage close
```

Правило неизменности: track-документ **не редактируется** после `done`.
Если нужна корректировка — новый трек с суффиксом `-errata-v0` или `-v1`.

---

### 4.3 Proposals (`docs/proposals/PROP-*.md`) — формальные предложения

```
Состояния:
  authored       написан, ещё без верификации
  proposal       принят к рассмотрению
  verified       experiment PASS, спецификация ещё не обновлена
  closed         experiment PASS + spec обновлён/scheduled
  rejected       формально отклонён (записать обоснование)
  superseded     заменён новым PROP; поле "Superseded by: PROP-NNN"
```

Правило синхронности: Status: в файле PROP = Status: в proposals/README.md.
Расхождение — дефект текущего round.

---

### 4.4 Spec-главы (`docs/spec/ch*.md`) — канонический эталон

```
Состояния:
  draft          написана, пока не соответствует реализации
  current        соответствует текущей реализации
  stale          реализация ушла вперёд, глава не обновлена
  frozen         stage закрыт, глава заморожена (Stage 1 = frozen)
```

Constraint «spec-lag»: spec может отставать не более чем на 1 stage.
К stage close spec должен быть в состоянии `current`.

---

### 4.5 Meta-proposals (`docs/meta-proposals/META-EXPERT-*.md`) — управление

```
Состояния:
  active         текущее действующее решение
  supporting     поддерживающий контекст для active
  decision       принятое одноразовое решение (не изменяется)
  superseded     заменён более новым META-EXPERT
  done           задача выполнена (процессный документ)
  research-note  не-governance материал (давление, идеи)
  vision         стратегический горизонт без governance force
```

Правило уникальности: только ОДИН meta-proposal может иметь статус `active`
на конкретную тему в конкретный момент.

---

### 4.6 Discussions (`docs/discussions/*.md`) — ограниченные дискуссии

```
Состояния:
  open       дискуссия идёт
  complete   закончена, маршрут определён (PROP / track / backlog / reject)
```

После `complete` не редактируется. Не архивируется — остаётся как исторический
сигнал в discussions/. Работает корректно; изменений не требуется.

---

## V. Актуализация

**Актуализация** — это обновление содержимого живого документа в ответ
на изменение внешних фактов (код, эксперименты, решения).

### Что актуализируется и когда

| Документ | Триггер | Кто выполняет |
|----------|---------|---------------|
| `current-status.md` | каждый round-curation слайс | Meta Expert |
| Spec-глава | в коде появился новый node type / fragment class | C/G Expert по запросу Meta Expert |
| proposals/README.md | изменился статус любого PROP | Meta Expert |
| PROP-файл | experiment PASS или PROP superseded | Meta Expert (Status строка) |
| meta-proposals/README.md | появился новый META-EXPERT | Meta Expert |
| tracks/README.md | добавлен новый трек | автор трека |

### Что НЕ актуализируется (неизменяемые типы)

- Track-документы после `done`
- Discussions после `complete`
- PROPs в `accepted/`
- Документы в `archive/snapshots/`

### Spec-backlog

Когда Meta Expert видит изменение в classifier/emitter без соответствующего
обновления spec-главы, он создаёт запись в spec-backlog (внутри текущего
status-curation трека):

```text
spec-backlog (пример):
  ch4: TEMPORAL fragment class — PROP-028 не отражён [S3-R2]
  ch6: temporal_input_node / temporal_access_node [S3-R3-C2]
  ch5: emit_typed path [S3-R2]
  ch7: cache key contract [S3-R3-C3]
```

При накоплении ≥3 записей или при отставании > 2 rounds — создаётся
`spec-stage3-sync-v0` трек [Compiler/Grammar Expert].

---

## VI. Ротация

**Ротация** — это изменение lifecycle-статуса документа:
продвижение (promoted), устаревание (deprecated), замена (superseded).

Ротация не перемещает файлы физически (это задача архивации).
Ротация меняет `Status:` в файле и запись в индексе.

### Правила ротации по типу

**Track-документы:**

```
in_progress → done         handoff написан, слайс закрыт
done → superseded          вышел новый трек с тем же scope
                           → добавить "Superseded by: <name>" в файл
                           → обновить tracks/README.md
blocked → done             разблокировка зафиксирована в handoff
blocked → superseded       scope закрыт другим способом
```

**PROP-файлы:**

```
authored → proposal        принят в очередь рассмотрения
proposal → verified        experiment PASS задокументирован в track
verified → closed          spec обновлён или scheduled
proposal/verified → rejected   решение отклонить; записать причину
any → superseded           новый PROP явно заменяет; добавить ссылку
```

**Meta-proposals:**

```
active → superseded        новый META-EXPERT принимает управление по теме
                           → переместить в секцию "Stage N Governance (closed)"
                           → в новом META-EXPERT добавить "Supersedes: ME-NNN"
decision / done            состояние финальное; не меняется
```

**Spec-главы:**

```
current → stale            код ушёл вперёд, глава не обновлена
stale → current            spec-sync трек выполнен
current → frozen           stage close (Meta Expert)
```

### Per-round ротационная проверка

В каждом `status-curation` слайсе Meta Expert выполняет:

```
[ ] Все эксперименты с PASS → PROP Status обновлён до closed?
[ ] Есть треки с done статусом > 2 rounds без superseded метки?
[ ] Есть meta-proposals в active секции которые уже superseded?
[ ] Есть spec-главы в current которые должны быть stale?
[ ] tracks/README.md синхронизирован с новыми треками?
```

---

## VII. Архивация

**Архивация** — физическое перемещение документа из рабочего пространства
в `docs/archive/`. Документы в архиве: read-only, исторический контекст,
не требуют обслуживания.

### Когда архивируется

Три и только три критерия:

```
КРИТЕРИЙ A (плановый): Stage close
  → все треки текущего stage переносятся в archive/snapshots/YYYY-MM-DD-stage-N-close/
  → PROPs в статусе closed/superseded переносятся в proposals/accepted/
  → spec-главы замораживаются (Status: frozen), физически не переносятся

КРИТЕРИЙ B (замена): документ явно superseded + прошёл ≥ 1 full round
  → track с superseded статусом + его заменитель уже имеет done
  → meta-proposal с superseded из прошлого stage
  → действие: перенести в archive/superseded/

КРИТЕРИЙ C (утраченная актуальность): доказательство, на которое ссылается
  документ, физически удалено или полностью переписано
  → требует явного решения Meta Expert + Supervisor
  → действие: перенести в archive/orphaned/ с пояснением причины
```

Всё остальное — не архивируется. «Старый трек» без явного критерия остаётся
в tracks/ как исторический след.

### Что куда переносится

```
docs/archive/
  snapshots/
    YYYY-MM-DD-stage-N-close/     ← полный срез при stage close
      tracks/                     ← все треки закрытого stage
      proposals/                  ← только accepted/ не переносятся, они уже там
      meta-proposals/             ← historical governance docs
      current-status.json         ← снимок scoreboard на момент close
  superseded/
    <document-name>.md            ← явно замещённые документы (Критерий B)
  orphaned/
    <document-name>.md            ← документы с утраченным контекстом (Критерий C)
    reason.md                     ← обязательно: объяснение почему
```

### Что НЕ архивируется никогда

- `current-status.md` — только git history
- `docs/discussions/*.md` — остаются как исторические сигналы
- Spec-главы — замораживаются (`frozen`), физически не перемещаются
- `proposals/accepted/` — уже является финальным местом для closed PROPs

### Stage close snapshot — процедура

При каждом stage close Meta Expert выполняет:

```
1. Зафиксировать дату close: YYYY-MM-DD
2. Создать директорию: archive/snapshots/YYYY-MM-DD-stageN-close/
3. Скопировать (не переместить) все треки stage в snapshot/tracks/
4. Скопировать meta-proposals governance docs в snapshot/meta-proposals/
5. Записать current-status snapshot как stage-close-status.json
6. Переместить closed/superseded PROPs в proposals/accepted/
7. Заморозить spec: обновить Status: current → frozen для всех ch*.md
8. Обновить meta-proposals/README.md: закрытый stage → archived section
9. Создать stage-close-governance META-EXPERT (пример: META-EXPERT-009.1)
```

**Примечание:** при stage close используется копирование в snapshot,
а не перемещение из tracks/. Треки физически остаются в tracks/ как
активная история, но snapshot фиксирует полный состав на момент close.
Ротация (superseded/archived статусы) выполняется отдельно от snapshot.

---

## VIII. Матрица ответственности

| Документ | Создаёт | Актуализирует | Ротирует | Архивирует |
|----------|---------|--------------|---------|------------|
| current-status.md | Meta Expert | Meta Expert (каждый round) | — | — |
| Track docs | назначенный агент | — (не редактируется) | Meta Expert | Meta Expert (stage close) |
| PROP файлы | C/G Expert | C/G Expert (errata) | Meta Expert | Meta Expert (stage close → accepted/) |
| proposals/README.md | C/G Expert | Meta Expert | Meta Expert | — |
| Spec chapters | C/G Expert | C/G Expert по запросу Meta Expert | Meta Expert | — (frozen in place) |
| Meta-proposals | Meta Expert | Meta Expert | Meta Expert | Meta Expert (stage close) |
| Discussions | инициатор | — (не редактируется) | автор (complete) | — |

---

## IX. Per-Round Lifecycle Checklist

Встроить в каждый `*-status-curation-v0` слайс Meta Expert.

```markdown
## Lifecycle Checklist Round N

### Актуализация
- [ ] current-status.md: все треки round N отражены, lanes актуальны, дата обновлена
- [ ] tracks/README.md: добавлена секция Round N со всеми треками
- [ ] proposals/README.md: синхронизирован с файлами PROP

### Ротация
- [ ] Все PROP с experiment PASS обновлены до Status: closed
- [ ] Нет расхождений между README и файлами PROP
- [ ] Treки с done статусом проверены: нет тех, которые должны быть superseded
- [ ] Meta-proposals/README.md: нет superseded документов в active section
- [ ] spec-backlog: нет записей старше 2 rounds без scheduled трека

### Архивация
- [ ] Нет треков с Критерием B (superseded > 1 round) без архивации
- [ ] При stage close: выполнена процедура snapshot (раздел VII)
- [ ] При stage close: closed PROPs перемещены в accepted/
```

---

## X. Текущий Debt Register (S3-R4)

### Критические (дефекты состояния — устранены в этом слайсе)

```
✅ PROP-026: Status: proposal → closed  (выполнено)
✅ PROP-027: Status: proposal → closed  (выполнено)
✅ meta-proposals/README.md: убран stale header "Active Governance (Stage 2)" (выполнено)
```

### Умеренные (требуют трека)

```
⏳ Spec backlog → spec-stage3-sync-v0 трек [C/G Expert]:
     ch4: TEMPORAL fragment class (PROP-028)
     ch6: temporal_input_node / temporal_access_node
     ch5: emit_typed path в pipeline description
     ch7: cache key contract outline

⏳ signal-ledger-index.md: добавить пометку stale, последнее обновление S2

⏳ proposals/README.md header: обновить с "Stage 2 active intake" → "Stage 3 active"
```

### Плановые (при Stage 3 close)

```
⌛ Stage 3 close snapshot → archive/snapshots/YYYY-MM-DD-stage3-close/
⌛ Closed PROPs (022–027, 028+) → proposals/accepted/
⌛ Spec chapters → Status: frozen
⌛ Треки Stage 3 (tracks/) → Status: archived + snapshot copy
```

---

## XI. Правила создания новых документов

Обязательные поля в заголовке каждого нового документа:

```markdown
# Для track-документов:
Card: <S-R-C-suffix>
Status: in_progress | done | blocked
Date: YYYY-MM-DD

# Для PROPs:
Status: authored | proposal
Date: YYYY-MM-DD
Stage: <N>
Depends on: <список PROP | nothing>

# Для meta-proposals:
Status: active | decision | research-note | ...
Date: YYYY-MM-DD
Supersedes: <ME-NNN> | nothing

# Для discussions:
Status: open
Mode: discussion
Date: YYYY-MM-DD
Initiator: user | architect-supervisor | meta-expert
```

Именование файлов:

```
Track:          <topic>-v0.md        → revision: <topic>-v1.md (не overwrite)
PROP:           PROP-NNN-<topic>-v0.md
Meta-proposal:  META-EXPERT-NNN-<topic>-v0.md
Discussion:     <topic>-discussion-v0.md
Errata:         <topic>-errata-v0.md (не изменять оригинал)
```

---

## XII. Метрики здоровья документооборота

```
АКТУАЛИЗАЦИЯ                               РОТАЦИЯ
✅ current-status.md обновлён этот round   ✅ PROP Status: = README Status:
✅ tracks/README.md не отстаёт             ✅ Нет active META-EXPERT дублей
✅ spec-backlog ≤ 2 round                  ✅ PROP PASS → closed в том же round

АРХИВАЦИЯ
✅ Нет superseded треков > 1 round без архивации
✅ При stage close: snapshot + accepted/ выполнены

ТРЕВОЖНЫЕ СИГНАЛЫ
⚠️  PROP Status в файле ≠ Status в README
⚠️  Spec-глава не обновлялась > 2 rounds при активных изменениях в коде
⚠️  > 1 META-EXPERT с active на одну тему
⚠️  tracks/README.md отстаёт от track-файлов на > 1 round
⚠️  signal-ledger без обновлений при наличии новых ME-решений
⚠️  Треки с Критерием B не архивированы > 1 round после superseded
```

---

## Handoff

```text
Card: S3-R4-C4-S (внетрековая задача)
Agent: [Igniter-Lang Meta Expert]
Role: meta-expert
Track: META-EXPERT-012-document-lifecycle-and-rotation-v0.md
Status: done

[D] Decisions
- Три механизма разграничены: актуализация, ротация, архивация.
- Per-round checklist разделён на три секции по механизму.
- Три и только три критерия архивации: stage close / superseded / orphaned.
- Stage close snapshot: копирование, а не перемещение треков.
- Spec-lag constraint: ≤ 1 stage отставания от реализации.
- Status: в файле PROP = Status: в README — нарушение = дефект текущего round.

[S] Signals
- PROP-026/027 исправлены в этом слайсе (критический дефект устранён).
- Spec backlog: ch4/ch5/ch6/ch7 — долг Stage 3, scheduled на spec-sync трек.
- 177 track docs: нет архивации, но теперь есть критерии.

[R] Recommendations
- spec-stage3-sync-v0 [C/G Expert]: приоритет S3-R4 или R5.
- Добавить Per-Round Lifecycle Checklist в шаблон status-curation трека.

[Next] Suggested next slices
- spec-stage3-sync-v0 [Compiler/Grammar Expert]
- status-curation-v0 с embedded lifecycle checklist
```
