/**
 * Utilitários compartilhados para ciclo contábil (monthStartDay) e datas BRT (-03:00).
 */

export interface AccountingYearMonth {
  year: number;
  month: number;
}

export interface AccountingMonthWindow {
  year: number;
  month: number;
  start: Date;
  end: Date;
  startIso: string;
  endIso: string;
}

/**
 * Extrai ano, mês e dia do calendário de São Paulo (-03:00).
 */
export function getSaoPauloCalendarParts(referenceDate: Date): {
  year: number;
  month: number;
  day: number;
} {
  const [year, month, day] = new Intl.DateTimeFormat("en-CA", {
    timeZone: "America/Sao_Paulo",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  })
    .format(referenceDate)
    .split("-")
    .map(Number);

  return { year, month, day };
}

/**
 * Formata uma data no padrão YYYY-MM-DD segundo o calendário de São Paulo.
 */
export function formatBrtDateKey(date: Date): string {
  const { year, month, day } = getSaoPauloCalendarParts(date);
  return `${year}-${String(month).padStart(2, "0")}-${String(day).padStart(2, "0")}`;
}

/**
 * Resolve o par (ano, mês) contábil ativo considerando `monthStartDay` (1..28).
 */
export function resolveAccountingYearMonth(
  referenceDate: Date,
  monthStartDay: number,
): AccountingYearMonth {
  const safeStartDay = Math.min(Math.max(Math.trunc(monthStartDay || 1), 1), 28);
  const { year: curYear, month: curMonth, day: curDay } =
    getSaoPauloCalendarParts(referenceDate);

  if (safeStartDay > 1 && curDay < safeStartDay) {
    const prev = new Date(Date.UTC(curYear, curMonth - 2, 1));
    return {
      year: prev.getUTCFullYear(),
      month: prev.getUTCMonth() + 1,
    };
  }

  return { year: curYear, month: curMonth };
}

/**
 * Retorna a janela exata [start, end] do ciclo contábil em UTC equivalente à meia-noite BRT (-03:00).
 */
export function getAccountingMonthWindow(
  year: number,
  month: number,
  monthStartDay: number,
): AccountingMonthWindow {
  const safeStartDay = Math.min(Math.max(Math.trunc(monthStartDay || 1), 1), 28);
  const maxStartDay = new Date(Date.UTC(year, month, 0)).getUTCDate();
  const clampedStartDay = Math.min(safeStartDay, maxStartDay);

  const nextAnchor = new Date(Date.UTC(year, month, 1));
  const maxNextDay = new Date(
    Date.UTC(nextAnchor.getUTCFullYear(), nextAnchor.getUTCMonth() + 1, 0),
  ).getUTCDate();
  const clampedNextDay = Math.min(safeStartDay, maxNextDay);

  // Meia-noite BRT (-03:00) equivale a 03:00 UTC.
  const start = new Date(Date.UTC(year, month - 1, clampedStartDay, 3, 0, 0, 0));
  const end = new Date(
    Date.UTC(
      nextAnchor.getUTCFullYear(),
      nextAnchor.getUTCMonth(),
      clampedNextDay,
      2,
      59,
      59,
      999,
    ),
  );

  return {
    year,
    month,
    start,
    end,
    startIso: formatBrtDateKey(start),
    endIso: formatBrtDateKey(end),
  };
}
