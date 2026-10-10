# 概要
Claude Codeプロジェクト

# 目的
主に２つの側面で管理。
* AI駆動開発のベースイメージ（`ghcr.io/nkajitani/base-claude`）の管理 — `base/`
* Claude Codeの検証用プロジェクト — `playground/`

後者に関しては、README.mdのみならず、RESULT.mdによって結果のアウトプットも行うことで、あとから見直せるようにすること。

## このリポジトリの位置づけ

このリポジトリは、Claude で AI 駆動開発を行うための**ベースイメージ**を管理する。

```
このリポジトリ  ──build──>  ghcr.io/nkajitani/base-claude:latest
                                      │
                                      │ 個別アプリのリポジトリで image として利用
                                      ▼
                            各アプリの compose.override.yml
```

個別のアプリケーション開発では、このイメージをそのまま使い、
アプリのリポジトリを `/work` にマウントして作業する。
`base/.claude/` 配下（エージェント・スキル・CLAUDE.md・settings.json 等）が、
コンテナ内の `/root/.claude/` としてイメージに焼かれる。

### 個別アプリ側の compose.override.yml

各アプリのリポジトリに以下を置いて使う。

```yaml
services:
  claude:
    image: ghcr.io/nkajitani/base-claude:latest
    volumes:
      - ./.claude:/root/.claude
      - .:/work
      # ベースとなるエージェント・スキルのみマウント先を切り替え
      - ~/docker/claude/base/.claude/agents:/root/.claude/agents
      - ~/docker/claude/base/.claude/skills:/root/.claude/skills
      - ~/docker/claude/base/.claude/commands:/root/.claude/commands
      - ~/docker/claude/base/.claude/CLAUDE.md:/root/.claude/CLAUDE.md
      - ~/docker/claude/base/.claude/settings.json:/root/.claude/settings.json
      - ~/docker/claude/base/.claude/statusline-command.sh:/root/.claude/statusline-command.sh
```

### マウントの住み分け

| マウント | 役割 |
|---------|------|
| `./.claude:/root/.claude` | アプリ側の `.claude/`。セッション履歴・メモリ・**ログ**がここに残る |
| `~/docker/claude/base/.claude/agents` 等 | ベース側のソースを直接マウント。イメージを再ビルドせずベースの更新が反映される |
| `.:/work` | アプリのソースコード。Claude Code の作業ディレクトリ |

`agents` / `skills` / `commands` をディレクトリ単位で切り替えているのは、
**プロジェクト固有のエージェントやスキルを開発する**余地を残すため。
ベース側を編集すれば即座に全プロジェクトへ反映され、
プロジェクト固有のものを作りたい場合はこの行を外せばアプリ側の `.claude/` が使われる。

### ログの出力先

サブエージェントの実行ログは、コンテナ内では `/root/.claude/logs/` に出る。
`./.claude:/root/.claude` によって、実体は**アプリのリポジトリ直下の `.claude/logs/`** になる。

そのため `.gitignore` は各アプリのリポジトリ側で設定する。

```gitignore
.claude/logs/
```

ベース側（このリポジトリ）の `base/.claude/logs/` は使われない。

### 注意：hooks はマウント対象外

`base/.claude/hooks/` は override でマウントしていない（イメージに焼かれたものを使う）。
hooks はプロジェクトごとに差し替える想定が無く、ベース共通の仕組みであるため。

`hooks/log-agent.sh` を変更した場合は、**イメージの再ビルドが必要**。
開発中に試行したい場合のみ、一時的に以下を足す。

```yaml
      - ~/docker/claude/base/.claude/hooks:/root/.claude/hooks
```

なお `settings.json` はファイル単位でマウントしているため、
コンテナ内の設定は常にこのリポジトリの内容と一致する（手元で書き換えてもズレない）。

## サブエージェントのログ基盤

リードエージェントが 7 つのサブエージェントに作業を委託する過程を、3 層に分けて記録・分析する。

| 層 | 記録するもの | 実装 | 出力先 |
|----|-------------|------|--------|
| 1. 実行ログ | 何が起きたか（起動・終了・時刻・エージェント名・トークン数） | hooks（`base/.claude/hooks/log-agent.sh`） | `/root/.claude/logs/agents-YYYYMMDD.jsonl` |
| 2. 判断ログ | なぜそうしたか（フェーズ移行・差し戻しの理由） | リードエージェントが追記（`CLAUDE.md` のルール） | `./docs/logs/decisions.md` |
| 3. 分析 | 傾向（重いエージェント、差し戻しの多いフェーズ） | `retrospective` エージェント | `./docs/logs/RESULT.md` |
| （運用）改善案ストック | 改善案と、その採否 | リードエージェント / `retrospective` が追記 | `./docs/logs/improvements.md` |

記録（1層）は hooks が自動で行うため、エージェントの書き忘れや書式の揺れが起きず、
トークンも消費しない。分析（3層）は明示的に呼んだときだけ動く。

### 1層：実行ログの見方

`SubagentStart` / `SubagentStop` フックで、1 行 1 イベントの JSONL が追記される。
ログはコンテナ内の `/root/.claude/logs/` に出る。`./.claude:/root/.claude` の
マウントにより、実体は**アプリのリポジトリ直下の `.claude/logs/`** になるため、
コンテナを止めても残る。

```console
$ cat /root/.claude/logs/agents-$(date -u +%Y%m%d).jsonl
```

```json
{"ts":"2026-10-10T11:36:52Z","event":"SubagentStart","agent":"Explore","agent_id":"a79ba7c3f89ac42ed","session_id":"20dfc0aa","cwd":"/work","effort":null,"tokens":null}
{"ts":"2026-10-10T11:36:53Z","event":"SubagentStop","agent":"Explore","agent_id":"a79ba7c3f89ac42ed","session_id":"20dfc0aa","cwd":"/work","effort":"high","tokens":{"input":2,"output":4,"cache_read":5488,"cache_create":2680,"api_calls":1,"total":8174}}
```

| フィールド | 内容 |
|-----------|------|
| `ts` | イベント発生時刻（UTC・ISO 8601） |
| `event` | `SubagentStart` または `SubagentStop` |
| `agent` | エージェント名（`coder`、`designer` など） |
| `agent_id` | 起動と終了を対応づける ID。2 つの `ts` の差が所要時間になる |
| `session_id` | セッション ID。どの作業単位かを識別する |
| `effort` | 推論の effort レベル |
| `tokens` | `SubagentStop` のみ。内訳と `total`。取得できない場合は `null` |

よく使う確認コマンド：

```console
# エージェントごとの起動回数
$ jq -r 'select(.event=="SubagentStart") | .agent' /root/.claude/logs/agents-*.jsonl | sort | uniq -c | sort -rn

# エージェントごとの合計トークン
$ jq -r 'select(.tokens) | [.agent, .tokens.total] | @tsv' /root/.claude/logs/agents-*.jsonl \
    | awk -F'\t' '{s[$1]+=$2} END{for(a in s) printf "%-22s %d\n", a, s[a]}' | sort -k2 -rn

# 今日の総トークン数
$ jq -s '[.[] | .tokens.total // 0] | add' /root/.claude/logs/agents-$(date -u +%Y%m%d).jsonl
```

ログは日付ごとのファイルに分かれる。各アプリのリポジトリで `.claude/logs/` を
`.gitignore` に入れておけば、コミットされない。

### 2層：判断ログ

hooks では「なぜその判断をしたか」は取れないため、リードエージェントが
フェーズ移行時と差し戻し時に `./docs/logs/decisions.md` へ 1 件ずつ追記する。
ルールと書式は `base/.claude/CLAUDE.md` の「判断ログの記録ルール」に定義している。

### 3層：retrospective の呼び方

ワークフロー図には入っていない。分析したいときにユーザーが明示的に呼ぶ。

```
retrospective エージェントで、今回のログを分析してください
```

1層の JSONL と2層の `decisions.md` を読み、`./docs/logs/RESULT.md` に以下を書き出す。

1. サマリ（対象期間・総起動回数・総トークン数）
2. エージェント別集計（起動回数・合計時間・合計トークン・平均）
3. フェーズ別の傾向
4. 差し戻しの分析
5. 改善提案（根拠となる数値つき）

数値はログの実測値のみを使い、根拠が無い項目は「データ不足」と明記する方針にしている。

### 改善案ストック（運用）

振り返りで出た改善案や、作業中に気づいた「あとで直したいこと」は
`./docs/logs/improvements.md` に溜める。

`RESULT.md` は実行するたびに上書きされるため、改善案をそこに置くと消える。
また、採用・却下の判断が残らないと同じ提案が毎回蒸し返される。
そのためストックは追記専用の別ファイルに分けている。

```markdown
## IMP-003 サブエージェントのプロンプトが長い
- **状態**: 未着手
- **起票**: 2026-10-10 / retrospective
- **根拠**: coder の cache_read 比率が 31%。他エージェント（平均 68%）より明確に低い
- **内容**: 設計書の全文ではなく該当章のみを渡す
- **効果**: 製造フェーズのトークンを 3 割程度削減できる見込み
```

- 状態は `未着手` / `対応中` / `完了` / `却下`
- ID は `IMP-001` から通番。アーカイブ後も ID は振り直さない
- `retrospective` は実行時にこれらを読み、**重複起票せず**、
  `却下` の項目を再提案しない（判断を蒸し返さない）
- 作業中に本筋と関係ない問題に気づいたら、その場で直さず起票して先に進む
- `完了` / `却下` になったものは `./docs/logs/archive/improvements-YYYYMM.md` へ移す。
  `improvements.md` には未着手・対応中だけが残る

```
docs/logs/
├── decisions.md                   判断ログ（2層）
├── improvements.md                未着手・対応中のみ
├── RESULT.md                      最新の振り返り（毎回上書き）
└── archive/
    └── improvements-202610.md     完了・却下したもの
```

`retrospective` は起票時に `improvements.md` と `archive/` の**両方**を読み、
ID の重複と却下済み案の蒸し返しを防ぐ。

ルールの詳細は `base/.claude/CLAUDE.md` の「改善案ストック（運用）」を参照。

### 設計上の注意

- **`hooks/` は override でマウントしていない**（イメージに焼かれたものを使う）。
  `log-agent.sh` や hooks 設定を変更したら、**イメージの再ビルドと配布が必要**。
  詳細は「このリポジトリの位置づけ」を参照
- **hooks はセッション開始時に読み込まれる**。`settings.json` を変更した場合、
  反映には Claude Code の再起動（コンテナの再起動）が必要
- **`log-agent.sh` は必ず終了コード 0 で抜ける**。ログ記録に失敗しても
  Claude Code の作業は止まらない（jq が無い・JSON が壊れている・
  ログ先が書き込み不可、いずれの場合も作業は継続する）
- **トークン数は transcript から集計している**。transcript は内部形式のため、
  Claude Code のバージョンアップで構造が変わると `tokens` が `null` になる可能性がある。
  その場合も 1 行の記録自体は残る
- **`retrospective` 自身は 1層ログに記録しない**。ログを分析するエージェントの起動が
  記録されると、分析の最中にログが増えて集計に自分が混ざる（自己参照）。
  除外するエージェントは環境変数 `CLAUDE_AGENT_LOG_EXCLUDE` で変更できる
  （カンマ区切り。既定値は `retrospective`）
- **`SubagentStop` の時点では transcript の書き込みが完了していないことがある**ため、
  最大 3 回（計 1.5 秒まで）待って読み直す。それでも取れなければ `null` とする
- **1層のログはプロジェクト外**（`/root/.claude/logs/`）にあるため、
  `settings.json` の `permissions.additionalDirectories` で読み取りを許可している。
  この設定が無いと `retrospective` がログを読めず、定量分析ができない
