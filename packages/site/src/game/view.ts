import { createGame, type Game } from "./state";
import { buildPrompt } from "./words";

const PROMPT_LENGTH = 25;
const TYPING_IDLE_MS = 400;
const LIVE_TICK_MS = 1000;
const PLACEHOLDER_HTML = `<span class="game-placeholder">Click to start · your slowest letters surface on the right</span>`;

const escapeChar = (ch: string): string => {
  switch (ch) {
    case "&":
      return "&amp;";
    case "<":
      return "&lt;";
    case ">":
      return "&gt;";
    case '"':
      return "&quot;";
    case "'":
      return "&#39;";
    default:
      return ch;
  }
};

const displayChar = (ch: string): string => {
  if (ch === " ") return "␣";
  return escapeChar(ch);
};

const formatSeconds = (ms: number) => (ms / 1000).toFixed(1);

const shellHtml = (promptLength: number) => `
  <div class="trainer-shell calibrator" data-game>
    <div class="calibrator-main">
      <dl class="game-stats" aria-live="polite">
        <div><dt>WPM</dt><dd data-wpm>0</dd></div>
        <div><dt>ACC</dt><dd data-acc>100%</dd></div>
        <div><dt>WORDS</dt><dd data-progress>0 / ${promptLength}</dd></div>
      </dl>
      <div
        class="game-prompt"
        data-prompt
        tabindex="0"
        role="textbox"
        aria-label="Typing calibration — click and type"
        aria-multiline="false"
      >${PLACEHOLDER_HTML}</div>
      <div class="game-controls">
        <button type="button" class="button secondary" data-action="restart">Restart</button>
        <button type="button" class="button secondary" data-action="new">New prompt</button>
        <span class="controls-hint" aria-hidden="true">⏎ submit · ⌫ back</span>
      </div>
    </div>
    <aside class="calibrator-aside" aria-live="polite" aria-label="Live calibration readout">
      <header class="calibrator-aside-head">
        <span class="calibrator-aside-eyebrow">Live calibration</span>
        <span class="calibrator-aside-hint">— your typing, measured</span>
      </header>
      <div class="calibrator-aside-body">
        <section class="stats-block">
          <h4>Slowest letters</h4>
          <ol class="stats-rows" data-letters>
            <li data-empty>type to calibrate</li>
          </ol>
        </section>
        <section class="stats-block">
          <h4>Slowest bigrams</h4>
          <ol class="stats-rows" data-bigrams>
            <li data-empty>type to calibrate</li>
          </ol>
        </section>
        <section class="stats-block">
          <h4>WPM · last 10s</h4>
          <div class="wpm-sparkline" data-sparkline data-empty="true">
            <span>awaiting keystrokes</span>
          </div>
          <div class="wpm-readout">
            <span>now</span>
            <strong data-wpm-live>—</strong>
          </div>
        </section>
      </div>
    </aside>
  </div>
`;

const formatMs = (ms: number) => {
  if (ms < 1000) return `${Math.round(ms)}ms`;
  return `${(ms / 1000).toFixed(1)}s`;
};

export const mountGame = (root: HTMLElement): void => {
  if (matchMedia("(pointer: coarse)").matches) {
    root.setAttribute("hidden", "");
    return;
  }

  root.innerHTML = shellHtml(PROMPT_LENGTH);

  const shell = root.querySelector<HTMLDivElement>("[data-game]");
  const promptEl = root.querySelector<HTMLDivElement>("[data-prompt]");
  const statWpm = root.querySelector<HTMLElement>("[data-wpm]");
  const statAcc = root.querySelector<HTMLElement>("[data-acc]");
  const statProgress = root.querySelector<HTMLElement>("[data-progress]");
  const lettersEl = root.querySelector<HTMLOListElement>("[data-letters]");
  const bigramsEl = root.querySelector<HTMLOListElement>("[data-bigrams]");
  const sparklineEl = root.querySelector<HTMLDivElement>("[data-sparkline]");
  const wpmLiveEl = root.querySelector<HTMLElement>("[data-wpm-live]");
  if (
    !shell ||
    !promptEl ||
    !statWpm ||
    !statAcc ||
    !statProgress ||
    !lettersEl ||
    !bigramsEl ||
    !sparklineEl ||
    !wpmLiveEl
  )
    return;

  let game: Game = createGame(buildPrompt(PROMPT_LENGTH));
  let liveTimer: number | null = null;
  let typingTimer: number | null = null;
  let showingPlaceholder = true;

  const CARET = `<span class="caret" aria-hidden="true"></span>`;

  const renderPlaceholder = () => {
    promptEl.innerHTML = PLACEHOLDER_HTML;
    showingPlaceholder = true;
  };

  const renderPrompt = () => {
    const words = game.renderWords();
    const caret = game.caret();
    const html = words
      .map((w, wi) => {
        const letters = w.letters
          .map((l, li) => {
            const pre = caret?.wordIndex === wi && caret.letterIndex === li ? CARET : "";
            return `${pre}<span class="letter" data-role="${l.role}">${escapeChar(l.char)}</span>`;
          })
          .join("");
        const trailingCaret =
          caret?.wordIndex === wi && caret.letterIndex >= w.letters.length ? CARET : "";
        return `<span class="word" data-role="${w.role}">${letters}${trailingCaret}</span>`;
      })
      .join(" ");
    promptEl.innerHTML = html;
    showingPlaceholder = false;
  };

  const renderStats = () => {
    statAcc.textContent = `${Math.round(game.accuracy())}%`;
    statProgress.textContent = game.progressLabel();
  };

  const renderWpm = () => {
    statWpm.textContent = Math.round(game.wpm()).toString();
  };

  const renderRows = (
    el: HTMLOListElement,
    rows: { key: string; ms: number }[],
    keyClass: string,
  ) => {
    if (rows.length === 0) {
      el.innerHTML = `<li data-empty>type to calibrate</li>`;
      return;
    }
    el.innerHTML = rows
      .slice(0, 3)
      .map(
        (r) =>
          `<li><span class="stats-key ${keyClass}">${displayChar(r.key)}</span><span class="stats-val">${formatMs(r.ms)}</span></li>`,
      )
      .join("");
  };

  const renderBigramRows = (el: HTMLOListElement, rows: { bigram: string; medianMs: number }[]) => {
    if (rows.length === 0) {
      el.innerHTML = `<li data-empty>type to calibrate</li>`;
      return;
    }
    el.innerHTML = rows
      .slice(0, 3)
      .map(
        (r) =>
          `<li><span class="stats-key is-bigram">${r.bigram.split("").map(displayChar).join("")}</span><span class="stats-val">${formatMs(r.medianMs)}</span></li>`,
      )
      .join("");
  };

  const renderSparkline = () => {
    const history = game.wpmHistory();
    if (history.length === 0) {
      sparklineEl.setAttribute("data-empty", "true");
      sparklineEl.innerHTML = `<span>awaiting keystrokes</span>`;
      wpmLiveEl.textContent = "—";
      return;
    }
    sparklineEl.removeAttribute("data-empty");
    const maxWpm = Math.max(80, ...history.map((p) => p.wpm));
    const w = 100;
    const h = 30;
    const step = history.length > 1 ? w / (history.length - 1) : 0;
    const coords = history.map((p, i) => {
      const x = i * step;
      const y = h - (p.wpm / maxWpm) * (h - 4) - 2;
      return `${x.toFixed(1)},${y.toFixed(1)}`;
    });
    const areaPoints = `0,${h} ${coords.join(" ")} ${w},${h}`;
    const linePoints = coords.join(" ");
    sparklineEl.innerHTML = `
      <svg viewBox="0 0 ${w} ${h}" preserveAspectRatio="none" aria-hidden="true">
        <polygon class="spark-area" points="${areaPoints}" />
        <polyline class="spark-line" points="${linePoints}" />
      </svg>
    `;
    const latest = history[history.length - 1];
    if (latest) {
      wpmLiveEl.textContent = `${Math.round(latest.wpm)} wpm`;
    }
  };

  const renderCalibratorStats = () => {
    const letters = game
      .letterTimings()
      .filter((l) => l.samples >= 1)
      .map((l) => ({ key: l.letter, ms: l.medianMs }));
    const bigrams = game.bigramTimings().filter((b) => b.samples >= 1);
    renderRows(lettersEl, letters, "");
    renderBigramRows(bigramsEl, bigrams);
    renderSparkline();
  };

  const renderSummary = () => {
    const existing = shell.querySelector(".game-summary");
    if (existing) existing.remove();
    if (!game.isFinished()) return;
    const summary = document.createElement("div");
    summary.className = "game-summary";
    summary.innerHTML = `
      <h3>Calibration complete</h3>
      <dl>
        <div><dt>WPM</dt><dd>${Math.round(game.wpm())}</dd></div>
        <div><dt>Accuracy</dt><dd>${Math.round(game.accuracy())}%</dd></div>
        <div><dt>Time</dt><dd>${formatSeconds(game.elapsedMs())}s</dd></div>
      </dl>
      <div class="game-summary-actions">
        <button type="button" class="button primary" data-action="restart">Try again</button>
        <button type="button" class="button secondary" data-action="new">New prompt</button>
      </div>
    `;
    shell.appendChild(summary);
  };

  const render = () => {
    renderPrompt();
    renderStats();
    renderCalibratorStats();
    renderSummary();
  };

  const startLiveTimer = () => {
    if (liveTimer !== null) return;
    liveTimer = window.setInterval(() => {
      if (game.isFinished()) {
        stopLiveTimer();
        renderWpm();
        renderSparkline();
        return;
      }
      renderWpm();
      renderSparkline();
    }, LIVE_TICK_MS);
  };
  const stopLiveTimer = () => {
    if (liveTimer !== null) {
      clearInterval(liveTimer);
      liveTimer = null;
    }
  };

  const markTyping = () => {
    promptEl.setAttribute("data-typing", "");
    if (typingTimer !== null) clearTimeout(typingTimer);
    typingTimer = window.setTimeout(() => {
      promptEl.removeAttribute("data-typing");
      typingTimer = null;
    }, TYPING_IDLE_MS);
  };

  const afterMutation = () => {
    markTyping();
    render();
    if (game.isFinished()) {
      stopLiveTimer();
      renderWpm();
      renderSparkline();
    } else if (!game.hasStarted()) {
      stopLiveTimer();
    } else {
      startLiveTimer();
    }
  };

  promptEl.addEventListener("focus", () => {
    if (showingPlaceholder) render();
  });

  promptEl.addEventListener("blur", () => {
    if (!game.hasStarted() && !game.isFinished()) renderPlaceholder();
  });

  promptEl.addEventListener("keydown", (e) => {
    if (e.isComposing) return;
    if (e.ctrlKey || e.metaKey || e.altKey) return;
    const k = e.key;
    if (k === "Tab" || k === "Escape") return;
    if (k === "Backspace") {
      e.preventDefault();
      game.deleteBackward();
      afterMutation();
      return;
    }
    if (k === "Enter") {
      e.preventDefault();
      game.submit();
      afterMutation();
      return;
    }
    if (k === " ") {
      e.preventDefault();
      game.insert(" ");
      afterMutation();
      return;
    }
    if (k.length === 1) {
      e.preventDefault();
      game.insert(k);
      afterMutation();
    }
  });

  root.addEventListener("click", (e) => {
    const target = e.target;
    if (target instanceof Element && target.closest("button")) return;
    promptEl.focus();
  });

  const handleAction = (action: string | null) => {
    if (action === "restart") {
      stopLiveTimer();
      game.restart();
      render();
      promptEl.focus();
      return;
    }
    if (action === "new") {
      stopLiveTimer();
      game = createGame(buildPrompt(PROMPT_LENGTH));
      render();
      promptEl.focus();
    }
  };

  shell.addEventListener("click", (e) => {
    const target = e.target;
    if (!(target instanceof Element)) return;
    const btn = target.closest("button");
    if (!btn) return;
    handleAction(btn.getAttribute("data-action"));
  });

  renderStats();
  renderCalibratorStats();
};
