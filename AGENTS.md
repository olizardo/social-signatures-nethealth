# Global Agent Guidelines

**Location:** `~/.config/agents/AGENTS.md` (Update this file to persist lessons globally across all projects)

## General Coding Standards
- Write concise, readable code with descriptive naming over short abbreviations.
- Prefer functional paradigms and immutable data structures where practical.
- Always include unit tests when introducing new utility functions or endpoints.

## Git & Workflow
- Format all commit messages using Conventional Commits (`feat:`, `fix:`, `refactor:`).
- Keep changes scoped to the prompt; do not refactor unrelated code.

## Asynchronous & Background Execution Standards (CRITICAL)
- **The Five-Minute Rule**: Any operation, script, or transfer anticipated to take more than 5 minutes (or any operation involving large multi-megabyte/gigabyte file transfers or heavy compilations) **must** be executed as an asynchronous background process (e.g., `nohup ... > /tmp/task.log 2>&1 &`) rather than blocking the foreground interactive shell. This prevents hanging the terminal, exhausting timeouts, or stalling assistant responsiveness.
- **HPC / Hoffman2 Rsync Operations**: Never run large `rsync` transfers synchronously in the interactive terminal. Always launch file transfers from or to Hoffman2 in the background (e.g., `nohup rsync -avz hoffman2:remote_dir/ ./local_dir/ > /tmp/rsync_hoffman.log 2>&1 &`) and monitor progress via log inspection.

## Safety & Boundaries
- Never commit hardcoded secrets, `.env` files, or private keys.
- Always run the repository's test and lint suites before signaling task completion.

## Quarto & Reporting Standards
- **Decoupled Compute & Fast Rendering Architecture (CRITICAL)**:
  - **Zero In-Document Model Execution**: Heavy statistical models (e.g., `brmsfit`, large MCMC posteriors, multi-gigabyte datasets) must **never** be loaded or sampled directly inside `.qmd` code chunks during compilation.
  - **Standalone Asset Serialization (`Plots/*.png`)**: Generate all figures via standalone, modular R extraction scripts (e.g., `scripts/generate_plots.R`, `scripts/extract_fixed_effects_stability.R`) and serialize publication-grade PNGs to `Plots/`. Reference them in `.qmd` using native markdown syntax (`![](Plots/my_figure.png){fig-align="center" width="100%"}`). This allows Pandoc to base-64 embed assets in milliseconds under `embed-resources: true` without invoking graphics device loops.
  - **Pre-Compiled Markdown Tables vs. Dynamic Table Engines**: Compute model fit comparisons, parameter estimates, and stability envelopes in extraction scripts, outputting them to `cache/*.csv` and embedding them as clean, static GitHub-flavored markdown tables in the `.qmd`. This completely bypasses heavy runtime HTML widget/table engines (`gt`, `kableExtra`, `DT`).
  - **Pure Pandoc AST Compilation**: Structuring the `.qmd` as pure Markdown/LaTeX without active `{r}` execution blocks allows Quarto to bypass knitr kernel startup, serializing multi-figure, multi-table reports to standalone HTML in under 2 seconds.
  - **Multi-Tiered Cache Architecture (`cache/`)**: Save intermediate tabular summaries and extracted draws to `cache/` (e.g., `fixed_effects_stability_summary.rds`, `random_slopes_stability_summary.rds`) so that modifying a specific figure only re-executes that single script without re-running the entire analytical pipeline.
  - **Decoupled Extraction and Plotting**: Never load heavy models (e.g., 60MB `brms` `.rds` files) directly in plotting scripts (`plot_*.R`). Create dedicated extraction scripts (`extract_*.R`) that load the model ONCE, compute marginal effects, predicted probabilities, or posterior draws, and save lightweight dataframes to `Cache/summaries/`. Plotting scripts must only load these lightweight dataframes.
  - **Parallel Execution**: Once plotting scripts are decoupled from heavy models and rely only on lightweight summaries, execute them concurrently using GNU `parallel` or `xargs -P` rather than sequentially.
- When rendering a Quarto document via the `bash` tool, be hyper-aware that rendering artifacts might trigger ghost file creation if Quarto writes to directories that are currently open in the editor or currently being crawled by background tasks.
- If using `<REPORT>` tags provided by the `report` skill, **do not manually duplicate** the `.qmd` file creation. The `<REPORT>` tags automatically serialize to disk. Mixing `cat > file.qmd` with `<REPORT>` output will create duplicate files (e.g. `file-1.qmd`) that break the `quarto render` logic.
- Avoid using `size` in `ggplot2` for line layers (`geom_line`, `geom_segment`, `geom_errorbar`); always use the modernized `linewidth` aesthetic to prevent deprecation warnings from cluttering the render logs.
- When applying robust standard errors to multi-state categorical models (like `nnet::multinom`), `lmtest::coeftest` struggles to return the structure. Manually extract the `vcovCL` diagonals and calculate the Z-scores and P-values via matrix arithmetic to ensure stable dataframe conversion.

## Supercomputing & HPC Integration (UCLA Hoffman2)
The local machine is fully configured to deploy computationally intensive R jobs (e.g., Bayesian mixture models, large simulations) to the **UCLA Hoffman2 Cluster**.

### Deployment Workflow
When asked to run a model on Hoffman2, you must do the following from the bash tool:
1. **Create the Project Directory on Hoffman2:**
   `ssh -o BatchMode=yes hoffman2 "mkdir -p my_project/Scripts my_project/dta"`
2. **Write the `.sh` Submit Script Locally:** (Use a standard Grid Engine `qsub` template)

### Grid Engine (.sh) Script Template
When writing `.sh` SGE submission scripts to run models on the cluster from scratch, ALWAYS use this exact structure to guarantee the toolchain compiles CmdStan flawlessly across array tasks and stays under the 24-hour limit:

```bash
#!/bin/bash
#$ -cwd
#$ -j y
#$ -o output_job.log
#$ -l h_rt=23:50:00   # CRITICAL: Always bound to just under 24 hours
#$ -l h_data=4G       # Tightly restrict RAM per core (e.g. 4G per core)
#$ -pe shared 4       # Number of cores

# CRITICAL: Must initialize the module system first in non-interactive Grid Engine shells
source /u/local/Modules/default/init/bash

# Must load modern GCC before R
module load gcc/10.2.0
module load R

# Pass allocated cores to R
export CMDSTANR_CORES=$NSLOTS
export cmdstanr_no_ver_check=TRUE

# Stagger concurrent array tasks by 15 mins to avoid compile races
if [ ! -z "$SGE_TASK_ID" ] && [ "$SGE_TASK_ID" -eq 2 ]; then
  sleep 900
fi

# Example R command:
Rscript Scripts/your_model.R
```
3. **Sync Data and Scripts via rsync:**
   `rsync -avz my_data.dta hoffman2:my_project/dta/`
   `rsync -avz Scripts/my_model.R Scripts/submit_job.sh hoffman2:my_project/Scripts/`
4. **Submit the Job via SSH:**
   `ssh -o BatchMode=yes hoffman2 "cd my_project && qsub Scripts/submit_job.sh"`

### Hoffman2 Best Practices & Gotchas
- **Cluster Hygiene (CRITICAL)**: Never run `qdel` on Hoffman2 unless you explicitly created the job ID yourself during your current session, or the user explicitly commands you to kill a specific ID. The user runs multiple concurrent jobs for different projects that must not be disrupted.
- **Queue Optimization (Avoiding Indefinite Waits & "Forever Queues")**: 
  - Hoffman2's maximum time limit for the general campus base pool is **24 hours**. Requesting `h_rt > 24:00:00` automatically traps the job in a permanent queue unless you have dedicated physical node hardware (`highp` queues). 
  - To maximize compute time while guaranteeing the fair-share backfill scheduler places your job:
    1. **Always bound time to just under the limit** (e.g., `#$ -l h_rt=23:50:00`).
    2. **Tightly restrict memory to exactly what is needed per core** (e.g., `#$ -l h_data=3G` when using 16 cores) to ensure the total footprint doesn't block the scheduler.
  - *Note on Checkpointing:* While standard jobs can checkpoint and resume, `brms` (NUTS sampler) cannot resume NUTS adaptation mid-warmup. Thus, you must allocate sufficient cores (`threading(4)`) to ensure the model finishes within the 24-hour limit.
- **Array Job Strategies**: For iterating across independent datasets or running sequential model blocks rapidly, use Array Jobs (e.g., `#$ -t 1-N` or `run_on_hoffman script.R 8 12 4G 1-10`). This slices large requests into smaller chunks that backfill through the queue instantly.
  - *Staggering Locks*: When submitting an Array Job to a fresh environment, concurrent tasks will race to write to the `renv/library` directory, causing a `00LOCK-renv` crash. Always add a bash `sleep` stagger in the submit script (e.g., `sleep $(( (SGE_TASK_ID - 1) * 600 ))`) so Task 1 can finish building the library before subsequent tasks wake up.
- **Bypassing Obscure renv Compilation Crashes & CmdStan Linker Errors**: When restoring a massive project lockfile from source on Hoffman2, obscure downstream dependencies (like `QuickJSR`, `bslib`, or HTML widgets) often fail to compile and crash the entire pipeline. For raw modeling runs, bypass `renv::restore()` in the SGE script entirely. Instead, use base R to manually `install.packages('brms')` and `cmdstanr`. **CRITICALLY**, if you see Intel TBB linker errors (`undefined reference to tbb::interface...`) during model compilation, it means a stale `~/.cmdstan` directory was compiled under a different toolchain. Force a native compilation with `overwrite = TRUE` so CmdStan links against the currently loaded `gcc/10.2.0` and `tbb` modules. **However, in an Array Job, NEVER let all tasks run this concurrently** (they will overwrite and delete each other's source files). Wrap the call so only Task 1 performs the installation (`if(as.integer(Sys.getenv("SGE_TASK_ID", 1)) == 1) { cmdstanr::install_cmdstan(...) }`), and ensure the bash `sleep` stagger for subsequent tasks is at least 10 minutes (`600` seconds) so compilation finishes.
- **C++ Compilation Errors**: Hoffman2's default `R` module uses an outdated 2015 compiler (`gcc-4.8.5`). If you manually install packages on the cluster (or if `renv::restore()` is running), you *must* load a modern compiler (e.g., `module load gcc/10.2.0`) before loading R. Also load `module load cmake` to prevent `RcppParallel` installation failures. The `run_on_hoffman` script handles this automatically, preventing notorious C++11 literal spacing errors (e.g., `operator""_xl`) when compiling packages like `tidyr`, `dplyr`, or `brms`.
- **Bulletproof Hoffman2 SGE Template for brms**: When writing `.sh` SGE submission scripts to run models on the cluster from scratch, ALWAYS use this exact structure to guarantee the toolchain compiles CmdStan flawlessly across array tasks:
  ```bash
  # Must load modern GCC before R
  source /u/local/Modules/default/init/bash
  module load gcc/10.2.0
  module load R

  # CRITICAL: Prevent Hoffman's global TBB module from overriding CmdStan's internal TBB
  
  
  # CRITICAL: Stagger concurrent tasks by at least 15 minutes (900 seconds) 
  # so Task 1 can cleanly compile both CmdStan AND the first brms C++ model 
  # without Task 2 racing it to delete shared temporary compiler objects (e.g. main_threads.o)
  if [ "$SGE_TASK_ID" -eq 2 ]; then
    sleep 900
  fi
  
  # Pass allocated cores to R
  export CMDSTANR_CORES=$NSLOTS
  
  # CRITICAL: DO NOT export CMDSTAN in bash! If the directory is missing/empty, 
  # cmdstanr's .onLoad sequence crashes with an obscure `endsWith()` error.
  # Instead, export only the version check skip, and set the path safely inside R.
  export cmdstanr_no_ver_check=TRUE
  
  # Ensure ONLY Task 1 installs the CmdStan backend natively. 
  # Pin version to 2.33.1 to avoid the stanc --name bug with brms.
  # Force overwrite to avoid TBB linker crashes from stale builds.
  Rscript -e "
    options(repos = c(CRAN = 'https://cloud.r-project.org'))
    if (!requireNamespace('brms', quietly = TRUE)) install.packages('brms')
    if (!requireNamespace('cmdstanr', quietly = TRUE)) install.packages('cmdstanr', repos = c('https://mc-stan.org/r-packages/', getOption('repos')))
    
    # Load library FIRST, then set the path safely inside R
    library(cmdstanr)
    cmdstanr::set_cmdstan_path('~/.cmdstan/cmdstan-2.33.1')
    
    if(as.integer(Sys.getenv('SGE_TASK_ID', 1)) == 1) { 
      cmdstanr::install_cmdstan(version = '2.33.1', cores = Sys.getenv('NSLOTS', unset = 4), overwrite = TRUE) 
    }
  "
  Rscript Scripts/your_model.R
  ```
- **Dynamic Threads**: R scripts submitted to Hoffman must dynamically read `$NSLOTS` (e.g., `Sys.getenv("CMDSTANR_CORES")`) and calculate `threads_per_chain = floor(NSLOTS / 4)` to ensure `brms` fully utilizes the allocated node without sitting idle.
- **Authentication & SSH Config**: Passwordless SSH is fully configured for Hoffman2. The config file is located at `~/.ssh/config` (which sets the `hoffman2` alias, username `olizardo`, and keep-alive intervals). It relies on the `ed25519` cryptographic keys in the same `~/.ssh/` directory. AI agents MUST seamlessly use `ssh -o BatchMode=yes hoffman2 "command"` to directly interact with the cluster without prompting the user. Do not alter this configuration.

## R & Bayesian Modeling Practices
- **mclogit & mblogit**: 
  - When specifying crossed random effects in `mclogit::mblogit`, you **must** pass them as a list (e.g., `random = list(~ 1|individual_id, ~ 1|cluster_id)`). Using the `lme4` syntax (`~ 1|id + 1|cluster_id`) will crash with a `model frame and formula mismatch in model.matrix()` error.
- **Handling `renv` Sync Issues**:
  - When using Quarto/RMarkdown documents that require external compilation engines (like `rmarkdown` or `knitr`), ensure those packages are explicitly installed and snapshotted (`renv::install("rmarkdown"); renv::snapshot()`). Even if the scripts don't directly `library(rmarkdown)`, the `renv` environment requires them to render documents properly.
  - **Implicit Dependencies (e.g., `cmdstanr`)**: If a package is only passed as a string argument (e.g., `backend = "cmdstanr"` in a `brms::brm()` call), `renv`'s dependency discovery will miss it. Always add `library(cmdstanr)` explicitly at the top of your script before running `renv::snapshot()`. Otherwise, remote cluster runs using `renv::restore()` will fail because the package is absent from the lockfile.
- **Bayesian Mixture Models (brms)**:
  - **Label Switching**: Finite mixture models in Stan suffer from "label switching." Always apply ordered constraints (e.g., `order = "mu"`) when defining the mixture families to ensure chains converge to the same latent classes.
  - **Posterior Collapse (Random vs. Fixed Effects)**: Be extremely careful when using crossed random effects (`(1 | category)`) inside latent mixture distributions. Highly dense parameter spaces can cause the sampler to "give up" (shrink variance to zero), leading to posterior collapse and erasing group heterogeneity. Switching group-level variables to **fixed effects with interactions** (`category + time:category`) drastically improves stability and trajectory identification, despite increasing run times.
  - **Model Comparison (LOO vs WAIC & Socket Timeouts)**: While LOO-CV (`add_criterion(fit, "loo")`) is theoretically preferred over WAIC or information criteria (AIC/BIC) for finite mixture models (as the mathematical proofs for AIC/BIC break down in bounded mixture spaces), computing exact or approximate LOO-CV on complex models with many cores (e.g., 16) causes `parallel::makePSOCKcluster()` to crash with network socket timeouts on HPC nodes, destroying the model object *after* sampling completes but *before* saving. 
    - **Crucial Rule:** If you must use LOO, strictly limit it to `cores = 4` or fewer (e.g., `add_criterion(fit, "loo", cores = min(num_cores, 4))`). Alternatively, fall back to `WAIC` (`add_criterion(fit, "waic")`) to drastically reduce memory usage and completely bypass parallel socket timeouts.
    - **Crucial Rule 2 (Atomic Saving & Wall Limits):** NEVER chain NUTS sampling and `add_criterion()` in memory on HPC clusters. ALWAYS use the `file = "..."` argument natively inside `brm()` so the multi-hour posterior samples are immediately and atomically serialized to disk the second sampling finishes. Only *after* `brm()` saves the file should you call `add_criterion()` to compute fit statistics. This ensures that if the LOO/WAIC calculation crashes or hits an HPC 24h wall limit, the raw posterior draws are perfectly preserved.
  - **Adjacent Category Dispersion**: When fitting `brms` Adjacent Category models (`family = acat()`) that model variance/dispersion (`disc ~ ...`), the response variable *must* be an explicit `ordered` factor (e.g., `ordered(y)`). Unordered factors or integers will cause `brms` to crash during internal Stan data compilation.
- **Local vs Remote Execution**: Never accidentally include HPC-bound heavy models (like variance/dispersion SGE jobs) in local background queues (e.g., `systemd`). This will silently hang or starve the local machine. Strictly separate local queues from Hoffman submission scripts.


## Google Drive & Word Manuscript Table / Figure Synchronization
For projects where manuscripts, tables, and figures are synced with Google Drive / Microsoft Word (`.docx`):

### 0. Strict Non-Interactive & Autonomous Execution Protocol (CRITICAL)
- **Zero Permission Prompts (`dangerReason`)**: For routine file reading, script execution, data loading, or executing the `sync_*.R` / `sync_*.py` pipeline, **NEVER** set the `dangerReason` parameter in `executeCode` or `bash` tool calls. Populating `dangerReason` triggers unnecessary UI confirmation modals.
- **Immediate Turnkey Execution**: Whenever asked to revise, edit, add to, or update a Google Doc manuscript, do not hesitate, prompt for permissions, or perform destructive pandoc conversions. Immediately execute the established in-place OpenXML round-trip pipeline (`Rscript Scripts/sync_*.R`).
- **Seamless Authentication**: `googledrive::drive_auth(email = "omarlizardo@gmail.com")` uses cached tokens in `~/.cache/gargle/` and runs non-interactively without user prompts.

### 1. The Google Drive In-Place Injection Pipeline (CRITICAL)
- **Zero Style Disruption**: To completely preserve the live manuscript's typography, fonts, heading hierarchy, margins, line spacing, track changes, and collaborator comments, **never re-upload or overwrite the whole document via Pandoc conversion**.
- **The Drive Round-Trip Protocol**:
  1. Download the live draft via `googledrive::drive_download(as_id(DOC_ID), path = "draft_live.docx", overwrite = TRUE)`.
  2. Perform surgical XML injection on `word/document.xml`, `word/_rels/document.xml.rels`, and `word/media/` locally.
  3. Upload the updated document directly back to Drive via `googledrive::drive_update(as_id(DOC_ID), media = "draft_updated.docx")`.
- **Two Update Modes (Initial Insertion vs. Automatic Re-Sync)**:
  - **Initial Tag Injection**: Authors place tags wrapped in double curly braces where assets belong (e.g., `{{TABLE_1}}` or `{{PLOT_FOREST_M7}}`). The script replaces the tag paragraph with the native OpenXML table or plot image.
  - **Automated Caption-Anchored Updates (No Re-Tagging Required)**: Once a table or figure is in the document, subsequent model/data updates do **not** require re-inserting tags. The script automatically matches standard captions (e.g., `Table 1.`, `Figure 2.`) and replaces the adjacent `<w:tbl>` or `<w:drawing>` in-place with the latest version.

### 2. OpenXML Schema Compliance & Character Escaping Rules (Preventing 400 Bad Request)
- **Mandatory XML Character Escaping**: All text inserted into table cells, headers, or captions **must** be XML-escaped (`<` to `&lt;`, `>` to `&gt;`, `&` to `&amp;`, `"` to `&quot;`). For example, unescaped p-values like `<0.001` produce `<w:t><0.001</w:t>`, which corrupts the XML syntax and causes Google Drive's import filter to fail with `400 Bad Request`.
- **Strict ECMA-376 Tag Ordering**:
  - Inside `<w:pPr>`: `<w:suppressAutoHyphens/>` -> `<w:spacing/>` -> `<w:ind/>` -> `<w:jc/>`. (Out-of-order elements violate XML schemas and trigger upload errors).
  - Inside `<w:tcPr>`: `<w:tcW/>` -> `<w:tcBorders/>` -> `<w:noWrap/>`.

### 3. Figure Injection, Relationship Mapping & Exact Aspect Ratios
- **Strict Relationship Tracing**: In OpenXML, drawing elements (`<w:drawing>`) reference image files via relationship IDs (`r:embed="rIdX"`). Never assume the order of `rId`s matches the order of `imageX.png` files or figure appearance. Always parse `word/_rels/document.xml.rels` to map `rIdX` -> `media/imageY.png` and confirm with the adjacent caption text (`Figure 1.`, `Figure 2.`).
- **Dual DrawingML Extent Synchronization**: When updating an image, **both** `<wp:extent cx="..." cy="..."/>` and `<a:ext cx="..." cy="..."/>` in `word/document.xml` **must** be updated simultaneously to match the image's exact native aspect ratio:
  - Width is set to full printable text width ($6.5 \text{ inches} = 5,943,600 \text{ EMUs}$).
  - Height in EMUs: $\text{height\_EMU} = \text{round}(5,943,600 \times (\text{pixel\_height} / \text{pixel\_width}))$.
  - Failing to synchronize extents causes Google Docs to stretch/squish images into old container dimensions.

### 4. Universal APA Table Style & Formatting Standards (MANDATORY)
All manuscript tables injected into Google Docs / Word documents across all projects must strictly conform to these formatting specifications:

1. **Width & Proportional Column Allocations**:
   - Total table width must scale to full **6.5-inch printable portrait width** (`w:w="9360" w:type="dxa"`).
   - **Column 1 (Row Labels / Models)**: Must be allocated wider space (~36–42% of total table width = 3,400–3,900 dxa) to prevent multi-line text wrapping.
   - **Numeric / Statistic Columns**: Remaining table width (58–64%) is divided proportionally across subsequent columns.
   - Define exact `<w:gridCol w:w="..."/>` in `<w:tblGrid>` and `<w:tcW w:w="..." w:type="dxa"/>` on each table cell.

2. **Column Title Length & Anti-Squish Budgeting**:
   - For narrow columns (under 0.8 in / 1,100 dxa), keep column headers concise (e.g., `Model`, `Under`, `Over`, `Both`, `Par`, `WAIC (SE)`, `ΔWAIC`) to fit without line breaks or column squishing.
   - Embed standard errors in parentheses in the same cell (`WAIC (SE)` or `Est (SE)`) rather than creating separate SE columns.

3. **Anti-Word-Break & Hyphenation Controls (Fit Whole Words to Columns)**:
   - **No Mid-Word Splitting**: Every paragraph inside table cells must include `<w:suppressAutoHyphens/>` in `<w:pPr>` to strictly prevent words from breaking or hyphenating mid-word across lines.
   - **No Wrap on Numbers**: Include `<w:noWrap/>` in `<w:tcPr>` for all numeric/statistic cells so numbers, estimates, and confidence intervals stay strictly on a single line.

4. **Horizontal Text Alignment**:
   - **Column 1 (Row Labels)**: Strictly left-justified (`<w:jc w:val="left"/>`).
   - **All Other Columns (Estimates, Statistics, Percentages)**: Strictly center-justified (`<w:jc w:val="center"/>`).

5. **Pagination & Page Break Controls**:
   - **Row Protection**: Every table row (`<w:trPr>`) must include `<w:cantSplit/>` to prevent individual rows from being sliced across page breaks.
   - **Repeating Header Rows**: The header row must include `<w:tblHeader/>` so column headers repeat automatically when a table spans multiple pages.

6. **Paragraph Indentations & Spacing**:
   - **Zero Indentation**: Strip all paragraph indentations from inside the table environment (`<w:ind w:left="0" w:right="0" w:firstLine="0" w:hanging="0"/>`).
   - **Tight Vertical Spacing**: Set zero before/after paragraph spacing (`<w:spacing w:before="0" w:after="0"/>`).

7. **Decimal Precision & Number Formatting**:
   - **Percentages**: Format strictly to **1 decimal place** (e.g., `79.9%`, `65.4%`).
   - **Model Estimates & Odds Ratios**: Format strictly to **2 decimal places** (e.g., `0.35`, `1.42`, `-0.18`), with directional significance bolding where appropriate.
   - **Standard Errors / Confidence Intervals**: Format strictly to **2 decimal places** (e.g., `(0.04)`).
   - **Sample Sizes (N, J)**: Format as integers with comma separators (e.g., `10,695`).

8. **APA 7th Horizontal Borders & Cell Padding**:
   - **Horizontal Rules**: 1pt top border (`sz="8"`), 0.5pt header-bottom border (`sz="4"`), 1pt table-bottom border (`sz="8"`).
   - **Zero Vertical Borders**: Set vertical and interior vertical borders to `w:val="none"`.
   - **Cell Padding (Margins)**: Top and bottom padding set to `120` dxa (6pt); left and right padding set to `160` dxa (8pt).

9. **Cross-Group & Multi-Category Layout (Vertically Stacked Panels vs. Horizontal Compression)**:
   - **Avoid Horizontal Squeezing**: When comparing multiple groups across several categorical levels, avoid side-by-side columns (which creates 7–11 narrow columns under 0.6 inches wide).
   - **Vertically Stacked Panels**: Stack groups vertically as distinct panels (*Panel A: Group 1*, *Panel B: Group 2*) sharing the same top column headers. Use a full-width spanning section header row (`<w:gridSpan w:val="N"/>`) with bold/italic title (`<w:b/><w:i/>`), and indent sub-item row labels in Column 1 (`<w:ind w:left="140"/>`).

10. **Model Parameter Column Naming**:
    - In model fit and specification comparison tables, standardly name the parameter count column **`Par`** or **`N. Par`** (rather than `Params` or `Parameters`) to maintain concise, consistent APA presentation.

### 5. Authentication
- Use `googledrive::drive_auth(email = "omarlizardo@gmail.com")`. Cached gargle tokens in `~/.cache/gargle/` provide seamless, non-interactive authentication.

### 6. Intermediate File Cleanup & Workspace Hygiene (MANDATORY)
- **Zero Artifact Leaks**: The Drive download, OpenXML DOM injection, and Pandoc text verification pipeline generates transient `.docx`, `.txt`, and `.json` scratch files (e.g., `draft_live.docx`, `draft_updated.docx`, `draft_verify.txt`, `replacements.json`). These files must never be allowed to accumulate in the workspace.
- **Automated `on.exit()` / `try...finally` Cleanup**:
  - In R master driver scripts (`sync_manuscript.R`), register an `on.exit()` handler to ensure scratch files are purged even if an error occurs mid-execution:
    ```r
    on.exit({
      unlink(Sys.glob("draft_*.docx"))
      unlink(Sys.glob("draft_*.txt"))
      unlink(Sys.glob("*.tmp"))
      unlink("replacements.json")
    }, add = TRUE)
    ```
  - In Python scripts (`sync_manuscript.py`), implement a `cleanup_scratch_files()` utility with a `--cleanup` command-line argument:
    ```python
    import glob, os

    def cleanup_scratch_files(keep=None):
        keep_set = set(os.path.abspath(f) for f in (keep or []) if os.path.exists(f))
        patterns = ["draft_*.docx", "draft_*.txt", "replacements.json", "*.tmp"]
        for pat in patterns:
            for f in glob.glob(pat):
                if os.path.abspath(f) not in keep_set:
                    try: os.remove(f)
                    except OSError: pass
    ```
- **Standard `.gitignore` Rules**:
  Every project implementing this workflow must include the following rules in `.gitignore`:
  ```gitignore
  # Drive sync intermediate files
  draft_*.docx
  draft_*.txt
  draft.docx
  draft_updated.docx
  draft_live.docx
  replacements.json
  *.tmp
  .tmp/
  ```

### 8. Document Styles, Paragraphs, Headings, and Caption Normalization Standards (MANDATORY)
When updating manuscripts in Google Docs / Word via OpenXML injection, scripts must maintain total stylistic fidelity with the document's native styles (`docDefaults` and `styles.xml`). Never allow disparate paragraphs or heading levels to diverge:

1. **Title Page Protection Standards (Title, Subtitle, Author, Date, Spacing)**:
   - **Preserve Title Styles**: Any paragraph styled with `Title` or `Subtitle` (or representing the document title) must retain `<w:pStyle w:val="Title"/>` or `Subtitle`, zero first-line indent (`<w:ind w:left="0" w:right="0" w:firstLine="0" w:hanging="0"/>`), and center alignment (`<w:jc w:val="center"/>`).
   - **Protect Title Page Metadata**: All cover page metadata paragraphs preceding the first substantive section heading (`Heading1` / `Introduction`)—including author names, affiliations, survey team labels, dates, and empty vertical spacing paragraphs—must retain center alignment (`jc="center"`) and zero first-line indent (`firstLine="0"`), strictly preventing standard 0.5-inch body indentation from corrupting the title page layout.
   - **Section Page Break Preservation**: Section breaks (`<w:br w:type="page"/>` or `<w:pageBreakBefore/>`) separating the title page from the main body must never be deleted.

2. **Surgical Additions & Terminological Precision vs. Zero Wholesale Rewriting (CRITICAL)**:
   - Once a manuscript is live on Google Drive and authors are actively revising, scripts and agents must treat the downloaded document as the canonical source of truth for text, subheadings, and structure.
   - **Zero Text Rewriting During Formatting Passes (MANDATORY)**: When performing formatting, style normalization, typography adjustments, line spacing changes, or indentation fixes, **NEVER alter, rewrite, condense, summarize, or replace the underlying prose text** of the manuscript or abstract. Formatting scripts must operate strictly on paragraph properties (`<w:pPr>`), run properties (`<w:rPr>`), styles (`styles.xml`), and document defaults (`docDefaults`), leaving the textual content of `<w:t>` elements 100% untouched. Any substantive text revisions or length reductions (such as shortening the abstract) must be handled through explicit user review or direct author drafting, never bundled into automated style or formatting passes.
   - **Targeted Additions & Terminological Adjustments Are Encouraged**: It is fully appropriate to insert newly requested literature citations, targeted conceptual arguments, hypotheses, table/figure references, and surgical terminological adjustments (e.g., standardizing *beliefs in objective taste* or *experiences of beauty*, and purging improper uses of *democratic*).
   - **Zero Wholesale Rewriting**: Never replace entire existing paragraph blocks with hardcoded local versions that discard or revert the author's live prose edits, phrasing choices, or stylistic revisions in the live Google Doc. Operate in surgical, non-destructive in-place mode.

3. **Body Prose Paragraphs (Normal Document Style Fidelity)**:
   - **Inherit Native Defaults**: All standard body prose paragraphs must follow the document's **Normal** style (`<w:pStyle w:val="Normal"/>` or default).
   - **Mutual Exclusivity of First-Line Indent and Hanging Indent in OpenXML (CRITICAL)**:
     - In ECMA-376 OpenXML schema and Google Docs' Word import engine, `w:firstLine` (positive first-line indentation) and `w:hanging` (hanging indentation) are mutually exclusive opposites.
     - When enforcing a first-line indent (`<w:ind w:left="0" w:right="0" w:firstLine="720"/>`), **NEVER specify `w:hanging="0"`**. If `w:hanging` is present in the XML element attributes, it must be explicitly deleted (`del ind.attrib['{...}hanging']`). If both `firstLine` and `hanging="0"` are present, Google Docs treats the paragraph as having a 0-width hanging indent, which completely wipes out and zeroes the first-line indent (`firstLine="0"`).
     - Conversely, for references requiring a hanging indent, specify strictly `<w:ind w:left="720" w:hanging="720" w:right="0"/>` without any `w:firstLine` attribute.
   - **Strip Hardcoded Paragraph Overrides**: Remove direct paragraph-level overrides on `w:ind` (e.g., `firstLine="0"`) and `w:spacing` (e.g., `line="240"`, `spacing after="180"` or `spacing before="180"`), so that body paragraphs cleanly inherit the local document style defaults (typically 11pt/12pt font, 1.5 line spacing `line="360"`, 0.5-inch first-line indent `firstLine="720"`, full justification `jc="both"`).
   - **Clean Direct Run Overrides**: Strip accidental whole-paragraph bolding (`<w:b/>`), stray shading/highlighting (`<w:shd>`), stray baseline alignments (`<w:vertAlign w:val="baseline"/>`), and hardcoded font/size/color overrides (`<w:rFonts>`, `<w:sz>`, `<w:color>`) so body text renders in the document's default font family and color (e.g., `Alegreya Sans`, 11pt, `#222222`).
   - **Preserve Genuine Semantic Markup**: Always preserve inline semantic formatting (such as `<i>` for italics like *ex ante*, quotes, book/work titles, and statistical symbols $N$, $J$, $\text{WAIC}$, $\text{OR}$, $\Delta$, $p < 0.001$).

4. **Heading Level & Style Hierarchy**:
   - **Level 1 Headings (`Heading1`)**: Style: `<w:pStyle w:val="Heading1"/>`, `<w:ind w:left="0" w:right="0" w:firstLine="0" w:hanging="0"/>`, left-aligned. Strip direct run-level bold/color/size overrides so headings cleanly inherit the document's native `Heading1` style definition (e.g., 16pt, dark red `#943634`, spacing before 300 / after 60).
   - **Level 2 Headings (`Heading2`)**: Style: `<w:pStyle w:val="Heading2"/>`, `<w:ind w:left="0" w:right="0" w:firstLine="0" w:hanging="0"/>`, left-aligned. Strip direct run-level bold/color/size overrides so headings cleanly inherit the native `Heading2` style definition (e.g., 14pt, dark red `#943634`, spacing before 200).
   - **Level 3 Headings (`Heading3`)**: Style: `<w:pStyle w:val="Heading3"/>`, `<w:ind w:left="0" w:right="0" w:firstLine="0" w:hanging="0"/>`, left-aligned. Strip direct run-level bold/size/color overrides (inheriting 12pt italic dark red `#943634`, spacing before 60).
   - **Purge Ghost/Empty Heading Paragraphs**: Automatically scan for and delete any blank/empty paragraphs styled with `Heading1`, `Heading2`, or `Heading3`.

5. **Table Captions, Figure Captions, and Notes**:
   - **Table Captions (`Table X. ...`)**: Zero first-line indent (`<w:ind w:left="0" w:right="0" w:firstLine="0" w:hanging="0"/>`), bold caption text (`<w:b/>`), left-aligned, tight vertical spacing (e.g., `before="60" after="80"`).
   - **Figure Captions (`Figure X. ...`)**: Captions must be **purely descriptive** of what the figure displays without interpretative results claims. Styled with zero first-line indent (`<w:ind w:left="0" w:right="0" w:firstLine="0" w:hanging="0"/>`), bold caption text (`<w:b/>`), left or justified alignment (`jc="both"` or `jc="left"`), tight vertical spacing (`before="60" after="160"`), and document house font (`Alegreya Sans`, 12pt).
   - **Table & Figure Notes (`Note: ...`)**: Style strictly as `Heading4` (footnote size 11pt/10pt) with zero first-line indent (`<w:ind w:left="0" w:right="0" w:firstLine="0" w:hanging="0"/>`), bold `Note:` prefix label, and tight vertical spacing (`before="60" after="120"`).
   - **Figure Drawings (`<w:drawing>`)**: Zero first-line indent, centered alignment (`jc="center"`), tight spacing before/after.

6. **Math Formatting & Normal Text Translation Standards (CRITICAL)**:
   - **Zero Raw LaTeX Math Delimiters in Markdown**: Never use raw TeX math delimiters (`$...$` or `$$...$$`) in markdown drafts intended for Google Docs synchronization. When Pandoc encounters TeX math, it emits Word `<m:oMath>` / `<m:oMathPara>` blocks that hardcode Cambria Math (serif) fonts, trigger XML parsing warnings, and frequently cause Google Docs to fail conversion (rendering raw TeX syntax warnings).
   - **Unicode & Semantic Text Runs**: Write all mathematical expressions using clean Unicode characters with standard semantic italics and superscripts/subscripts (e.g., *p~i,w~*(*r*) = *w~ij(r),w~* / *W~i,w~*, *d*~self~, *d*~ref~, *α*, *β*, *p* < 10^-12^, *R*^2^ = 0.935, *β* = 0.098).
   - **Automated `<m:oMath>` to `<w:r>` Conversion**: Formatting scripts (`format_manuscript.py`) must implement `convert_omath_to_runs()` to traverse the XML DOM, extract any remaining math text, set `rFonts` explicitly to the document font (e.g., `Alegreya Sans`), set `sz` to `22` (11pt), italicize single-letter variables (*N*, *p*, *r*, *k*, *J*, *d*), and replace `<m:oMath>` with standard `<w:r>` runs.

7. **Preventing Generic Word Style Resets in Google Docs**:
   - **The Pandoc Style Trap**: Pandoc compiles markdown paragraphs with styles `BodyText` and `FirstParagraph`. If these style IDs are missing from `styles.xml`, or if `w:rFonts` contains theme attributes (`asciiTheme="minorHAnsi"`), Google Docs cannot resolve the font hierarchy and resets the entire document to its internal generic default (Calibri 11pt, 1.15 line spacing, 0 indent).
   - **Stripping Alien Style Identifiers**: Formatting scripts must automatically strip `<w:pStyle w:val="BodyText"/>` and `<w:pStyle w:val="FirstParagraph"/>` from body paragraphs so they cleanly default to `Normal`.
   - **Purging Theme Attributes**: Delete `asciiTheme`, `hAnsiTheme`, `cstheme`, and `eastAsiaTheme` from `w:docDefaults` and all run definitions, forcing Word and Google Docs to read explicit font definitions (`w:ascii="Alegreya Sans"`).
   - **Injecting Proven Template Styles**: Always package verified reference templates (`templates/styles.xml` and `templates/fontTable.xml`) into the `.docx` archive during formatting passes.

8. **Standalone Empirical Paper Framing (Zero "Slide Extension" Jargon)**:
   - When reviving or expanding projects from preliminary presentation slide decks (e.g., conference talks or lab presentations), **never** write the manuscript as a mere "replication of slides" or an "extension of preliminary presentations."
   - Always frame the manuscript from the ground up as an authoritative, standalone empirical paper with its own conceptual narrative, research questions, and theoretical stakes.
   - Ground the introduction in foundational literature (e.g., evolutionary cognitive constraints, Dunbar's social brain, slot-filling hypothesis, tie strength theory).
   - Preliminary slide presentations may be cited as prior work in the literature review or footnotes, but the text must speak as an independent empirical study.

### 7. Turnkey Setup & Workflow Architecture for Any Project
To implement this synchronization workflow in any project, establish the following standardized structure:

#### Project Directory Convention:
```
project/
├── Scripts/
│   ├── sync_manuscript.R        # Master R driver (run via: Rscript Scripts/sync_manuscript.R)
│   ├── sync_manuscript.py       # DOM-based OpenXML table & figure injector
│   └── generate_md_tables.R     # Pre-computes markdown tables to cache/
├── cache/                       # Intermediate markdown tables (table1_wald.md, etc.)
└── Plots/                       # Publication-grade PNG figures (6.5 inches wide, 300 DPI)
```

#### Template 1: Master Driver Script (`Scripts/sync_manuscript.R`)
```r
#!/usr/bin/env Rscript
library(googledrive)

# 1. Configuration: Note document ID from Google Doc URL
doc_id <- "YOUR_GOOGLE_DOC_ID_HERE"
live_docx <- "draft_live.docx"
updated_docx <- "draft_updated.docx"

message("[1/4] Ensuring table summaries in cache/ are up to date...")
if (file.exists("Scripts/generate_md_tables.R")) {
  source("Scripts/generate_md_tables.R")
}

message("[2/4] Downloading live manuscript from Google Drive...")
drive_auth(email = "omarlizardo@gmail.com")
drive_download(as_id(doc_id), path = live_docx, overwrite = TRUE)

message("[3/4] Performing in-place XML injection of tables and figures...")
exit_code <- system2("python3", args = c("Scripts/sync_manuscript.py", live_docx, updated_docx))
if (exit_code != 0) {
  stop("Error during in-place XML injection.")
}

message("[4/4] Uploading updated manuscript back to Google Drive...")
drive_update(as_id(doc_id), media = updated_docx)

# Clean up local temporary files
if (file.exists(live_docx)) unlink(live_docx)
if (file.exists(updated_docx)) unlink(updated_docx)
message("Synchronization complete! Google Doc updated successfully.")
```

#### Template 2: OpenXML DOM Injector (`Scripts/sync_manuscript.py`)
```python
import os
import re
import sys
import zipfile
import struct
import xml.etree.ElementTree as ET

def xml_escape(s):
    if s is None: return ""
    return str(s).replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace('"', "&quot;")

def get_png_dimensions(image_path):
    with open(image_path, "rb") as f:
        data = f.read(24)
        if len(data) >= 24 and data.startswith(b'\x89PNG\r\n\x1a\n'):
            return struct.unpack('>II', data[16:24])
    return 1950, 1200

def parse_markdown_table(file_path):
    with open(file_path, "r", encoding="utf-8") as f:
        lines = [line.strip() for line in f if line.strip()]
    table_lines = [line for line in lines if line.startswith("|") and line.endswith("|")]
    if len(table_lines) < 3: return [], []
    headers = [c.strip() for c in table_lines[0].strip("|").split("|")]
    rows = []
    for line in table_lines[2:]:
        row = [c.strip() for c in line.strip("|").split("|")]
        rows.append(row)
    return headers, rows

def create_apa_table_xml(headers, rows_data, col_widths=None):
    total_w = 9360  # 6.5 in portrait width in dxa
    num_cols = len(headers)
    if col_widths is None:
        col1_w = int(total_w * 0.40)
        rem_w = total_w - col1_w
        sub_w = int(rem_w / (num_cols - 1))
        col_widths = [col1_w] + [sub_w] * (num_cols - 2)
        col_widths.append(total_w - sum(col_widths))
        
    xml = [f'<w:tbl xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:tblPr><w:tblW w:w="{total_w}" w:type="dxa"/><w:tblBorders><w:top w:val="single" w:sz="8" w:space="0" w:color="000000"/><w:left w:val="none"/><w:bottom w:val="single" w:sz="8" w:space="0" w:color="000000"/><w:right w:val="none"/><w:insideH w:val="none"/><w:insideV w:val="none"/></w:tblBorders><w:tblCellMar><w:top w:w="120" w:type="dxa"/><w:bottom w:w="120" w:type="dxa"/><w:left w:w="160" w:type="dxa"/><w:right w:w="160" w:type="dxa"/></w:tblCellMar></w:tblPr><w:tblGrid>']
    for w in col_widths: xml.append(f'<w:gridCol w:w="{w}"/>')
    xml.append('</w:tblGrid>')
    
    # Header Row
    xml.append('<w:tr><w:trPr><w:tblHeader/><w:cantSplit/></w:trPr>')
    for i, h in enumerate(headers):
        align = "left" if i == 0 else "center"
        escaped_h = xml_escape(h)
        xml.append(f'<w:tc><w:tcPr><w:tcW w:w="{col_widths[i]}" w:type="dxa"/><w:tcBorders><w:bottom w:val="single" w:sz="4" w:space="0" w:color="000000"/></w:tcBorders><w:noWrap/></w:tcPr><w:p><w:pPr><w:suppressAutoHyphens/><w:spacing w:before="0" w:after="0"/><w:ind w:left="0" w:right="0" w:firstLine="0" w:hanging="0"/><w:jc w:val="{align}"/></w:pPr><w:r><w:rPr><w:b/></w:rPr><w:t>{escaped_h}</w:t></w:r></w:p></w:tc>')
    xml.append('</w:tr>')
    
    # Data Rows
    for row in rows_data:
        xml.append('<w:tr><w:trPr><w:cantSplit/></w:trPr>')
        for i, val in enumerate(row):
            align = "left" if i == 0 else "center"
            escaped_val = xml_escape(val)
            xml.append(f'<w:tc><w:tcPr><w:tcW w:w="{col_widths[i]}" w:type="dxa"/><w:noWrap/></w:tcPr><w:p><w:pPr><w:suppressAutoHyphens/><w:spacing w:before="0" w:after="0"/><w:ind w:left="0" w:right="0" w:firstLine="0" w:hanging="0"/><w:jc w:val="{align}"/></w:pPr><w:r><w:t>{escaped_val}</w:t></w:r></w:p></w:tc>')
        xml.append('</w:tr>')
    xml.append('</w:tbl>')
    return "".join(xml)

def generate_table_xmls():
    # Map each manuscript table caption to parsed markdown table and column widths
    tables = {}
    # Example:
    # h1, r1 = parse_markdown_table("cache/table1_results.md")
    # tables["Table 1"] = create_apa_table_xml(["Model", "Estimate", "SE", "p"], r1, [3860, 1800, 1800, 1900])
    return tables

def sync_docx(in_docx, out_docx):
    with zipfile.ZipFile(in_docx, "r") as zin:
        xml_bytes = zin.read("word/document.xml")
        rels_bytes = zin.read("word/_rels/document.xml.rels")
        all_files = {item.filename: zin.read(item.filename) for item in zin.infolist()}
    
    root_rels = ET.fromstring(rels_bytes)
    rid_to_target = {e.get('Id'): e.get('Target') for e in root_rels if e.get('Id')}
    
    # Map caption prefixes to figure images
    figure_map = {
        # "Figure 1.": "Plots/fig1.png",
        # "Figure 2.": "Plots/fig2.png"
    }
    
    ET.register_namespace('w', 'http://schemas.openxmlformats.org/wordprocessingml/2006/main')
    ET.register_namespace('a', 'http://schemas.openxmlformats.org/drawingml/2006/main')
    ET.register_namespace('r', 'http://schemas.openxmlformats.org/officeDocument/2006/relationships')
    ET.register_namespace('wp', 'http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing')
    
    doc_tree = ET.fromstring(xml_bytes)
    ns = {
        'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main',
        'a': 'http://schemas.openxmlformats.org/drawingml/2006/main',
        'r': 'http://schemas.openxmlformats.org/officeDocument/2006/relationships',
        'wp': 'http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing'
    }
    body = doc_tree.find('w:body', ns)
    
    # 1. Update Figures in-place
    if figure_map:
        body_list = list(body)
        for i, elem in enumerate(body_list):
            text = ''.join(elem.itertext()).strip()
            for fig_caption, img_path in figure_map.items():
                if fig_caption in text and os.path.exists(img_path):
                    for offset in range(0, 4):
                        idx = i - offset
                        if 0 <= idx < len(body_list):
                            candidate = body_list[idx]
                            blips = candidate.findall('.//{http://schemas.openxmlformats.org/drawingml/2006/main}blip')
                            if blips:
                                for blip in blips:
                                    rid = blip.attrib.get('{http://schemas.openxmlformats.org/officeDocument/2006/relationships}embed')
                                    if rid and rid in rid_to_target:
                                        target_media = "word/" + rid_to_target[rid]
                                        with open(img_path, "rb") as f_img:
                                            all_files[target_media] = f_img.read()
                                        
                                        pw, ph = get_png_dimensions(img_path)
                                        cx = 5943600  # 6.5 in portrait width in EMUs
                                        cy = int(round(5943600 * (ph / pw)))
                                        for wp_ext in candidate.findall('.//wp:extent', ns):
                                            wp_ext.set('cx', str(cx))
                                            wp_ext.set('cy', str(cy))
                                        for a_ext in candidate.findall('.//a:ext', ns):
                                            a_ext.set('cx', str(cx))
                                            a_ext.set('cy', str(cy))
                                break

    # 2. Update Tables in-place (DOM Sibling Search)
    tables = generate_table_xmls()
    if tables:
        body_list = list(body)
        for i, elem in enumerate(body_list):
            text = ''.join(elem.itertext()).strip()
            for caption_key, tbl_xml in tables.items():
                if text.startswith(caption_key) or f'{caption_key}:' in text or f'{caption_key}.' in text:
                    for j in range(i + 1, min(len(body_list), i + 6)):
                        sibling = body_list[j]
                        if sibling.tag.endswith('tbl'):
                            new_tbl_elem = ET.fromstring(tbl_xml)
                            idx_in_body = list(body).index(sibling)
                            body.remove(sibling)
                            body.insert(idx_in_body, new_tbl_elem)
                            break
                            
    all_files["word/document.xml"] = ET.tostring(doc_tree, encoding="utf-8", xml_declaration=True)
    
    with zipfile.ZipFile(out_docx, "w", compression=zipfile.ZIP_DEFLATED) as zout:
        for fname, data in all_files.items():
            zout.writestr(fname, data)

if __name__ == "__main__":
    if len(sys.argv) >= 3:
        sync_docx(sys.argv[1], sys.argv[2])
```

### 9. Critical Operational Lessons & Edge-Case Safeguards for Live Document Syncing
Across collaborative manuscripts where authors actively edit online while agents perform programmatic updates, agents must strictly enforce the following safeguards:

1. **Canonical Source of Truth & Safe Two-Way Syncing (Never Blind-Overwrite User Edits)**:
   - Once a manuscript is live on Google Drive, human authors frequently perform direct prose edits, merge paragraphs, eliminate figures/tables, and customize table cells directly online.
   - **Crucial Rule:** The downloaded `draft_live.docx` is the canonical source of truth for text, headings, and table structures.
   - **Decoupled Data Injection (`--inject-tables`)**: Do NOT automatically overwrite user-edited tables with local markdown files unless explicit table injection is requested. Formatting, image refreshes, and figure renumbering passes must preserve user table edits and text revisions intact.

2. **Font Contamination, Math Markup & Run-Level Override Sanitization (The "Alien Font" Trap)**:
   - External paste operations and equation editors often insert direct run-level font declarations (e.g., `<w:rFonts w:ascii="Nova Mono"/>`, `<w:rFonts w:ascii="Cardo"/>`) or Office Math markup (`<m:oMath>`, `<m:oMathPara>`) into the OpenXML tree.
   - Because run-level `<w:rFonts>` and `<m:oMath>` override the document's default `docDefaults` / `Normal` style, Google Docs and Word will render numbers, Greek symbols ($\Delta$, $\theta$), and equations in alien serif (`Cardo`, `Cambria Math`) or monospace typefaces.
   - **Crucial Rule:** Always execute a normalization pass on `word/document.xml` that: (a) converts all `<m:oMath>`/`<m:oMathPara>` blocks to standard text runs (`<w:r>`); (b) strips all direct `<w:rFonts>`, stray `<w:shd>`, `<w:highlight>`, `<w:color>`, and `<w:sz>` tags so that all numbers, variables ($N$, $p$, $J$, $\text{WAIC}$), and symbols render cleanly in the document house font (`Alegreya Sans`); and (c) sanitizes `word/fontTable.xml` to remap foreign fonts to `Alegreya Sans`.

3. **Page Breaks & Section Boundary Preservation in Appendices**:
   - In manuscripts with extensive appendices (e.g., Appendix Sections A through E), explicit page breaks (`<w:br w:type="page"/>` or `<w:pageBreakBefore/>`) define clean section transitions.
   - **Crucial Rule:** Never strip or collapse empty paragraphs that carry `<w:br w:type="page"/>`. Verify that appendix section breaks remain intact across sync cycles.

4. **Atomic Sequential Figure & Table Renumbering (Preventing Cascading Regex Collisions)**:
   - When a figure or table is removed (e.g., Figure 4 deleted, so Figure 5 becomes Figure 4, Figure 6 becomes Figure 5), applying sequential linear replacements (`replace("Figure 5", "Figure 4"); replace("Figure 6", "Figure 5")`) causes cascading collisions (Figure 6 -> Figure 5 -> Figure 4).
   - **Crucial Rule:** Always use atomic token/lambda replacement with word boundaries:
     ```python
     mapping = {'5': '4', '6': '5', '7': '6'}
     text = re.sub(
         r'\bFigure\s+([567])\b',
         lambda m: f'Figure {mapping.get(m.group(1), m.group(1))}',
         text,
     )
     ```
   - Update both the caption paragraphs (`Figure X. ...`) AND all corresponding in-text narrative references (`As shown in Figure X...`).

5. **Immediate Parity between Live Document and Local Accounting**:
   - Whenever figures or tables are added, removed, or renumbered in the Google Doc, immediately synchronize:
     - The project's `sync_manuscript.py` `figure_mappings` list
     - The project memory (`AGENTS.md` Figure & Table taxonomy)
     - `Scripts/Plotting_and_QA/README.md`
   - This ensures any future agent or subagent working in the repo operates from the exact same numbering and asset inventory.

### 10. Surgical Live Document Updating & Anti-Collision Protocols (CRITICAL - ALL AGENTS)
When collaborating on live manuscripts hosted on Google Drive where authors actively write and revise online, all programmatic edits and sync scripts must enforce these anti-collision safeguards:

1. **The Human In-Flight Collaboration Rule (The Live Document Is King)**:
   - When manuscripts are live on Google Drive, human authors perform continuous edits (refining prose, fine-tuning paragraph spacing, reordering lines, customizing table cells, adding comments, and resolving track changes).
   - Never assume local files, templates, or hardcoded scripts represent current prose. Every sync cycle must start with a fresh download (`googledrive::drive_download()`) of the live draft.

2. **Idempotent Structural Restructuring (The "Check-Before-Inject" Pattern)**:
   - When asked to restructure a section (e.g., inlining hypotheses into subsections, reordering headings), the script must check whether the target structure is *already present* in the document (e.g., `has_inlined_hypotheses = any(...)` or checking for heading titles).
   - If the structure is already present, the script **must skip section re-injection** and enter non-destructive pass-through mode. This prevents re-injecting hardcoded templates over author edits made after the initial restructuring.

3. **Surgical Single-Node / Run-Level DOM Targeting**:
   - For targeted text revisions (e.g., updating a hypothesis citation, fixing a typo, removing a duplicated sentence):
     - Locate the exact `<w:p>` node via text matching in `.itertext()`.
     - **Preserve the `<w:pPr>` block intact** (inheriting existing paragraph styles, spacing, indents, and alignment).
     - Modify only the targeted text inside `<w:r>` runs.
     - Never regenerate or overwrite surrounding paragraphs or the broader section.

4. **Preserving Inline Semantic Markup (`<w:rPr>`)**:
   - Word OpenXML stores italics (`<w:i/>`), bold (`<w:b/>`), subscripts, and superscripts at the run level (`<w:r>`).
   - Plain string replacement on paragraph text will strip formatting tags. When constructing replacement text, use a helper that tokenizes inline markup (e.g., `<i>...</i>`, `<b>...</b>`) and builds corresponding `<w:r>` runs so italicized terms, book titles, and statistical symbols ($p < 0.001$, $N$, $\Delta$) are never flattened into plain text.

5. **Decoupled Asset Replacement (Zero Prose Side-Effects)**:
   - Tables and figures must be updated strictly via DOM sibling search and relationship ID mapping.
   - Replacing Table 3 or Figure 2 must never touch, reflow, or alter adjacent introductory or discussion paragraphs.

6. **Preserving Paragraph Spacing, Blank Lines, and Page Breaks**:
   - Authors use deliberate paragraph spacing (`before`, `after`, line spacing) and page breaks (`<w:br w:type="page"/>`).
   - Sync scripts must never indiscriminately purge "empty" paragraphs that contain page breaks, and must never strip custom `pPr` spacing definitions from body paragraphs unless explicitly cleaning alien overrides.

7. **The Two-Way Local Markdown Synchronization Rule**:
   - Immediately after applying a surgical edit to the live document, update `current_text.md` to reflect the change so that the local markdown mirror remains 100% faithful to the live document.

8. **Remote Formatting & Style Preservation Standard (MANDATORY - ZERO OVERWRITING)**:
   - **Preserve All Author Styling & Formatting**: Any formatting, typography, styling, font choices, line spacing, margins, color palettes, heading hierarchies, paragraph alignments, track changes, or layout adjustments made by human authors remotely in Google Docs / Word must be **100% preserved** across all future sync cycles and draft updates.
   - **Never Overwrite with Pandoc Re-compilation**: Once a document is live on Google Drive, scripts and agents must **never** overwrite it by uploading a fresh Pandoc-compiled `.docx` file. Pandoc re-compilation wipes out custom remote styles, comments, track changes, and typography.
   - **Strict In-Place DOM Injection**: All future updates must operate strictly via the in-place OpenXML round-trip protocol (`draft_live.docx` -> surgical DOM injection -> `draft_updated.docx`). Only targeted `<w:tbl>` (table) and `<w:drawing>` (figure) nodes are modified in `word/document.xml`, leaving all remote paragraph properties (`<w:pPr>`), font properties (`<w:rPr>`), section styles, and document defaults completely intact.

## Bayesian Model Visualization Standards (`ggdist` & `ggplot2`)

When visualizing Bayesian posterior distributions, marginal effects, random coefficients, and ordinal transitions from `brms` or `cmdstanr` models across any project, all agents must strictly adhere to these unified publication standards:

### 1. Directional Credibility Criterion (95% Posterior Mass)
- **Mathematical Definition**: An effect or contrast is statistically credible if at least **95% of the posterior probability mass** falls strictly on one side of zero ($P(\theta > 0) \ge 0.95$ or $P(\theta < 0) \ge 0.95$).
- **Extraction Code Standard**:
  ```r
  credibility <- plot_draws %>%
    group_by(Condition, Threshold) %>%
    summarise(
      conf_low  = quantile(draw, 0.025),
      conf_high = quantile(draw, 0.975),
      p_pos     = mean(draw > 0),
      p_neg     = mean(draw < 0),
      .groups   = "drop"
    ) %>%
    mutate(
      Credible = ifelse(p_pos >= 0.95 | p_neg >= 0.95, "Credible Shift", "No Credible Shift")
    )
  ```
  *(Note: Checking `conf_low > 0` on a standard two-tailed 95% interval enforces a 97.5% one-tailed threshold; computing `p_pos >= 0.95` correctly evaluates directional hypothesis credibility).*

### 2. Dual-Interval Multi-Width Thickness in `stat_halfeye`
- Always supply `.width = c(0.80, 0.95)` to represent both the narrow **80% credible interval** and the wider **95% credible interval**.
- **CRITICAL Sizing Rule**: Always specify `interval_size_range = c(0.75, 1.9)` (or `c(1.5, 4.0)`).
- **NEVER pass a single fixed scalar** like `interval_size = 1.2`. Passing a single scalar overrides `ggdist` interval scaling and collapses both the 80% and 95% bars into the identical line thickness, contradicting figure captions that reference "thick and thin bars".

### 3. Marker & Color Mapping for Statistical Credibility (Grayscale Standard)
- **Credible Shift (≥ 95% Mass)**: Render as a solid circle (`shape = 16` / default point) filled with the condition or directional color (Deep Blue `#0072B2` for positive, Vermillion `#D55E00` for negative).
- **No Credible Shift / Spanning Zero (< 95% Mass)**: Render in **grayscale** (`"gray60"`), using solid markers (`shape = 16` / default point).
- **Grayscale Consistency Rule**: Across all plots (single-series, multi-condition, and directional transitions), non-credibility is indicated consistently via **grayscale color/fill** rather than hollow/white-filled circles.
- **Standard Sizing**: Set `point_size = 4.8` (or `3.2` on dense multi-facet plots).

### 4. Half-Eye Density Slab Standards
- Set `slab_alpha = 0.15` (or `0.20`) with `scale = 0.65` so the posterior density cloud provides a subtle, aesthetic backdrop without cluttering the intervals and points.

### 5. Standardized `stat_halfeye` Code Template
```r
stat_halfeye(
  point_interval = median_qi,
  .width = c(0.80, 0.95),
  point_size = 4.8,
  interval_size_range = c(0.75, 1.9),
  slab_alpha = 0.15,
  scale = 0.65,
  position = position_dodge(width = 0.6)
) +
scale_color_manual(values = COLOR_CREDIBILITY, name = "Directional Credibility") +
scale_fill_manual(values = COLOR_CREDIBILITY, name = "Directional Credibility")
```

### 6. Responsive Legend & Subtitle Layout (Preventing Horizontal Clipping)
- **Controlled Row Guide Strips**: Enforce `nrow = 1` for short single-series legends, or wrap into multiple rows (`nrow = 2` or `nrow = 3`, `byrow = TRUE`) for multi-category or vertically stacked facet plots on standard 6.5-inch canvases to prevent horizontal margin overflow or clipping:
  ```r
  guides(
    color = guide_legend(nrow = 2, byrow = TRUE, override.aes = list(shape = 16, size = 4.5, linetype = 0)),
    fill  = "none",
    shape = guide_legend(nrow = 1, override.aes = list(color = "black", fill = "white", size = 4.5, stroke = 1.5))
  )
  ```
- **Legend Centering**: Use `theme(legend.box = "horizontal", legend.box.just = "center", legend.spacing.x = unit(0.4, "cm"), legend.margin = margin(t = 4, b = 2))`.
- **Subtitle & Caption Wrapping**: Ensure long subtitles and captions include explicit line breaks (`\n`) or use `stringr::str_wrap(subtitle, width = 75)` so text never clips at the plot margins.

## Visualization & Table Presentation Standards
- **Standard 6.5-Inch Image Width**: Export all publication plots at `width = 6.5` inches (300 DPI) to match the exact printable text width of a standard 1.0-inch margin portrait page.
- **Credible / Not-Credible Plotting Strategy (Grayscale Standards)**:
  - **Credibility Criterion**: An effect is statistically credible if >= 95% of the posterior probability mass falls strictly to the right or left of zero (Q2.5 > 0 or Q97.5 < 0).
  - **Credible Effects**: Rendered with **solid filled markers** (`shape = 16` / default point) and directional color (Deep Blue `#0072B2` for positive / upper tier, Vermillion `#D55E00` for negative / comparison tier).
  - **Not Credible (Spanning Zero)**: Rendered in **grayscale** (`"gray60"`) with standard solid markers.
- **Domain Axis Ordering Standard (Beauty Encounters)**:
  - In all Bayesian posterior plots for beauty encounters, order the domain y-axis according to the **overall correlation between the binary domain indicator and educational attainment** (ranked from lowest correlation at the bottom to highest correlation at the top):
    1. **Literature** (Top, $r \approx +0.15$)
    2. **Visual Arts** ($r \approx +0.12$)
    3. **Built Places** ($r \approx +0.12$)
    4. **Music** ($r \approx +0.06$)
    5. **Screen Media** ($r \approx +0.06$)
    6. **Food & Drink** ($r \approx +0.03$)
    7. **Fashion & Style** ($r \approx +0.025$)
    8. **Crafts & DIY** (Bottom, $r \approx +0.015$)
    *(Factor levels in R: `c("Crafts & DIY", "Fashion & Style", "Food & Drink", "Screen Media", "Music", "Built Places", "Visual Arts", "Literature")`)*.
- **Vertical Panel Stacking & Common X-Axis Standard (`ncol = 1`)**:
  - For multi-category demographic plots (e.g. Educational Capital, Political Ideology, and Age Cohorts), **stack panels vertically in a single column (`facet_wrap(~ Category, ncol = 1)`) on a common fixed x-axis** rather than side-by-side or 2x2 grids with independent `free_x` scales.
  - **Visual Advantages**:
    - **Direct Top-Down Scanning**: Facilitates natural vertical eye movement across ordinal progressions (e.g. *Bachelor's* $\rightarrow$ *Postgraduate*, *Right* $\rightarrow$ *Center* $\rightarrow$ *Left* $\rightarrow$ *Very Left*, *35–44* $\rightarrow$ *65+*).
    - **Continuous Vertical Reference Line**: The dashed zero line ($x = 0$) aligns unbroken down the entire column.
    - **Elimination of Scale Distortion**: Every unit of shift represents the exact same physical horizontal distance across all panels, ensuring accurate cross-category visual comparisons.
  - **Standard Sizing**:
    - 2-panel vertical stacks: `width = 6.5` in, `height = 7.2` in.
    - 4-panel vertical stacks: `width = 6.5` in, `height = 9.8` in.
- **Demographic Disparity Dumbbells**:
  - For natural probability scale visualizations (0%-100%), use connected horizontal dumbbell charts to display the baseline prevalence alongside the disparity span between demographic poles (e.g., Men vs. Women, No Degree vs. Postgrad, Very Right vs. Very Left, 65+ vs. 18-34, Minimizing vs. Maximizing profiles).
  - **Geometric Shape Differentiation**: Use distinct solid geometric shapes (e.g., **Solid Circles `shape = 16`** for Reference / Minimizing profiles and **Solid Triangles `shape = 17`** for Comparison / Maximizing profiles) with uniform point size (`size = 3.6`) and country palette coloring (`#D55E00` for US, `#0072B2` for UK) rather than subtle size or open-stroke variations.
  - Label the percentage point gap directly next to each dumbbell (`+24 pp`, `0 pp`, etc.).
- **Controlled Legend Rows & Margins**:
  - Multi-item legends must explicitly use `guide_legend(nrow = 2, byrow = TRUE)` or `nrow = 1` with generous margins to prevent horizontal canvas overflow.
  - Facet strips must be concise, centered (`hjust = 0.5`), with generous panel spacing (`panel.spacing = unit(1.8, "lines")`).
- **Concise Embedded Plot Headers**: Keep plot-embedded titles and subtitles concise (e.g., `< 55` characters) so they never wrap awkwardly or clip horizontally at 6.5 inches.
- **Figure Notes at Bottom**: Place figure titles and notes at the bottom of the figure block. In notes, describe graphical elements (slopes definition, probability densities, median points, 80%/95% intervals, and color coding) without raw code variables or narrative effect-size claims.
- **Simplified Regression Tables**:
  - Omit wide bracketed ranges `[Q2.5, Q97.5]` from cells in favor of clean point estimates with directional credibility bolding/asterisks (e.g., `<b>0.251***</b>`).
  - Strip technical/range metadata from row labels (e.g., `Variable Name` instead of `Variable Name (1-4)`).
  - Embed sample sizes ($N_{\text{obs}}$, $N_{\text{respondents}}$, $J_{\text{clusters}}$), priors, and model fit diagnostics ($\text{WAIC}, \Delta\text{WAIC}$) directly into bottom summary rows of the regression table.

## Global Academic Writing & Style Guidelines
- **Quotation Marks Standard (Double Typographic Quotes vs. Single Quotes)**:
  - Strictly use **double quotation marks** (“...”) for quotations, named concepts, coined phrases, and colloquial terms (e.g., “omnivorous generation”, “cultural omnivore”, “high art”, “inclusive elitists”) rather than single quotes (‘...’ or '...').
  - Reserve single quotation marks (‘...’) strictly for quotations or terms nested inside other quotations.
  - Avoid using straight single quotes (`'...'`) in running manuscript prose, abstracts, titles, and captions for general terminology or quotation.
- **Prohibition of "Democratic" for Egalitarian / Pervasive Distribution**:
  - Strictly do **NOT** use the word *"democratic"*, *"democratically"*, or *"democratization"* when what is meant is *egalitarian*, *equally distributed*, *widely distributed*, *broad-based*, *pervasive*, or *widespread*.
  - "Democratic" is a specific term from political theory and political science denoting a particular kind of political regime or system of governance, not cultural prevalence, widespread adoption, or evaluative egalitarianism.
  - Strictly use **"widely distributed"**, **"broadly distributed"**, **"egalitarian"**, **"pervasive"**, **"broad-based"**, or **"equalization"** instead (e.g., *“aesthetic experience is widely distributed across the general public”* rather than *“democratically distributed”*; *“egalitarian tolerance”* rather than *“democratic tolerance”*).
- **Abstract and Title Page Preservation (Zero Author Overwriting - CRITICAL)**:
  - Once an author makes edits to the Abstract, Title, or Title Page metadata in the live Google Doc, sync scripts and agents must **NEVER** blind-overwrite, replace, or revert the author's live prose with hardcoded text strings.
  - Every sync cycle must preserve 100% of the live author edits to the Abstract and Title Page, applying only non-destructive OpenXML DOM styling (inheriting Alegreya Sans, 0-indent justified body, centered metadata) without modifying the underlying text.
- **Author and Scholar Naming Conventions**:
  - When citing or referring to particular scholars or theorists by name in narrative text, strictly use only their **last name** (e.g., **Bourdieu** instead of *Pierre Bourdieu*, **Dewey** instead of *John Dewey*, **Lamont** instead of *Michèle Lamont*), except where full names are explicitly required to disambiguate scholars sharing a surname or within full bibliographic entries.
- **Hypothesis Formatting Standards**:
  - When stating or listing formal hypotheses in text, do **not** attach parenthetical titles or labels to the hypothesis prefix (e.g., use strictly **Hypothesis 1:** or *Hypothesis 1: ...* without adding parenthetical names like *(Democratic Distribution)*, *(Cultural Stratification)*, or *(Aesthetic Omnivorousness)*).
- **Gender & Demographic Terminology Standards**:
  - Avoid using 'male' and 'female' as nouns to refer to people when writing up results; strictly use **'men'** and **'women'**.
  - Always use the term **'Gender Identity'** (or 'Gender') rather than **'Sex'** across all write-ups, variable definitions, table row/column headers, and figure labels.
- **Per-Figure Analytical Discussion Standard**:
  - In empirical reports and manuscripts featuring multi-figure visualization sequences, **every visual figure must be accompanied by its own dedicated discussion paragraph** (or introductory prose) situated immediately beneath its subsection heading and preceding/following the figure asset.
  - Discussion paragraphs must walk through specific domain estimates, directional shifts, credible contrasts, and substantive takeaways for that figure rather than grouping all commentary into a single generic section note.
- **Strict Anti-Hyperbole & Empirical Tone Standards**:
  - Strictly prohibit hyperbolic, dramatic, or sensationalist terms (e.g., *'massive'*, *'gigantic'*, *'profound'*, *'dramatic'*, *'stark'*, *'breakthrough'*, *'monumental'*, *'unprecedented'*, *'complete neutrality'*, *'without exception'*).
  - Use measured, precise empirical descriptions (e.g., *'substantial'*, *'largest'*, *'gradient'*, *'difference'*, *'attenuated'*, *'limited differentiation'*).
  - Always hedge and qualify analytical claims (e.g., *'suggests'*, *'indicates'*, *'is associated with'* rather than *'proves'*, *'confirms that'*, *'confers'*).
- **Word Choice Standards ("Show" vs. "Demonstrate", "Use" vs. "Utilize")**:
  - Strictly use **"show"**, **"shows"**, **"showing"**, and **"shown"** rather than **"demonstrate"**, **"demonstrates"**, **"demonstrating"**, or **"demonstrated"** across all analytical prose, empirical write-ups, hypothesis descriptions, and theoretical discussions.
  - Strictly use **"use"**, **"uses"**, **"using"**, and **"used"** rather than **"utilize"**, **"utilizes"**, **"utilizing"**, **"utilized"**, or **"utilization"**.
- **Prohibition of "Modern" for Statistical Methods and Approaches**:
  - Strictly do **NOT** use the word **"modern"** to refer to statistical methods, models, frameworks, techniques, or analytical approaches.
  - Strictly use **"recent"** or **"recently developed"** instead (e.g., *“recent age-period-cohort methods”*, *“recently developed partial identification frameworks”*, *“recent APC bounding techniques”*).
- **Avoidance of "Robust" as a Generic Evaluative Adjective**:
  - Strictly avoid using **"robust"**, **"robustly"**, or **"robustness"** as generic evaluative praise, vague intensifiers, or stylistic filler (e.g., avoid *“robust findings”*, *“robust typologies”*, *“robust evidence”*, *“robust relationship”*, *“robust patterns”*).
  - Use precise, descriptive alternatives instead (e.g., *“consistent”*, *“stable”*, *“reliable”*, *“persistent”*, *“well-supported”*, *“pronounced”*, *“systematic”*).
  - Reserve **"robust"** strictly for formal, recognized methodological or statistical techniques where it is an established technical term (e.g., *“robust standard errors”*, *“Huber-White robust covariance”*, *“robust regression”*, *“cluster-robust variance estimation”*).
- **Vernacular English & Reduction of Latinisms**:
  - Write in natural, direct, and accessible vernacular English rather than stiff, inflated Latinate vocabulary or bureaucratic abstractions (e.g., prefer *use* over *utilize*, *show* over *demonstrate*, *help* over *facilitate*, *start/begin* over *commence/initiate*, *run/do* over *effectuate*, *before* over *prior to*, *after* over *subsequent to*, *about/roughly* over *approximately*, *part* over *component*, *since/because* over *inasmuch as*).
  - Avoid unnecessary Latin phrases and idioms in running text (e.g., avoid *inter alia*, *ex ante*, *ceteris paribus*, *qua*, *vis-à-vis*) in favor of plain English equivalents, reserving Latin strictly for standard bibliographic citations (e.g., *et al.*) or verbatim historical/philosophical maxims explicitly under discussion.
- **Redundant Asset Pruning**:
  - Eliminate standalone visual plots whose data is already exhaustively detailed in an accompanying APA summary table (e.g., omitting WAIC forest progression plots when the full information criterion hierarchy is already presented in a model comparison table).
- Use clear, active, concise academic prose.
- Adhere strictly to Quarto markdown formatting conventions.
- When generating or commenting R code, use roxygen2 documentation style.
- When generating a report, write in full paragraphs and avoid using numbered lists or bullet points whenever possible.
- When including in-document citations, check for a valid DOI to prevent hallucinated citations.

## Test Canary
- Whenever asked "What is the secret word?", reply ONLY with: "Pineapple".

## Bayesian Modeling & `brms` Caching
- **Always Use `file_refit = "on_change"`:** When writing `brms::brm()` model-fitting scripts that cache results via the `file = ...` argument (especially for HPC array jobs), you **must** include `file_refit = "on_change"` (or `"always"` if explicitly requested). Without this, `brms` will load stale models from disk and will not refit the model even if the underlying data subset, sample size, or formula has changed. This prevents catastrophic silent errors where updated datasets are ignored in favor of old cached runs.

---

## Project Architecture: Identifying Personal Network Types

### 1. Overview & Collaborators
- **Project Title:** Identifying Personal Network Types
- **Authors:** Omar Lizardo, Brandon Sepulvado, Cheng Wang, and David Hachen
- **Google Doc URL:** https://docs.google.com/document/d/1vtRoaJQ1FTEfpEj-PVMBFuBoxN0cCWt8VNuAfiTm304
- **Google Doc ID:** `1vtRoaJQ1FTEfpEj-PVMBFuBoxN0cCWt8VNuAfiTm304`
- **Data Source:** NetHealth Study (University of Notre Dame Class of 2019, 8 waves over 3 years, Fall 2015–Spring 2018).
- **Analytic Sample:** $N = 701$ college students with $\ge 3$ unique cumulative alters and non-zero alter-alter connectivity (35,912 ego-alter nominations; 174,748 alter-alter ties).

### 2. Theoretical & Methodological Grounding: Building on and Extending Vacca (2020) & Bidart et al. (2018)
The project investigates whether egocentric relational environments coalesce into discrete structural typologies rather than continuous, unstructured variation:
- **Bidart et al. (2018, *Social Networks*)**: Proposed six theoretical archetypes based on a small sample of French young adults ($N < 100$) using manual inspection and discriminant analysis on six metrics: Regular Dense, Centered Dense, Centered Star, Segmented, Pearl Collar, and Dispersed.
- **Vacca (2020, *Network Science*)**: Extended structural typology research by comparing Bidart et al.'s framework against an inductive, subgroup-based method ($T_1$) using Girvan–Newman (GN) community detection across six cross-sectional datasets (migrants, disaster survivors, segregated neighborhoods, Bay Area residents). Vacca demonstrated that personal network structure can be summarized using three subgroup measures (subgroups $\ge 3$ nodes, singletons/dyads, and partition modularity) and clustered via $k$-medoids.

#### How Our Study Builds on Vacca (2020):
1. **Topological Over Attribute-Based Classification**: Like Vacca, we reject purely compositional/attribute-based classifications in favor of formal alter-alter network topology.
2. **Subgroup and Cohesion Metrics**: We systematically evaluate community modularity (Louvain), component fragmentation, main component share (LCC), and density alongside betweenness centralization and diameter.
3. **Inductive Unsupervised Clustering**: Like Vacca, we use unsupervised clustering and formal cluster validation heuristics rather than subjective assignment.
4. **Medoid Graph Representation**: Building on Vacca's emphasis on medoid solutions, we identify empirical medoids (exemplar participants minimizing distance to centroids) and render their actual alter-alter graphs.

#### How Our Study Differs from and Advances Beyond Vacca (2020):
1. **Longitudinal Dynamics vs. Cross-Sectional Snapshots**:
   - *Vacca (2020)* examined cross-sectional datasets with static network measures.
   - *Our Study* leverages eight multi-wave survey administrations across three years to examine:
     - **Cumulative Personal Networks** ($N = 701$), capturing the full volume of relational capital accumulated across collegiate life ($\bar{x} = 28.6$ alters, max $= 83$).
     - **Semester-to-Semester Markov State Transitions (HMMs)**: We model $N = 1,900$ transitions across 2,821 ego-wave observations. While Regular Dense networks exhibit high persistence (70.8%), students experience substantial structural mobility, with expansive Pearl Collar configurations emerging cumulatively across academic years.
2. **Empirical Classification Decision Tree with Data-Driven Cutoffs**:
   - Rather than relying on black-box cluster assignments or Bidart's heuristic cutoffs, we train a classification tree (`rpart`) that achieves **92.9% accuracy**.
   - We discover that in residential campus environments, alter-alter density ($\ge 0.55$) is the primary root splitting criterion rather than betweenness centralization ($> 0.20$), and we provide explicit, reproducible cutoffs for all four typologies.
3. **Multilevel Contextual Nesting (Dorm & Major Clustering)**:
   - Vacca compared aggregate distributions across disparate regional datasets.
   - We estimate multilevel categorical logit models (`mclogit::mblogit`) with crossed random intercepts for freshman residence halls ($J = 29$) and academic majors ($J = 43$). We quantify institutional sorting, finding substantial clustering attributable to residential dorms ($\bar{\sigma}^2 = 0.164$) and academic disciplines ($\bar{\sigma}^2 = 0.268$).
4. **Psychological Grounding (Big Five Personality)**:
   - We integrate validated Big Five personality dimensions, demonstrating that Extraversion ($b = +0.81$, $p < 0.001$) and Conscientiousness ($b = -0.85$, $p < 0.01$) directly predict avoidance of closed network bubbles, establishing an empirical bridge between individual dispositions and network topology.

### 3. Current Directory Structure & Asset Taxonomy
```
project/
├── AGENTS.md                         # Global & project-specific guidelines (source of truth for agents)
├── draft_manuscript.md               # Active local manuscript mirror (pure Markdown, no code chunks)
├── presentation.qmd                  # Quarto Reveal.js presentation
├── presentation.html                 # Compiled Reveal.js presentation slides
├── analysis.Rmd                      # Reproducible R pipeline
├── dat/                              # Processed analytical datasets
│   ├── data_clusters-4-km_demog_lgcc.csv  # Master ego-level analytical dataset (N = 701)
│   └── kmeans-4-*.csv                # Breakdown tables (descriptives, demographics, Big 5)
├── raw_dat/                          # Downloaded raw NetHealth survey data
│   ├── alter_alter_edges.csv         # 174,748 alter-alter evaluations
│   ├── network_survey.csv            # 35,912 ego-alter nominations
│   └── basic_survey.csv              # Demographics, residence halls, majors, Big 5
├── Plots/                            # Publication-grade PNG figures (6.5 in wide, 300 DPI)
│   ├── fig1_size_distribution.png
│   ├── fig2_cluster_selection.png
│   ├── fig3_cluster_profiles.png
│   ├── fig4_decision_tree.png
│   ├── fig5_metric_correlations.png
│   ├── fig6_network_archetypes.png
│   ├── fig7_comparative_decision_trees.png
│   ├── fig8_longitudinal_transitions.png
│   ├── fig9_demographic_dumbbells.png
│   └── fig10_personality_profiles.png
├── cache/                            # Pre-compiled APA markdown tables
│   ├── table1_structural_metrics.md
│   ├── table2_cluster_selection.md
│   ├── table3_demographics.md
│   ├── table4_regressions.md
│   ├── table5_big5_regression.md
│   ├── table6_markov_transitions.md
│   └── table7_multilevel_categorical.md
├── tabs/                             # Formatted regression HTML & PNG tables
│   ├── reg-tab-gender.*
│   ├── reg-tab-foreign.*
│   ├── reg-tab-ses.*
│   └── reg-tab-big5.*
└── Scripts/                          # Modular execution pipeline
    ├── generate_plots_and_tables.R   # Computes figures and tables to Plots/ and cache/
    ├── sync_manuscript.py            # In-place OpenXML DOM table & figure injector
    └── sync_manuscript.R             # Master Drive sync driver (Rscript Scripts/sync_manuscript.R)
```

### 4. Tables and Figures Inventory in Live Google Doc (Strict Sequential Order)
- **Figure 1**: Cumulative Ego-Network Size Distribution Across NetHealth Participants (`Plots/fig1_size_distribution.png`)
- **Figure 2**: Cluster Partition Quality Diagnostics Across Candidate Solutions ($k = 2$ to 10; Elbow & Silhouette criteria) (`Plots/fig2_cluster_selection.png`)
- **Table 1**: Descriptive Statistics of Personal Network Structural Metrics by Typology ($N = 701$) (`cache/table1_structural_metrics.md`)
- **Table 2**: Cluster Partition Quality Diagnostics Across Candidate Solutions ($k = 2$ to 10; WSS, % Variance Explained, Silhouette, Calinski-Harabasz) (`cache/table2_cluster_selection.md`)
- **Figure 3**: Standardized Topological Profiles Across Personal Network Typologies ($2 \times 2$ comparative grid displaying $z$-score deviations from cohort mean in standard deviation units; replaces old squished 1x5 lollipop layout) (`Plots/fig3_cluster_profiles.png`)
- **Figure 4**: Pairwise Pearson Correlation Heatmap Across Personal Network Metrics (`Plots/fig5_metric_correlations.png`)
- **Figure 5**: Empirical Network Archetypes: Force-Directed Layouts of Cluster Medoids (`ggraph` stress layout) (`Plots/fig6_network_archetypes.png`)
- **Figure 6**: Empirical Decision Tree for Classifying Personal Network Typologies (92.9% accuracy) (`Plots/fig4_decision_tree.png`)
- **Figure 7**: Comparative Decision Tree Graphic: Bidart Theoretical Heuristics vs. NetHealth Empirical Cutoffs (`Plots/fig7_comparative_decision_trees.png`)
- **Table 3**: Semester-to-Semester Markov State Transition Probability Matrix ($N = 1,900$ transitions) (`cache/table6_markov_transitions.md`)
- **Figure 8**: Semester-to-Semester Markov State Transition Probability Heatmap (`Plots/fig8_longitudinal_transitions.png`)
- **Table 4**: Cross-Tabulation of Network Typology by Demographic and Socioeconomic Characteristics (`cache/table3_demographics.md`)
- **Figure 9**: Demographic Disparity Dumbbell Charts for Personal Network Typologies (Gender Identity and International Student Status) (`Plots/fig9_demographic_dumbbells.png`)
- **Table 5**: Multinomial Logistic Regressions Predicting Personal Network Typology Membership (Gender & International Status) (`cache/table4_regressions.md`)
- **Table 6**: Multilevel Multinomial Logit with Crossed Random Effects for Residence Halls ($J = 29$) and Majors ($J = 43$) (`cache/table7_multilevel_categorical.md`)
- **Figure 10**: Big Five Personality Trait Means Across Personal Network Typologies (`Plots/fig10_personality_profiles.png`)
- **Table 7**: Multinomial Logistic Regression Predicting Network Typology from Big Five Personality Traits (`cache/table5_big5_regression.md`)

### 5. Canonical Citations for the NetHealth Study
Any future write-up, manuscript revision, or slide deck referencing the NetHealth Study must cite the canonical project publications:
- **Liu, S., Hachen, D., Lizardo, O., Poellabauer, C., Striegel, A., & Milenković, T. (2018)**. Network analysis of the NetHealth data: Exploring co-evolution of individuals’ social network positions and physical activities. *Applied Network Science*, 3(1), 45. https://doi.org/10.1007/s41109-018-0103-2
- **Sepulvado, B., Wood, M., Wang, C., Fridmanski, E., Chandler, M., Lizardo, O., & Hachen, D. (2020)**. Predicting homophily and social network connectivity from dyadic behavioral similarity trajectory clusters. *Social Science Computer Review*, 40(1), 186–205. https://doi.org/10.1177/0894439320923123
- **Wang, C., Lizardo, O., & Hachen, D. S. (2020)**. Neither influence nor selection: Examining co-evolution of political orientation and social networks in the NetSense and NetHealth studies. *PLOS ONE*, 15(5), e0233458. https://doi.org/10.1371/journal.pone.0233458

### 6. Strict Protocol for Future Autonomous Agents
1. **The Live Google Doc Is King (ZERO OVERWRITING)**: The human author actively edits and styles the Google Doc online. Never overwrite the live document by uploading a fresh Pandoc-compiled `.docx` file. Pandoc re-compilation destroys user typography, paragraph margins, track changes, and comments.
2. **Download First**: Every synchronization or editing run must begin by downloading `draft_live.docx` via `googledrive::drive_download(as_id(doc_id), path = "draft_live.docx", overwrite = TRUE)`.
3. **In-Place OpenXML Injection Only**: All asset updates must be applied directly to the downloaded `draft_live.docx` XML tree using DOM sibling search / relationship mapping (`Scripts/sync_manuscript.py`), updating only `<w:tbl>` and `<w:drawing>` containers.
4. **Intermediate File Cleanup**: Always purge scratch files (`draft_*.docx`, `draft_*.txt`, `*.tmp`, `replacements.json`) via `on.exit()` in R or `try...finally` in Python.
5. **Style Compliance**:
   - Double typographic quotes (“...”) for named typologies.
   - Never use "democratic" for egalitarian / widely distributed / pervasive.
   - Use "men" and "women" (never "male" / "female" as nouns).
   - Use "Gender Identity" (or "Gender") rather than "Sex".
   - Avoid using the generic adjective "robust" (reserve strictly for technical terms like "robust standard errors").
   - Every visual figure must be accompanied by its dedicated analytical discussion paragraph.

---

## Project Architecture: Classifying and Predicting Degree Trajectories in Longitudinal Ego Networks

### 1. Overview & Collaborators
- **Project Title:** Classifying and Predicting Degree Trajectories in Longitudinal Ego Networks
- **Authors:** Omar Lizardo, Matthew J. Chandler, and David Hachen
- **Google Doc URL:** https://docs.google.com/document/d/147PaI7iC0LPB12CI_sT6XY_gCg76JKFkPP18maTc9TQ
- **Google Doc ID:** `147PaI7iC0LPB12CI_sT6XY_gCg76JKFkPP18maTc9TQ`
- **Data Source:** NetHealth Study (University of Notre Dame, 8 waves over 4 years, Fall 2015–Spring 2019: https://sites.nd.edu/nethealth/).
- **Analytic Samples:**
  - *Benchmark Waves 1–6 Sample:* $N = 450$ participants with $\ge 3$ network surveys in Waves 1–6, complete baseline survey, and passive phone compliance.
  - *Expanded Waves 1–8 Sample:* $N = 457$ participants tracked through senior-year graduation.

### 2. Theoretical Grounding & Empirical Design
The project investigates how personal network size (degree) changes dynamically across the collegiate life course, whether individuals follow distinct, predictable degree pathways, and how baseline psychological traits and sociodemographic background predict these trajectories:
1. **Replication of Chandler & Hachen (Sunbelt 2018)**:
   - Evaluates six trajectory classification schemes: Deductive 8-category decision tree, simplified 4-category scheme, raw $k$-means ($k=7, 9$), and demeaned $k$-means ($k=4, 8$).
   - Estimates 84 multinomial logistic regression models across Demographic ($n=30$), Personality ($n=18$), and Mixed ($n=36$) specifications.
   - Replicates core findings: Personality traits (Extraversion, Neuroticism, Openness) and Generalized Trust consistently predict trajectory membership, whereas standard socioeconomic indicators (parental income, parental education, citizenship, sex) show negligible explanatory power.
2. **Expansion 1: Latent Class Growth Analysis (LCGA) with Poisson Mixtures (`flexmix`)**:
   - Replaces continuous Euclidean $k$-means with formal repeated-measures Poisson finite mixture models across $K = 1 \dots 5$.
   - Accurately respects the bounded, non-negative integer count nature of degree ($D \in \{0, \dots, 25\}$).
   - Identifies three primary latent classes: “Network Conservers” (46.2%), “Accelerated Winnowers” (36.0%), and “Tie Accumulators” (17.8%).
3. **Expansion 2: Multilevel Poisson Growth Curve Models (`lme4::glmer`)**:
   - Models degree growth directly in continuous time with random ego intercepts:
     $$\log(\mathbb{E}[D_{it}]) = (\beta_0 + u_{0i}) + \beta_1 \text{Time}_t + \mathbf{X}_i \boldsymbol{\beta} + (\text{Time}_t \times \mathbf{Z}_i) \boldsymbol{\gamma}$$
   - **Key Empirical Discovery**: Collegiate networks contract by ~7% per wave on average ($\text{IRR} = 0.931, p < 0.001$). High baseline trust maintains systematically larger networks ($\text{IRR} = 1.065, p = 0.010$). Crucially, extraverts experience significantly *steeper* winnowing slopes over time ($\text{Time} \times \text{Extraversion IRR} = 0.986, p < 0.001$), casting a wide net initially and shedding peripheral ties more rapidly than introverted peers.
4. **Expansion 3: Full 8-Wave collegiate Trajectory Decomposition**:
   - Decomposes total degree into **Close Ties**, **Daily Activated Ties**, and **Support-Providing Ties** across all four undergraduate years.
   - **Substantive Resolution**: Total network size declines from 14.2 to 10.8 alters, but daily activated ties (mean $\approx 5.5$) and close/supportive ties (mean $\approx 10.5$) remain invariant over time. The observed downward trend represents the pruning of superficial campus acquaintances rather than an erosion of core personal communities.

### 3. Directory Structure & Asset Taxonomy
```
project/
├── AGENTS.md                                # Project-specific guidelines and asset inventory
├── draft_manuscript.md                      # Active local markdown mirror
├── README.md                                # Full technical and empirical documentation
├── data/
│   ├── raw/                                 # Symlinked raw survey microdata (.gitignored)
│   └── processed/                           # Cleaned analytical datasets (.gitignored)
├── Plots/                                   # Publication-grade PNG figures (6.5 in wide, 300 DPI)
├── cache/                                   # Pre-compiled APA markdown tables
└── Scripts/                                 # Turnkey modular execution pipeline
    ├── 01_prepare_trajectory_data.R         # Data ingestion & baseline covariate harmonization
    ├── 02_classify_trajectories.R           # Deductive decision tree & k-means clustering
    ├── 03_replicate_multinomial_models.R    # 84 multinomial logit models & fit diagnostics
    ├── 04_expansion_latent_class_growth.R   # LCGA Poisson mixture models
    ├── 05_expansion_multilevel_growth.R     # Multilevel Poisson GLMMs
    ├── 06_expansion_tie_decomposition.R     # 8-Wave trajectory decomposition
    ├── generate_md_tables.R                 # Pre-compiles APA markdown tables to cache/
    ├── sync_manuscript.py                   # In-place OpenXML table & figure injector
    └── sync_manuscript.R                    # Master Drive sync driver (Rscript Scripts/sync_manuscript.R)
```

### 4. Tables and Figures Inventory in Live Google Doc (Strict Sequential Order)
- **Table 1**: Empirical Distribution of Undergraduate Ego Networks Across Trajectory Classification Schemes ($N = 450$) (`cache/table1_trajectory_schemes.md`)
- **Figure 1**: Degree Trajectories Classified by A Priori Logic across Survey Waves 1–6 ($N = 450$) (`Plots/fig1_8cat_logical_trajectories.png`)
- **Figure 2**: Degree Trajectories Classified by Simplified A Priori Logic ($N = 450$) (`Plots/fig2_4cat_simplified_trajectories.png`)
- **Figure 3**: Degree Trajectories Classified by $k$-Means Clustering Zeroed on Ego Mean ($k = 4, N = 450$) (`Plots/fig3_kmeans_demeaned_k4.png`)
- **Figure 4**: Within-Cluster Distance to Centroids Across $k = 1 \dots 10$ (Elbow Analysis) (`Plots/fig4_kmeans_elbow_curves.png`)
- **Table 2**: Predictor Variable Significance Rates Across 84 Multinomial Logistic Regression Models (`cache/table2_variable_significance_rates.md`)
- **Figure 8**: Likelihood Ratio Chi-Squared $p$-Values Across Model Specification Families (`Plots/fig8_chisq_pvalues_by_type.png`)
- **Figure 9**: McFadden Pseudo $R$-Squared Values Across Model Specification Families (`Plots/fig9_pseudo_r2_by_type.png`)
- **Figure 10**: McFadden Pseudo $R$-Squared Values Stratified by Omnibus Significance ($p < .05$ vs. $p \ge .05$) (`Plots/fig10_pseudo_r2_by_type_and_signif.png`)
- **Figure 11**: Proportion of Multinomial Logistic Regression Models Where Each Candidate Predictor Achieves Statistical Significance ($p < .05$) (`Plots/fig11_variable_significance_rates.png`)
- **Table 3**: Latent Class Growth Analysis (LCGA) Model Fit Statistics Across Candidate Poisson Mixture Models ($K = 1 \dots 5$) (`cache/table3_lcga_model_selection.md`)
- **Figure 5**: Latent Class Growth Analysis (LCGA) Trajectory Profiles from Repeated-Measures Poisson Mixture Model ($K = 3$) (`Plots/fig5_lcga_optimal_trajectories.png`)
- **Table 4**: Model Comparison Hierarchy for Multilevel Poisson Growth Curve Models (`cache/table4_multilevel_model_comparison.md`)
- **Table 5**: Fixed Effects Estimates from Multilevel Poisson Growth Curve GLMM with Random Ego Intercepts (Model 4) (`cache/table5_multilevel_glmm_estimates.md`)
- **Figure 6**: Predicted Ego Degree Growth Trajectories by Extraversion and Neuroticism Profiles from Multilevel Poisson GLMM (`Plots/fig6_multilevel_predicted_trajectories.png`)
- **Table 6**: Longitudinal Means and Standard Errors of Decomposed Relational Dimensions Across Eight Collegiate Waves (`cache/table6_decomposed_trajectory_means.md`)
- **Figure 7**: Decomposing Ego Network Evolution Across Eight Collegiate Waves: Total Degree, Strong Ties, Daily Ties, and Support Ties (`Plots/fig7_decomposed_degree_trajectories.png`)

### 5. Strict Protocol for Autonomous Execution & Synchronization
1. **The Live Google Doc Is King (ZERO OVERWRITING)**: Human authors edit and style text online. Never overwrite the live document by uploading a fresh Pandoc-compiled `.docx` file.
2. **Download First**: Always download `draft_live.docx` via `googledrive::drive_download(as_id(doc_id), path = "draft_live.docx", overwrite = TRUE)`.
3. **In-Place OpenXML Injection Only**: All asset updates must be applied directly to the downloaded `draft_live.docx` XML tree using DOM sibling search / relationship mapping (`Scripts/sync_manuscript.py`), updating only `<w:tbl>` and `<w:drawing>` containers.
4. **Intermediate File Cleanup**: Always purge scratch files (`draft_*.docx`, `draft_*.txt`, `*.tmp`, `replacements.json`) via `on.exit()` in R or `try...finally` in Python.
5. **Style Compliance**:
   - Double typographic quotes (“...”) for named classes.
   - Never use "democratic" for egalitarian / widely distributed / pervasive.
   - Use "men" and "women" (never "male" / "female" as nouns).
   - Use "Gender Identity" (or "Gender") rather than "Sex".
   - Avoid generic "robust" (reserve strictly for formal statistical terms like "cluster-robust standard errors").
   - Every visual figure must be accompanied by its dedicated analytical discussion paragraph.


## Project Architecture: Social Signatures in the NetHealth Study

### 1. Overview & Document Identification
- **Project Title:** Examining the Relational Content and Personal Determinants of Social Signatures Across Multiple Time Scales (Working Subtitle: *The Persistent Architecture of Relational Investment: Social Signatures in the NetHealth Study*)
- **Authors:** Omar Lizardo (Department of Sociology, University of California, Los Angeles) and David Hachen (Department of Sociology, University of Notre Dame)
- **Primary Publication Manuscript:** `manuscript.tex` (Synchronized directly with Overleaf and GitHub)
- **Bibliography:** `references.bib` (BibTeX database integrated via `natbib`)
- **Overleaf Project URL:** https://www.overleaf.com/project/6aa09a088d46d1a81ec5e22c
- **Overleaf Git Endpoint:** `https://git.overleaf.com/6aa09a088d46d1a81ec5e22c`
- **GitHub Repository:** https://github.com/olizardo/social-signatures-nethealth.git
- **Collaborative Google Doc URL:** https://docs.google.com/document/d/1CAVM2L25colX4ok5fdewBGo1-wWk-NzhX9esQ2nBU_o
- **Collaborative Google Doc ID:** `1CAVM2L25colX4ok5fdewBGo1-wWk-NzhX9esQ2nBU_o`
- **Data Sources:** NetHealth Study (University of Notre Dame, continuous smartphone sensing and longitudinal surveys, 2015–2017: https://sites.nd.edu/nethealth/).
- **Primary Analytic Sample:** $N = 491$ egos, 498,237 outgoing iOS voice calls spanning June 30, 2015 through July 2, 2017, linked to 8 sociocentric network survey waves ($N = 35,913$ alter nominations), complete alter-alter structural edge lists ($174,748$ ties), and longitudinal psychometric batteries ($N = 722$ egos).

### 2. Theoretical Lineage & Empirical Grounding (Literature Review Synthesis)
The project synthesizes and advances a decade of multidisciplinary research building on the social signatures framework coined by \citet{saramaeki2014persistence}:
1. **Foundational Origins & Cognitive Limits**:
   - Grounded in Dunbar's social brain hypothesis \citep{dunbar1992neocortex,dunbar1998social,dunbar2018anatomy}, neocortical volume limits, and time as a finite zero-sum budget \citep{miritello2013time,roberts2009exploring,sutcliffe2012relationships}.
   - \citet{saramaeki2014persistence}: Formalized social signatures as normalized interaction allocation vectors ($p_i(r)$), quantified dissimilarity via zero-padded Jensen-Shannon Divergence ($\JSD$), established intra-individual persistence over time ($d_{\mathrm{self}} < d_{\mathrm{ref}}$), and hypothesized the "slot-filling" mechanism under high alter turnover ($1 - J \approx 0.60$--$0.80$).
2. **Multichannel & Multimodal Frontiers**:
   - \citet{heydari2018multichannel}: Demonstrated persistence within voice call and SMS channels across half a million egos, identifying cross-channel resemblance despite minimal overlap in specific alters.
   - \citet{li2018social}: Evaluated online collaborative interaction dynamics in Facebook Wall posts and Wikipedia Talk pages, introducing "structural signatures" based on triadic embeddedness (shared neighbors) and showing that structural embeddedness mirrors behavioral communication profiles.
   - \citet{li2022evidence}: Analyzed the Copenhagen Networks Study ($N > 700$ students) across phone calls, text messages, and Bluetooth physical proximity; confirmed signature persistence across all modalities while demonstrating that mediated channels exhibit higher structural stability than face-to-face proximity.
   - \citet{liu2024uncovering}: Analyzed dual-channel mobile records, revealing a U-shaped trade-off between calling and texting as contact portfolios expand, alongside sharp communication vitality ceilings (10 contacts for calls, 100 for texts, 20 for hybrid).
3. **Theoretical Models of Resource Allocation & Universal Scaling**:
   - \citet{tamarit2022beyond}: Formulated a maximum entropy continuous resource allocation model reconciling discrete Dunbar circles ($5, 15, 50, 150$) with continuous signatures, identifying a universal scaling parameter $\eta \approx 6$ governing relational maintenance costs across calls, face-to-face, and Facebook.
   - \citet{iniguez2023universal}: Analyzed millions of individuals across calls, SMS, Twitter, and Wikipedia to reveal universal tie strength distributions driven by a microscopic competition between cumulative advantage (preferential tie reinforcement $\propto w^\beta$) and random choice (exploratory communication), parameterized by the alter-preferentiality exponent $\beta$.
   - \citet{adel2026preferentiality}: Extended this framework to offline wearable sensors and colocation data, demonstrating that passive colocation is a noisy proxy, whereas genuine face-to-face interaction follows universal scaling between tie preferentiality and bounded social bandwidth.
4. **Methodological Refinements (Disentangling Degree & Tie Strength)**:
   - \citet{heydari2024disentangling} & \citet{heydari2024dynamic}: Identified that standard $\JSD$ distance conflates network size (degree $k$) with internal allocation shape. Using degree-invariant metrics (the Gini coefficient distance $\Delta G$ and normalized alter-preferentiality distance $\Delta \beta$), they proved that egos maintain authentic, persistent tie strength heterogeneity independent of degree.
5. **Longitudinal Boundaries & Biometric Uniqueness**:
   - \citet{koltsova2021social}: Tracked social networking site messaging (VKontakte) over 18 months, showing that while short-term stability holds, signatures undergo statistically significant structural drift across longer developmental horizons.
   - \citet{jia2025multidimensional}: Demonstrated that the idiosyncratic shape and stability of multidimensional social signatures allow user re-identification and de-anonymization (up to 87\% accuracy) in low-sensitivity interaction data, establishing that communication profiles function as behavioral biometric fingerprints.

### 3. Five Open Frontiers Addressed and Resolved by NetHealth
1. **The "Content Black Box" & Functional Support Grounding**:
   - *The Gap*: Prior work relied exclusively on telecommunications metadata devoid of relational content, leaving open whether rank order reflects mere call frequency or qualitative functional specialization.
   - *NetHealth Resolution*: Links $N = 13,174$ call-ranked dyads to longitudinal sociocentric surveys recording multidimensional social support. Rank 1 is a specialized kinship-dominated support hub (69.7\% family, 85.4\% emotional support, 87.6\% advice, 64.1\% financial aid), transitioning to sympathy groups (Ranks 2--3: 62.2\% kin, 77.1\% emotional support), peer friendship dominance (Ranks 4--5: 56.9\% friends; Ranks $>20$: 87.8\% friends), while companionship remains sustained across all tiers ($>69\%$).
2. **Direct Empirical Verification of the Slot-Filling Mechanism**:
   - *The Gap*: Previous studies hypothesized slot-filling under alter turnover, but could not test whether stability survives complete replacement of the primary alter versus alter retention.
   - *NetHealth Resolution*: Across eight semesters with 80.1\% average alter turnover, we separate transitions where the top alter (Rank 1) is retained from those where Rank 1 is completely replaced. Even when Rank 1 is replaced, self-divergence increases only marginally (from 0.043 to 0.078), providing direct empirical proof of the slot-filling mechanism.
3. **Psychological Foundations of Signature Curvature**:
   - *The Gap*: Theoretical models hypothesize that internal cognitive traits drive alter-preferentiality, but commercial CDRs possess zero psychometrics.
   - *NetHealth Resolution*: Econometric regression of objective power-law decay exponents ($\alpha_i$) on longitudinal Big Five personality traits, CES-D depression, and UCLA loneliness scores shows that **Negative Emotionality strongly predicts steeper, hyper-concentrated signatures ($\beta = 0.098, t = 5.08, p = 6.96 \times 10^{-7}$)**, whereas Extraversion displays no statistically significant effect ($t = -1.01, p = 0.314$).
4. **Multi-Timescale Hierarchy and Parameter Burn-In Convergence**:
   - *The Gap*: Prior work examined arbitrary, isolated observation windows (1 month, 6 months, 9 months) without establishing how long an ego must be observed for parameter estimates to stabilize.
   - *NetHealth Resolution*: Evaluates signatures across eight temporal window schemes (from 1-week discrete windows to full academic years) and tracks cumulative parameter stability from 2 to 24 months, showing that estimated decay exponents stabilize asymptotically within 6 to 8 months.
5. **Sociocentric Structural Embedding and Multilevel Panel Dynamics**:
   - *The Gap*: Egocentric communication has traditionally been modeled in isolation from the alters' own structural ties.
   - *NetHealth Resolution*: Embeds communication logs within the complete sociocentric graph ($174,748$ alter-alter structural ties), estimating multilevel linear mixed-effects models that show alter turnover ($\beta = 0.351, p < 10^{-15}$) and volume shifts ($\beta = 0.0014, p < 10^{-10}$) drive temporal stability, while local network clustering does not alter stability net of turnover.

### 4. Canonical NetHealth Study Citations (Representing All Primary PIs)
Any manuscript revision, grant submission, or documentation referencing the NetHealth Study must cite the foundational project publications representing the primary PIs (David Hachen, Omar Lizardo, Christian Poellabauer, Aaron Striegel, Tijana Milenković, and Nitesh Chawla):
- **Liu, S., Hachen, D., Lizardo, O., Poellabauer, C., Striegel, A., & Milenković, T. (2018)**. Network analysis of the NetHealth data: Exploring co-evolution of individuals' social network positions and physical activities. *Applied Network Science*, 3(1), 45. https://doi.org/10.1007/s41109-018-0103-2
- **Purta, R., Mattingly, S., Song, L., Lizardo, O., Hachen, D., Poellabauer, C., & Striegel, A. (2016)**. Experiences measuring sleep and physical activity patterns across a large college cohort with Fitbits. *Proceedings of the 2016 ACM International Symposium on Wearable Computers (ISWC '16)*, 28–35. https://doi.org/10.1145/2971763.2971767
- **Faust, L., Purta, R., Hachen, D., Striegel, A., Poellabauer, C., Lizardo, O., & Chawla, N. V. (2017)**. Exploring compliance: Observations from a large scale Fitbit study. *Proceedings of the 2nd International Workshop on Social Sensing (SocialSens '17)*, 55–60. https://doi.org/10.1145/3055601.3055608
- **Liu, S., Vahedian, F., Hachen, D., Lizardo, O., Poellabauer, C., Striegel, A., & Milenković, T. (2021)**. Heterogeneous network approach to predict individuals' mental health. *ACM Transactions on Knowledge Discovery from Data (TKDD)*, 15(2), 1–26. https://doi.org/10.1145/3429446

### 5. Tables and Figures Inventory in Publication Manuscript
- **Table 1**: NetHealth Cohort Summary Across Temporal Window Definitions (`cache/table1_cohort_summary.md`)
- **Figure 1**: Empirical Social Signatures across Temporal Window Resolutions (Ranks 1–15; 2-row bottom legend layout preventing clipping) (`Plots/fig01_mean_signatures_by_window.png`)
- **Table 2**: Statistical Tests of Social Signature Persistence Across Window Schemes (`cache/table2_stability_tests.md`)
- **Figure 2**: Persistence of Social Signatures: Self vs. Reference Divergence across Temporal Resolutions (`Plots/fig02_self_vs_ref_divergence.png`)
- **Table 3**: Parametric Model Evaluation Across Window Resolutions (Power-Law vs. Exponential) (`cache/table3_parametric_models.md`)
- **Figure 3**: Power-Law vs Exponential Model Fits and Exponent Distribution (`Plots/fig03_power_law_vs_exponential.png`)
- **Figure 4**: Parameter Burn-In Convergence Over 24 Months (`Plots/fig04_parameter_burnin.png`)
- **Table 4**: Relational Composition and Support Functions Across Signature Rank Tiers ($N = 13,174$ Dyads) (`cache/table4_support_tiers.md`)
- **Figure 5**: Functional Support Dimensions Across Signature Rank Tiers (High-contrast accessible color palette with zero light yellow; multi-row bottom legend) (`Plots/fig05_rank_by_support_tiers.png`)
- **Figure 6**: The 'Slot-Filling' Dynamic: Alter Turnover vs. Signature Divergence ($r = 0.456, p < 10^{-15}$) (`Plots/fig06_turnover_vs_stability.png`)
- **Table 5**: Multilevel Linear Mixed-Effects Models Predicting Signature Self-Divergence ($\JSD$) (`cache/table5_multilevel_models.md`)
- **Table 6**: Personality Determinants of Social Signature Power-Law Alpha ($\alpha_i$) (`cache/table6_personality_models.md`)
- **Figure 7**: Negative Emotionality as a Driver of Egocentric Relational Concentration (Two-panel visualization centering on the statistically significant Negative Emotionality effect; Panel A: scatterplot and regression fit of $\alpha_i$ on Negative Emotionality; Panel B: mean signatures across ranks 1--10 stratified by Negative Emotionality tertiles with a multi-row legend, showing high Negative Emotionality individuals allocate 31.7% to Rank 1 vs. 25.3% for low Negative Emotionality peers; Extraversion removed) (`Plots/fig07_personality_signature_effects.png`)

### 6. Directory Structure & Asset Taxonomy
```
social-signatures-nethealth/
├── manuscript.tex                         # Primary LaTeX manuscript (synchronized with Overleaf)
├── references.bib                         # BibTeX reference library (36 verified entries)
├── manuscript.pdf                         # Compiled 23-page publication PDF
├── draft_manuscript.md                    # Local Markdown mirror synchronized with Google Drive
├── run_all.R                              # Master analytical reproduction pipeline
├── data/
│   ├── raw/                               # Call logs, calendars, and survey microdata (.gitignored raw files)
│   └── processed/                         # Harmonized analytical datasets
├── Plots/                                 # Publication-grade PNG figures (6.5 in wide, 300 DPI)
├── cache/                                 # Pre-compiled APA markdown tables
├── templates/                             # Document reference styles and fontTable XML
└── Scripts/                               # Turnkey modular execution pipeline
    ├── 01_prepare_call_windows.R          # Temporal window binning & cohort filtering
    ├── 02_compute_signatures_and_jsd.R    # Social signature computation, fast JSD, Wilcoxon tests
    ├── 03_fit_parametric_models.R         # Power-law vs exponential models & burn-in analysis
    ├── 04_egonet_topology_and_turnover.R  # Ego network metrics & alter turnover dynamics
    ├── 05_survey_linkage_psychometrics.R  # Support dimensions & Big Five psychometrics
    ├── 06_expansion_statistical_models.R  # Dyadic support tiers & multilevel LMM regressions
    ├── 07_generate_figures_and_tables.R   # Publication-quality figure and table rendering
    ├── generate_md_tables.R               # Pre-compiles APA markdown tables into cache/
    ├── sync_manuscript.py                 # OpenXML table & figure DOM injector
    ├── format_manuscript.py               # Typography, margins, indents, and style normalizer
    └── sync_manuscript.R                  # Master Google Drive synchronization driver
```

### 7. Core Operational Lessons & Style Standards for Social Signatures
1. **Zero Local LaTeX Compilation When Connected to Overleaf (CRITICAL)**:
   - Never run `pdflatex`, `xelatex`, `bibtex`, or `latexmk` locally when connected to Overleaf. Overleaf compiles and previews PDFs online. Focus exclusively on editing source files (`manuscript.tex`, `references.bib`, `Plots/`) and pushing commits directly (`git push overleaf main`).
2. **Abstract Word Count Strict Enforcement**:
   - Always verify that the abstract is strictly $\le 250$ words (currently 229 words).
3. **Discussion Section CUA Tripartite Standard (MANDATORY)**:
   - Structure the concluding Discussion into three distinct subsections:
     1. `Summary of Key Results` (Bird's-Eye Synthesis, Systematic Walking of Findings, Concluding Transition).
     2. `Limitations and Future Work` (Full academic prose covering 5 analytical dimensions: operationalization/measurement, threats to causal inference, directionality/selection, temporal granularity/attrition, institutional scope conditions).
     3. `Implications: Cognitive Templates and Capital` (Theoretical stakes, resolving zero-sum paradoxes, broader sociological synthesis).
4. **Complete Elimination of Bullet Points and Numbered Lists**:
   - Compose the entire manuscript in full, flowing academic prose paragraphs. Zero `\begin{enumerate}` or `\begin{itemize}` blocks in the body text.
5. **Italics for In-Text Emphasis**:
   - Use italics (`\textit{...}` or `\emph{...}`) instead of boldface for emphasizing terms, concepts, and key statistical statements in running text. Reserve boldface strictly for section titles and table column headers.
6. **Avoidance of "Architecture" When Specific Terms Apply**:
   - Reserve the term "architecture" for overarching metaphorical titles; in running text, use precise terms: "binning schemes", "temporal definitions", "qualitative organization", "relational geometry", and "communication networks".

### 5. Exhaustive Replication Audit Against Social Signatures.pptx
Every slide, figure, and empirical study from Matthew Chandler's 26-slide presentation (May 7, 2019) has been comprehensively replicated and extended:

| Slide(s) in PPTX | Topic / Analysis in Slide Deck | Implementation in This Project | Location in Paper & Pipeline |
|:---|:---|:---|:---|
| **Slides 2 & 12** | Social signature formulation & generalized n-ary JSD (Lin 1991) | Matrix-accelerated zero-padded pairwise JSD and multi-window generalized entropy | `scripts/02_compute_signatures_and_jsd.R`, Section 2.3 |
| **Slide 6 & 13** | 7 Window binning definitions (Academic Years, Semesters, Quarters, Months, 3-Wk Moving, 2-Wk Discrete, 1-Wk Discrete) | Complete calendar and weekly binning algorithms with >=2 alters & >10 calls criteria | `scripts/01_prepare_call_windows.R`, Table 1 |
| **Slide 7** | Alter variation & Jaccard turnover by year (n = 411) | Year-over-year alter degree correlations and Jaccard turnover distributions | `scripts/04_egonet_topology_and_turnover.R`, Section 4.2 |
| **Slide 8** | Scatterplot matrix of alter counts across 8 quarters (n = 229) | Quarter-by-quarter alter degree correlation matrix | `scripts/01_...` & `scripts/04_...` |
| **Slides 9–11** | Sample individual social signatures across Semesters, Quarters, and 3-Week Moving | Individual ego curves and aggregate mean signature profiles | `scripts/02_...`, Figure 1 |
| **Slide 14** | Pairwise Mean Self-Divergence vs. Combined Generalized JSD across narrow windows (n = 70) | Comparative evaluation of pairwise consecutive JSD vs. multi-window generalized JSD | `scripts/02_...`, Section 2.3 |
| **Slide 15** | Reference divergence formulation (all-pairs vs. by-ego averaged) | Both reference divergence calculations implemented across all window resolutions | `scripts/02_...`, Table 2 |
| **Slide 16 & 17** | Self vs. Reference divergence and turnover scatterplots; correlation distributions | Dyadic Jaccard turnover vs. JSD regressions and stability distributions | `scripts/04_...`, Figure 6 |
| **Slide 18** | Self vs. Reference divergence distributions (No Limit vs. Top 20) with Wilcoxon / Mann-Whitney tests | Formal non-parametric location tests confirming persistence (p < 10^-12) | `scripts/02_...`, Table 2, Figure 2 |
| **Slide 19** | Log-log social signatures by semester showing linear power-law decay | Individual and aggregate log-log decay curves | `scripts/03_fit_parametric_models.R`, Figure 3 |
| **Slide 20** | Power-law models f(x) = beta * x^-alpha (p < 0.00001 for all models) | NLS and log-linear estimation across all ego-windows (97.7% significant at p < 0.0001) | `scripts/03_...`, Table 3 |
| **Slide 21** | Distributions of power-law intercept beta and slope -alpha | Parameter distribution density modeling across timescales | `scripts/03_...`, Figure 3 |
| **Slide 22** | Individual differences in parameters by year (Delta beta, Delta alpha) | Year-over-year individual parameter stability tracking | `scripts/03_...`, Section 3.3 |
| **Slide 23** | Longitudinal parameter trajectories across Semesters, Quarters, Months | Longitudinal panel modeling of ego-level decay exponents | `scripts/03_...` & `scripts/06_...` |
| **Slide 24** | Power-law vs. Exponential models (f(x) = beta * exp(-alpha * x)) | Direct goodness-of-fit comparison (AIC, BIC, R^2; power-law preferred in 97.0%) | `scripts/03_...`, Table 3, Figure 3 |
| **Slide 25** | Parameter burn-in: How long before an ego's model is stable? | Cumulative 2-to-24 month parameter convergence tracking (stabilizes at 6-8 months) | `scripts/03_...`, Figure 4 |
| **Slide 26** | Covariates to tease out (degree, clustering, turnover, activity, modularity) | Multilevel mixed-effects models & support tier linkages | `scripts/05_...` & `scripts/06_...`, Tables 4–6, Figures 5–7 |

### 6. Technical Lessons & Best Practices
5. **LaTeX Migration & Mathematical Consistency Standards (Math-Heavy Papers)**:
   - **Primary Typesetting in LaTeX**: For papers characterized by intensive mathematical formulations (information-theoretic metrics, power-law vs. exponential decay equations, Shannon entropy, dyadic turnover formulas, and multi-level mixed-effects models), LaTeX (`manuscript.tex` + `references.bib`) serves as the canonical authoring and submission medium, bypassing word-processor equation limitations.
   - **Consistent Notation Hierarchy**: Maintain uniform mathematical symbols across all prose, equations, tables, and figure captions:
     - Ego $i$, window $w$, alter rank $r$, alter identity $j$, time $t$.
     - Interaction weights: $w_{i,j,w}$, total volume $W_{i,w} = \sum_{j=1}^{k_{i,w}} w_{i,j,w}$.
     - Social signature proportion: $p_{i,w}(r) = w_{i,(r),w} / W_{i,w}$ where $\sum_{r=1}^{k_{i,w}} p_{i,w}(r) = 1$.
     - Entropy and divergence: $H(P) = -\sum p_r \log_2(p_r)$, $\JSD(P \parallel Q) = H(M) - 0.5[H(P) + H(Q)]$.
     - Divergence metrics: self-divergence $\dself(i)$, reference divergence $\dref(i)$.
     - Turnover: $\Turnover_{i,w} = 1 - |A_{i,w} \cap A_{i,w+1}| / |A_{i,w} \cup A_{i,w+1}|$.
     - Panel models: $\JSD_{it} = \beta_0 + \beta_1 \Turnover_{it} + \beta_2 \Delta \mathrm{Activity}_{it} + \mathbf{X}_{it}\boldsymbol{\gamma} + u_i + \epsilon_{it}$.
   - **Table Design**: Use `booktabs` (`\toprule`, `\midrule`, `\bottomrule`) with `\resizebox{\textwidth}{!}{...}` on wide multi-column tables to ensure seamless margin compliance.
   - **Zero-Warning Compilation Pipeline**: Always compile via `pdflatex -interaction=nonstopmode manuscript.tex && bibtex manuscript && pdflatex -interaction=nonstopmode manuscript.tex && pdflatex -interaction=nonstopmode manuscript.tex`.


1. **Translating Math to Document Text (Bypassing Cambria Math & oMath Issues)**:
   - When authors request standard manuscript typography (e.g., Alegreya Sans 11pt) across the entire paper, never use LaTeX math delimiters in markdown, as Pandoc converts them into Word `<m:oMath>` blocks which default to Cambria Math and fail Google Docs import conversion.
   - Write equations in clean Unicode text with semantic italics and superscripts/subscripts.
   - `format_manuscript.py` must run `convert_omath_to_runs()` to convert any lingering `<m:oMath>` into standard `<w:r>` text runs styled in the document font (`Alegreya Sans 11pt`).
2. **Preventing Generic Word Style Resets in Google Docs**:
   - Pandoc compiles markdown paragraphs with styles `BodyText` and `FirstParagraph`. If these style IDs are missing from `styles.xml`, Google Docs falls back to its generic default styles (Calibri 11pt, 1.15 line spacing, 0 indent).
   - In `format_manuscript.py`, always strip `BodyText` and `FirstParagraph` from paragraphs so they default to `Normal`, ensure `docDefaults` has `rFonts w:ascii="Alegreya Sans"` without theme overrides (`asciiTheme`), and inject proven `styles.xml` and `fontTable.xml` templates.
3. **High-Performance JSD Vectorization in R**:
   - Calculating pairwise JSD across hundreds of egos and windows iteratively hangs in R.
   - Precompute Shannon entropy H(P) once per signature vector. Pairwise JSD then only requires calculating H(M) for the midpoint M = 0.5(P + Q).
   - Pad all signatures in a window into a matrix and compute midpoint entropy vectorized across columns, achieving a 400x speedup.
4. **Fast GZ Ingestion without Extra Packages**:
   - To bypass `fread()`'s prompt for `R.utils` when reading `.csv.gz`, pass the decompressed stream command: `fread(cmd = sprintf("zcat %s", gz_file), select = ...)`.
