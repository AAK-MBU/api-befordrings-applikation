"""Date utility helpers.

This module contains small reusable date functions used across the API.

Currently it handles:

- Converting OS2Forms timestamps into Python date objects
- Subtracting months from a date while handling month length safely
"""

import logging
from calendar import monthrange
from datetime import date, datetime
from zoneinfo import ZoneInfo

logger = logging.getLogger(__name__)

_TIDSZONE = ZoneInfo("Europe/Copenhagen")


def parse_os2forms_timestamp(value: str | int | None) -> date | None:
    """Convert an OS2Forms timestamp into a date.

    Args:
        value:
            Timestamp value from OS2Forms.

            OS2Forms may provide this as a string or integer.
            If the value is missing or empty, None is returned.

    Returns:
        A Python date object in the Europe/Copenhagen timezone.
        Returns None if no value was provided.

    Notes:
        TWO shapes arrive, because two callers send this field:

          * a Unix timestamp — what OS2Forms' own remote post handler sends,
            e.g. 1790000000
          * an ISO 8601 string — what [RPA].[journalizing] stores and
            rpa-befordring-kontrol forwards, e.g.
            "2026-10-01T14:12:28+00:00"

        Only the first was handled, so a submission from the kontrol process
        raised ValueError inside int() and the whole create returned 500 — no
        bevilling at all, over a date field.

        The timezone matters in both branches: a submission at 23:30 UTC is
        already the next day in Copenhagen, and ansoegningsdato is a date.
        An ISO value carrying its own offset is converted; a naive one is read
        as local time, which is what a timestamp without an offset means here.

        An unparseable value yields None rather than raising. The date can be
        corrected on the bevilling afterwards; a rejected submission cannot be
        recovered without someone noticing it went missing.
    """

    if not value:
        return None

    tekst = str(value).strip()

    # Unix timestamp, including one sent as a numeric string.
    try:
        return datetime.fromtimestamp(int(tekst), tz=_TIDSZONE).date()
    except (ValueError, OverflowError, OSError):
        pass

    # ISO 8601. fromisoformat handles offsets and a trailing "Z" from 3.11 on.
    try:
        tidspunkt = datetime.fromisoformat(tekst)
    except ValueError:
        logger.warning("Kunne ikke læse OS2Forms-tidsstempel: %r", value)
        return None

    if tidspunkt.tzinfo is None:
        tidspunkt = tidspunkt.replace(tzinfo=_TIDSZONE)

    return tidspunkt.astimezone(_TIDSZONE).date()


def subtract_months(value: date, months: int) -> date:
    """Subtract a number of months from a date.

    Args:
        value:
            The original date.

        months:
            Number of months to subtract.

    Returns:
        A new date with the requested number of months subtracted.

    Notes:
        This handles months with different numbers of days.

        Example:
            If value is 2026-03-31 and one month is subtracted, February does
            not have 31 days.

            Instead of crashing, the result becomes 2026-02-28 or 2026-02-29,
            depending on whether it is a leap year.
    """

    # Convert the current month into a shifted month index.
    #
    # Example:
    # March minus 2 months:
    # 3 - 2 = 1
    #
    # January minus 2 months:
    # 1 - 2 = -1
    #
    # The calculations below handle crossing year boundaries.
    month_index = value.month - months

    # Calculate the target year after subtracting months.
    year = value.year + (month_index - 1) // 12

    # Convert the shifted month index back into a normal month number: 1-12.
    month = (month_index - 1) % 12 + 1

    # Find the last valid day in the target month.
    #
    # monthrange(year, month)[1] returns the number of days in that month.
    last_day_in_target_month = monthrange(year, month)[1]

    # Keep the same day number when possible.
    #
    # If the original day does not exist in the target month, use the last
    # valid day instead.
    day = min(value.day, last_day_in_target_month)

    return date(year, month, day)
