export type Committed = { expected: string; typed: string };

export type LetterRole =
  | "correct"
  | "incorrect"
  | "pending"
  | "extra"
  | "missing";

export type WordRole = "submitted" | "active" | "upcoming";

export type RenderLetter = { char: string; role: LetterRole };
export type RenderWord = { role: WordRole; letters: RenderLetter[] };
export type CaretPosition = { wordIndex: number; letterIndex: number } | null;

const EXTRA_CAP = 4;

export const createGame = (
  promptWords: readonly string[],
  now: () => number = Date.now,
) => {
  let committedWords: Committed[] = [];
  let currentInput = "";
  let startedAt: number | null = null;
  let finishedAt: number | null = null;
  let didRestoreInCurrentWord = false;

  const currentWordIndex = () => committedWords.length;
  const isFinished = () => currentWordIndex() >= promptWords.length;

  const submit = () => {
    if (isFinished()) return;
    const expected = promptWords[currentWordIndex()];
    if (expected === undefined) return;
    const typed = currentInput.trim();
    if (typed === "") {
      currentInput = "";
      return;
    }
    currentInput = "";
    didRestoreInCurrentWord = false;
    if (startedAt === null) startedAt = now();
    committedWords.push({ expected, typed });
    if (isFinished()) finishedAt = now();
  };

  const insert = (ch: string) => {
    if (/\s/.test(ch)) {
      submit();
      return;
    }
    if (isFinished()) return;
    const expected = promptWords[currentWordIndex()] ?? "";
    if (currentInput.length >= expected.length + EXTRA_CAP) return;
    currentInput += ch;
  };

  const canRewind = () =>
    currentInput === "" &&
    !didRestoreInCurrentWord &&
    committedWords.length > 0;

  const deleteBackward = () => {
    if (currentInput !== "") {
      currentInput = currentInput.slice(0, -1);
      return;
    }
    if (!canRewind()) return;
    const restored = committedWords.pop();
    if (!restored) return;
    currentInput = restored.typed;
    finishedAt = null;
    didRestoreInCurrentWord = true;
  };

  const restart = () => {
    committedWords = [];
    currentInput = "";
    startedAt = null;
    finishedAt = null;
    didRestoreInCurrentWord = false;
  };

  const wpm = () => {
    if (committedWords.length === 0) return 0;
    if (startedAt === null) return 0;
    const end = finishedAt ?? now();
    const elapsed = end - startedAt;
    if (elapsed <= 0) return 0;
    const expectedChars = committedWords.reduce(
      (sum, c) => sum + c.expected.length,
      0,
    );
    return expectedChars / 5 / (elapsed / 60000);
  };

  const accuracy = () => {
    let correct = 0;
    let total = 0;
    for (const c of committedWords) {
      total += Math.max(c.expected.length, c.typed.length);
      const n = Math.min(c.expected.length, c.typed.length);
      for (let i = 0; i < n; i++) {
        if (c.expected[i] === c.typed[i]) correct++;
      }
    }
    if (total === 0) return 100;
    return (correct / total) * 100;
  };

  const renderLetters = (
    role: WordRole,
    expected: string,
    typed: string,
  ): RenderLetter[] => {
    const n = Math.max(expected.length, typed.length);
    if (n === 0) return [];
    const out: RenderLetter[] = [];
    for (let i = 0; i < n; i++) {
      const eCh = expected[i];
      const tCh = typed[i];
      if (eCh !== undefined) {
        if (tCh !== undefined) {
          out.push({
            char: eCh,
            role: eCh === tCh ? "correct" : "incorrect",
          });
        } else {
          out.push({
            char: eCh,
            role: role === "submitted" ? "missing" : "pending",
          });
        }
      } else if (tCh !== undefined) {
        out.push({ char: tCh, role: "extra" });
      }
    }
    return out;
  };

  const renderWords = (): RenderWord[] => {
    const cwi = currentWordIndex();
    const finished = isFinished();
    return promptWords.map((expected, i) => {
      let role: WordRole;
      if (i < committedWords.length) role = "submitted";
      else if (i === cwi && !finished) role = "active";
      else role = "upcoming";

      if (role === "upcoming") {
        return {
          role,
          letters: expected
            .split("")
            .map((ch) => ({ char: ch, role: "pending" as const })),
        };
      }
      const typed =
        role === "submitted"
          ? (committedWords[i]?.typed ?? "")
          : currentInput;
      return { role, letters: renderLetters(role, expected, typed) };
    });
  };

  const caret = (): CaretPosition => {
    if (promptWords.length === 0 || isFinished()) return null;
    return {
      wordIndex: Math.min(currentWordIndex(), promptWords.length - 1),
      letterIndex: currentInput.length,
    };
  };

  const elapsedMs = () => {
    if (startedAt === null) return 0;
    const end = finishedAt ?? now();
    return Math.max(0, end - startedAt);
  };

  const progressLabel = () =>
    `${Math.min(currentWordIndex(), promptWords.length)} / ${promptWords.length}`;

  return {
    insert,
    submit,
    deleteBackward,
    restart,
    isFinished,
    renderWords,
    caret,
    wpm,
    accuracy,
    elapsedMs,
    progressLabel,
    hasStarted: () => startedAt !== null,
  };
};

export type Game = ReturnType<typeof createGame>;
