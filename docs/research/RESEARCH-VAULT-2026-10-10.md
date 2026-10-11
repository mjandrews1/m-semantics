# Research vault — M-stack literature + biomedical citation/YottaDB + gMG case study

> Merged 2026-10-10 · workspaces: `research/m-ports-lit/` · `research/biomed-citation-lit/` · `research/gmg-selfmg-vanilla/`  
> This is the **final merged document** of the two literature maps plus the applied gMG self-management comparison (vanilla vs YottaDB-augmented).  
> **Medical content is research synthesis, not personal medical advice.**

---

# Part A — Which literature grounds our RSM-ported M implementations (JvMumps + mJVM)?

 grounds our RSM-ported M implementations (JvMumps + mJVM)?

> Generated 2026-10-10 · depth: standard · 25+ sources · workspace: research/m-ports-lit/

## Executive summary

- **Cite ISO/IEC 11756:1999, not ANSI X11.1** — ANSI M standards were withdrawn ~2001; ISO 11756 Edition 2 (1999-07) is the live international M standard, confirmed 2026-03-06 [1][2][3].
- **Standard lineage is fully documented**: NBS Handbook 118 (1976) → ANSI X11.1-1977/1984/1990/1995 → ISO 11756-1992/1999; RSM targets X11.1-1995 (= ISO 11756:1999 text) [1][4][5][6].
- **Conformance practice is documentation, not a shared machine suite** — O'Kane “deviations highlighted”, Newman “basically X11.1-1995 compliant”; no NIST-SQL-style public M suite found [7][8][9]. Our `conformance.json` (139 cases) fills that gap for the port family.
- **M patterns** are full-string, codes A/C/E/L/N/P/U, with count ranges and parenthesized alternation; naive recursion blows up (`<COMPLEX PATTERN>`) — MDH already maps M patterns → PCRE [10][11][12].
- **JVM backend**: JSR 292 `invokedynamic` + MethodHandle/CallSite bootstrap is the documented path for dynamic call sites (Oracle 2009, JRuby 2008) [13][14]; bytecode dispatch (computed-goto vs switch) measurably matters [15].
- **Formal methods**: SpecTec/Wasm and K Framework show semantics-vs-conformance is how spec bugs get found; Jitterbug justifies **contract-level** verification inside an unverified port [16][17][18]. No M-specific formal semantics literature surfaced [gap].
- **Dafny vs Rocq**: a 2026 RISC-V study finished in Rocq in 30 min where Dafny timed out — keep Dafny for contracts (patterns, compare), don't chase whole-interpreter proofs first [19][20].

## Background & scope

We implement M as **JvMumps + mJVM** (primary), with **RSM as the only Oracle**, Py/C3 as accepted peer proofs (131/8/0), and O'Kane/FreeM as adjuncts. This report maps the standards, port, compiler, and formal-methods literature that should ground that work. Out of scope: YottaDB storage plane (separate report).

## 1. Normative standards (what “conformant” means)

ISO/IEC 11756:1999 (doc 29268, 115 pp., Edition 2) is the in-force language standard [1]. The ANSI line (X11.1-1977 … X11.1-1995) was administratively withdrawn around 2001 after the MDC/MTA closed; ISO text matches X11.1-1995 except front matter and a SQL normative reference [2][3]. X11.1-1995 defines metalanguage grammars, **three conformance classes**, error codes M1–M113/S0, and portability minimums — directly reusable as corpus design criteria [2]. Companion standards: OMI (X11.2→ISO 15851), GKS binding (X11.3), MWAPI (X11.6→ISO 15852) [2].

Historical anchors: NBS Handbook 118 (1976, 162 pp., public-domain scan) is the first formal MUMPS spec and a useful 1976 baseline [4]; MUMPS itself (1966–67, MGH PDP-7) was released to the public domain under an NIH grant condition [5].

## 2. Implementations and porting practice

| Implementation | Standard claim | Notes |
|----------------|----------------|-------|
| **RSM** | X11.1-1995 / ISO 11756:1999 | Oracle; from Ray Newman MUMPS V1 [6] |
| **GT.M / YottaDB** | “Nearly complete” ISO M + Z-prefix extensions | Open-sourced 2000-12-09; YottaDB is the fork [8][9] |
| **O'Kane GPL Mumps** | X11.1-1995 with documented deviations | Native + SQLite backends [7] |
| **FreeM** | Historical X11.1-1995 + SSVNs/MWAPI goals | Maintainer now de-prioritizes strict MDC [11] |
| **Newman MUMPS (SF)** | “Basically X11.1-1995 / 11756:1999” | Third independent C+M implementation [12] |

Conventions worth adopting: **Z-prefix = non-ANSI extension** [9]; **published deviations list** (O'Kane) rather than silent divergence [7]; our **8-case upstream set** (ELSE/`$TLEVEL`/string-compare/`=`) is exactly such a deviations list against RSM.

**Gap:** no public machine-checkable M conformance suite (unlike NIST SQL) [7]. Our shared 139-case corpus + multi-host matrix is the practical substitute.

## 3. Interpreter & compiler design

- **Expressions:** Pratt TDOP (nud/led, binding powers) is the standard hand-written parser for M-like expressions; Bendersky’s walkthrough is the short companion [21][22].
- **Patterns:** InterSystems documents `?` as full-string match with codes A/C/E/L/N/P/U and nested alternation; pathological backtracking is a known abort case [10]. MDH’s grammar (`count pattern_element`, alternation `('(' atom {',' atom} ')')`) and **PCRE lowering** (E → `[[:print][:cntrl:]]`) are the best published formalization [11][12] — this is the literature twin of our `PatternMatch` / `MPattern.dfy` group work.
- **Bytecode/JVM:** GoAWK’s tree-walk→stack VM rewrite (+18% micro) documents opcode fusion and loop-condition duplication [23][24]; JSR 292 `invokedynamic` + bootstrap `CallSite` is the primary JVM dynamic-call protocol [13][14]; computed-goto dispatch beat `switch` by 25% on a micro-VM [15].

## 4. Formal methods (why Dafny contracts, not whole-RSM proofs)

SpecTec (Wasm CG, 2025) generates prose + Coq from one semantics source and found “numerous bugs in the hand-crafted prose” when run against the test suite [16][17]. K Framework case studies (JS ES5.1 2,782 tests; KEVM 40,000+ programs) validate semantics-derived interpreters against conformance suites [18]. Jitterbug found 16 BPF JIT bugs via a **precise component spec inside an unverified kernel** [19] — the recipe for our Dafny pattern/compare contracts. WasmRef-Isabelle-as-fuzz-oracle is the closest analogue to “RSM is oracle with 8 known divergences” [20]. A 2026 Rocq-vs-Dafny RISC-V study favors explicit proof states over SMT timeouts under agent repair [17b from F4][20].



## Part A open questions
- No M-specific formal semantics paper in the search budget — `m-semantics` may be novel.
- No shared public M conformance suite — our 139-case corpus + multi-host matrix is the practical substitute.
- Register-vs-stack VM tradeoffs for mJVM (one 2005 paper 403'd).

---

# Part B — Which literature grounds PubMed+MeSH+MARC author/citation work on YottaDB?

 grounds PubMed+MeSH+MARC author/citation work on YottaDB?

> Generated 2026-10-10 · depth: standard · 30+ sources · workspace: research/biomed-citation-lit/

## Executive summary

- **MeSH is an authority file + pre-coordinated thesaurus** by NLM’s own 1954/1960 framing — preferred terms, entry terms, qualifier combinations — not a bag of words [1][2][3][4].
- **Evaluate IS&R the Cranfield way**: collection + topics + qrels + precision/recall; MeSH beats textword on gold-standard PubMed search (75%/47.7% vs 54%/34.4%) but ~15.5% of relevant items are textword-only [5][6].
- **Bibliographic graphs are huge and edge-list-friendly**: S2AG 225M papers / 2.8B citation edges; OpenAIRE 2.18B edges fit in 16 GB as int32 pairs — YottaDB sparse globals are a sound physical choice for `^AUTHOR`/`^GRAPH` [7][8][9].
- **Graph store wins traversals, RDBMS wins aggregates** — design ydb-mesh for path/neighbor workloads; preserve directed/unweighted citation vs undirected/weighted co-authorship [10][11][12].
- **YottaDB limits**: 31 subscripts, 1,019-byte key, 1 MiB value; sparse nodes; BC/SI replication for durability [13][14][15]. Precedents: Octo (SQL over globals), TaxisDB `^EATV` fact index [16][17].
- **Author identity is hard**: >55% PubMed names ambiguous; ORCID sparse (~10% of articles) and self-asserted; NLM Computed Authors is the working scale (21.3M authors / 163M instances) [18][19][20][21].
- **LLM/RAG is adjunct, not replacement**: GPT-4o fabricated 78–90% of recent citations (GPT-5 still 39% title-level); hybrid BM25→MedCPT rerank + citation checks is the validated stack [22][23][24].

## Background & scope

ydb-mesh stores PubMed author/citation edges on YottaDB (~185M rows / 325M edges after author-pass 2026-10-10). This report grounds indexing, ranking, author edges, and optional LLM assist in ISR/library science, graph DBs, YottaDB architecture, biomedical communication, and LLM-retrieval literature.

## 1. Library science & ISR (MeSH, authority, evaluation)

MeSH is NLM’s controlled hierarchical thesaurus behind MEDLINE/PubMed [1]; it began as the 1954 *Subject Heading Authority List* [2]. Rogers’ 1960 preface states main-heading + topical-subheading is **pre-coordination** [3]; entry terms act as “see” references; descriptors explode to narrower terms unless `[mh:noexp]` [4]. LC authority control (MARC 1XX/4XX/5XX: heading + see-from + see-also-from + notes) is the formal twin of preferred/entry/related terms [5a]. Cranfield (Cleverdon 1958–66) founded test-collection evaluation [5]; JMLA 2022 (n=1,521) shows MeSH 75% recall / 47.7% precision vs textword 54% / 34.4%, with 15.5% of gold items textword-only [6] — **use combined MeSH + text**. PubMed’s MeSH Translation Table already implements entry-term-style mapping [4]. MEDLARS (1964) is the historical ancestor of MeSH-indexed IR [5b].

## 2. Citation graphs & storage

S2AG: 225M+ papers, 650M authorship, 2.8B citation edges (2025-05) [7][8]. OpenAIRE: 205.8M works, 2.18B citation edges; ~2.5 TB JSON collapses to a **16 GB int32 edge-list** [9]. Graph backends split KV/document/wide-column/native; **adjacency list** is traversal-efficient [10]. Neo4j beat PostgreSQL 36×–2441× on path queries but lost on group-by aggregates [11] — ydb-mesh should optimize neighbor/path access. Citation edges = directed unweighted; co-authorship = undirected weighted [12]. Bulk ingest is brutal (6.2 TB / 38B objects > 3 weeks in Neo4j-class stores) [12a] — our YottaDB batch load (~20h for 1334 files) is competitive.

## 3. YottaDB as data plane

Globals are hierarchical sparse arrays (31 subscripts, 1,019-byte key, 1 MiB value; empty cells cost nothing) [13][14]. Replication: BC + SI logical multi-site, 16-way fan-out, 60-bit JSN [15]. Daemonless multi-process ACID [15a]. **Octo** = SQL over globals (PostgreSQL wire) [16]; **TaxisDB `^EATV(eid,aid,tx,valkey)`** = documented graph-style global layout [17]. Production: FIS Profile banks, Jordan Hakeem VistA 24×7 [15b][15c] — scientific graph at 185M-row scale is comparatively uncharted [gap].

## 4. Author identity

>55% of PubMed author names are ambiguous [18]. NLM Computed Authors: 21.3M authors / 163M instances / 35.7M PMIDs, weekly, FTP+API [18]. ORCID merge/split rules cut split error 7.7%→3.6% but raise merge error 2.2%→5.3% [19]; only ~10% of articles carry ORCID; 40%+ records stale [19][20]. Feature sparsity: Affiliation 53.2%, Grant 8.5% [21]. Author-ity ~99.5% precision/recall vs NIH PI IDs; weaker on Asian surnames [21a]. **Implication:** 160M `new_authors` from name-string identity will over-split; plan clustering + ORCID soft-merge like NLM.

## 5. LLM / RAG (adjunct)

GPT-4o fabricated 78–90% of recent citations (worst in biomedicine); GPT-5 still 39% title-level [22]. Hybrid retrieval (dense + API + rerank) beats single-source; BM25→MedCPT on 24M PubMed: 0.90 acc/recall @ 1.91s [23]. MedRAG/MIRAGE (7,663 questions) shows diverse corpora+retrievers win [24]. DeepScholar-Bench: no system >31% geometric mean on synthesis [24a] — **keep structured graph search primary; LLM for rewrite/summary with citation checks**.

## Comparison table

| Approach | Best for | Risk | Sources |
|----------|----------|------|---------|
| MeSH/authority mapping | recall on indexed lit | misses textword-only 15.5% | [1][4][6] |
| Sparse global edge store | neighbor/path at 100M+ edges | aggregate queries slower | [9][13][11] |
| Property-graph DB | multi-hop analytics | multi-week bulk load | [10][12a] |
| ORCID-as-identity | precise merge | ~10% coverage | [19][20] |
| LLM+RAG rewrite | query expansion, summary | citation fabrication | [22][23] |



## Part B open questions
- No peer-reviewed YottaDB bibliographic-graph workload at our scale — we may be a first.
- MARC-sourced names lack PubMed features for disambiguation.
- Gold-standard qrels for author/citation search UI (Cranfield-style) not yet designed.

---

# Part C — Applied case: gMG patient self-management (vanilla vs YottaDB)

 for patient self-management of generalized myasthenia gravis (gMG) — and what YottaDB graph augmentation adds

> Generated 2026-10-10 · research: web literature pass + YottaDB graph pass · **not personal medical advice**

## Executive summary

**Standard of care / best practice (self-management):**
1. **Crisis literacy is the #1 safety skill** — 911 for severe dyspnea, choking, or inability to walk/talk; crisis = respiratory failure needing BiPAP/intubation; keep go-bag + emergency card + MyMG tracking [F2-4][F2-5].
2. **Dysphagia bundle** — 5–6 small soft meals, upright head-forward, thicken thin liquids, time meals ~1 h post-pyridostigmine; SLP if persistent [F2-2][F2-3].
3. **Energy conservation** — peak tasks ~1 h after Mestinon; “don’t stand when you can sit”; PT/respiratory training safe in mild–moderate MG [F2-1][F2-8].
4. **Medication self-management is the weak link** — 52–71% non-adherence (MMAS); modifiable drivers = necessity beliefs + self-efficacy (social support works *via* self-efficacy) [F3-1–4].
5. **Track MG-ADL** (≥2 points = meaningful change); German 2023 guideline mandates serial QMG/MG-ADL/MG-QOL15r + patient self-assessment [F3-5][F3-7].
6. **Infection ≫ vaccine risk** (ILI exacerbation 40% vs flu shot 1.5%) — inactivated vaccines recommended; meningococcal vax before complement inhibitors [F2-9][F3-12].
7. **Mental health is underdiagnosed** (HADS depression 31% vs 11.6% known) — routine screening is standard-of-care-adjacent [F2-13].
8. **SC home therapy preferred** (82% SC, 84% home) — supports self-administered biologics (zilucoplan/efgartigimod/rozanolixizumab) [F3-9][F3-11].
9. **Pregnancy / drug flags** — worsen in 1st trimester & postpartum; avoid MgSO4, aminoglycosides, FQs, etc. [F2-11][F2-12].

**Method comparison (vanilla vs YDB-augmented):**

| | Vanilla web research | + YottaDB `^GRAPH`/`^AUTHOR` |
|--|----------------------|------------------------------|
| Clinical claims (protocols, ORs, %) | **Strong** (MGFA, Wiendl 2023, registries) | **None** — no titles/abstracts in store |
| Coverage map / recall | Query-dependent | **Strong** — 17,042 MG PMIDs; MeSH neighbourhood scale |
| Author / citation trails | Manual | **Strong** — co-authorship & `has_mesh` edges |
| Actionable “what to do” | **Yes** | Only after resolving PMIDs to full text |
| Failure mode | SEO/guideline lag | Silent empty topic if MeSH not loaded; name-only authors |

**Bottom line:** YDB does **not** replace evidence search for self-management content; it **indexes** the literature (topic→PMID→authors→citations) at 17k-MG / 325M-edge scale. Use it for **recall + provenance + expert/cluster discovery**, then read the papers (or paywalled APIs) for protocols. Hybrid = what we just did.

*Medical disclaimer: synthesis for methodology comparison. Patients should follow their neuromuscular specialist’s plan.*

---

## 1. Standard of care — patient self-management (evidence synthesis)

### 1.1 Safety: flare vs crisis
MGFA: **call 911** for severe shortness of breath, severe swallowing/choking, inability to walk or talk. Myasthenic **crisis** = respiratory muscle weakness requiring BiPAP or intubation (distinct from flare). Crisis often evolves over days–weeks of worsening; early clinician contact can prevent progression. Practical kit: go-bag, cautionary-drug list, emergency alert card (MGFA 2024 EN/ES PDFs), MyMG app [F2-4][F2-5].

### 1.2 Swallowing & nutrition
5–6 small meals, softer foods, rest before meals, no talking while eating, cold foods/liquids, alternate solids/liquids, ~1 h after peak medication. Sit upright, head forward; thicken thin liquids; chop/mash/puree. Persistent problems → SLP + dietitian. Caution: pyridostigmine ↑saliva can worsen dysphagia; NG route preferred over SC neostigmine if aspiration risk [F2-2][F2-3][F2-7].

### 1.3 Activity, rehab, fatigue
Peak-effort scheduling; PT/aerobic+resistance (e.g. 12 wk 2×/week) and inspiratory muscle training improve function without excess AEs; distinguish **fatigue** from **fatigable weakness**; heat avoidance; fall-proofing [F2-1][F2-6][F2-8][F2-16].

### 1.4 Medication adherence (highest-yield self-management lever)
Non-adherence **52% (n=198)** to **71.2% (n=865)** by MMAS; risks: irregular dosing (OR 0.242), medication concerns (OR 0.890); protective: necessity beliefs (OR 1.286), self-efficacy (OR 1.194). Social support → adherence is **mediated by self-efficacy (63.8%)** — teach skills, not just facts [F3-1–4].

### 1.5 Monitoring & treatment context
German 2023 (Wiendl): goal = rapid complete control + QoL; serial **QMG, MG-ADL, MG-QoL15r, MGFA**; pyridostigmine first-line symptomatic; AZA±steroid first disease-modifying; complement/FcRn agents for active AChR-Ab+ disease; meningococcal vaccination before complement inhibitors [F3-5][F3-6][F3-12]. **MG-ADL** (8 items, 0–24; 2-pt MCID sens 77%/spec 82%) is the patient-facing score; post-REGAIN use as primary endpoint 10%→46.7% [F3-7][F3-8].

### 1.6 Administration preference & daily life
82% prefer SC, 84% home (2024 meta-analysis) — aligns with self-administered gMG biologics [F3-9–11]. Infection >> vaccine risk (ILI 40% vs flu 1.5%) [F2-9][F2-10]. Mental health screening (HADS 31%/36%) [F2-13]. Work (ADA accommodations) & driving (UK DVLA reportable) [F2-14][F2-15]. Pregnancy: worsen 1st trimester/postpartum; avoid MgSO4 etc. [F2-11][F2-12].

---

## 2. YottaDB graph pass (what our database actually contributes)

From U01 `^GRAPH` / `^MESH` / `^AUTHOR` (1340-file author-pass + MeSH load):

| MeSH (UI) | Indexed papers in store |
|-----------|------------------------:|
| **Myasthenia Gravis (D009157)** | **17,042** |
| Patient Education as Topic (D010353) | 91,824 |
| Self Care (D012648) | 38,330 |
| Quality of Life (D011788) | 317,187 |
| Fatigue (D005221) | 39,585 |
| Dysphagia (D003680) | 26,430 |
| Immunosuppressive Agents (D007166) | 110,213 |
| Respiratory Muscles (D012132) | 6,513 |
| Pyridostigmine Bromide (D011729) | **1,827** (sparse) |

Sample MG PMIDs from `^GRAPH("mesh","D009157","has_mesh","pubmed",…)` include early MEDLINE IDs (939, 4695, …) through the full baseline — i.e. **decades-long coverage**, not only recent RCTs.

**What the graph can do that vanilla cannot:**
- **Recall:** full 17k-paper MG set in one `$ORDER` walk vs 10–20 Google/semantic hits.
- **Facets:** count self-care / education / QoL / dysphagia overlaps *as a map* before reading.
- **People:** `author_authored` edges → who dominates MG self-management literature (e.g. MGFA materials vs registry teams).
- **Citations:** `^GRAPH`/`^GRAPHREV` expand neighborhoods for “which paper does this recommendation come from?”

**What it cannot do (honest limits):**
- **No titles/abstracts/full text** — cannot state “MGFA says 911 for…” from the store alone.
- **No quality filter** — MeSH co-occurrence ≠ guideline status.
- **Author identity** is name-keyed (160M `new_authors`); ORCID-style merge still needed (see biomed lit report).
- **Pyridostigmine MeSH is small (1.8k)** vs drug names in text — topic recall is MeSH-limited (classic ISR finding).

---

## 3. Compare the two research products

| Dimension | Vanilla (MGFA/Wiendl/registries) | YDB-augmented |
|-----------|----------------------------------|---------------|
| **Specificity of self-care advice** | High (exact meal timing, 911 criteria, ORs) | Zero until PMIDs resolved |
| **Evidence grade visible** | Yes (RCT, meta-analysis, guideline) | No (edges only) |
| **Coverage of “self-management”** | Good for guidelines; misses orphan papers | Can enumerate 38k Self Care × 17k MG intersection |
| **Novel papers / local experts** | Search-engine bias | Citation/author walk over full MEDLINE subset |
| **Reproducibility** | URLs + dates | Deterministic global keys + `$ORDER` |
| **Time to first claim** | Minutes | Seconds to map; hours to read |

**Augmented workflow that wins:**  
`MeSH D009157` → intersect `Self Care`/`Patient Education` → take high-degree `author_authored` nodes → resolve those PMIDs to guidelines/protocols → verify with MGFA/Wiendl.  
Vanilla alone is faster for **protocol text**; YDB alone is stronger for **completeness and provenance**. Together: vanilla supplied 28 evidence claims; YDB proved the corpus behind them is 17k papers deep and linked to 38k self-care / 91k patient-education / 317k QoL records.

---

## Open questions
- Need a **title/abstract** sidecar (or NLM E-utilities) for true graph-augmented evidence synthesis.
- MeSH **qualifiers** (`/nursing`, `/psychology`) would sharpen “self-management” vs generic MG papers.
- Co-occurrence walk timed out at scale — add `^GRAPHREV` reverse index or precomputed facet counts (ydb-mesh feature).

## Sources (vanilla pass)
Findings files: `research/gmg-selfmg-vanilla/findings/F2.md`, `F3.md` (F1 guidelines agent cancelled; MGFA + Wiendl captured in F2/F3).  
YDB: U01 `ydb-mesh` globals `^GRAPH`, `^MESH`, `^AUTHOR` (author-pass 2026-10-10, 185M rows / 325M edges).


---

# Combined sources (deduped)

## A. M / standards / compilers / formal methods


## C. gMG evidence (findings files)
- MGFA energy conservation / dysphagia / 911 criteria — see `research/gmg-selfmg-vanilla/findings/F2.md`
- Wiendl 2023 German guideline; adherence MMAS studies; MG-ADL MCID; SC preference meta-analysis — `findings/F3.md`
- YottaDB: U01 `^GRAPH`/`^MESH`/`^AUTHOR` (author-pass 2026-10-10; MG MeSH D009157 = 17,042 papers)
