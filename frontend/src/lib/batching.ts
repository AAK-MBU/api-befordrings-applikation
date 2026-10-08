/**
 * Run async work over a list a few items at a time.
 *
 * "Udvid alle" on a worklist used to fan out without any bound: the loop fired
 * three requests per row and never awaited, and loading one student's
 * bevillinger fans out again — one more request per bevilling. On a page with
 * 80 rows that is roughly 400 requests leaving the browser at once.
 *
 * The API holds a database connection for the length of each request, out of a
 * pool of 10 with 20 overflow. 400 arrive, 30 are served, the rest queue until
 * SQLAlchemy's 30-second pool timeout gives up — and because the pool is
 * shared, a single caseworker pressing that button returned 500s to everybody
 * else using the application at the time.
 *
 * The limit is deliberately low. It is not there to make the page fast; it is
 * there to leave the pool with room for the people who are not pressing the
 * button.
 */

/** How many items are in flight at once. See the note above before raising it. */
export const SAMTIDIGE = 4;

export async function iBatches<T>(
  items: T[],
  arbejde: (item: T) => Promise<unknown>,
  samtidige: number = SAMTIDIGE,
): Promise<void> {
  const koe = [...items];

  // N workers pulling from one queue, rather than fixed slices: a slow student
  // then holds up only its own worker instead of the whole batch.
  const workers = Array.from({ length: Math.max(1, samtidige) }, async () => {
    for (;;) {
      const item = koe.shift();

      if (item === undefined) return;

      try {
        await arbejde(item);
      } catch (error) {
        // One failed student must not abandon the rest of the list.
        console.error("Batch-indlæsning fejlede for ét element:", error);
      }
    }
  });

  await Promise.all(workers);
}
