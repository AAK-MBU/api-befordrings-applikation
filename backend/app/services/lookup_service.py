"""Service layer for lookup/reference data.

This module contains read-only lookup methods used by the frontend.

Lookup data is typically used for dropdowns, select fields, filters, and other
UI options.

The service returns lookup records in a shared format:

    {
        "id": ...,
        "label": ...
    }

This keeps the frontend simpler because most lookup endpoints return the same
basic structure.
"""

from sqlalchemy import select, true
from sqlalchemy.orm import Session

from app.models.adresse import Adresse
from app.models.lookup import (
    Afgoerelsesbrev,
    Befordringstype,
    Hjaelpemiddel,
    Hjemmel,
    KoerselstypeTillaeg,
    PPRSagsbehandler,
    Sagsbehandler,
    Skolematrikel,
    Status,
    Tidspunkt,
    Ugedag,
    Ungdomsuddannelse,
)


class LookupService:
    """Service class for lookup-related database reads.

    Args:
        db:
            SQLAlchemy database session.
    """

    def __init__(self, db: Session):
        """Initialize the service with a database session."""

        self.db = db


    def _get_lookup_records(
        self,
        model,
        id_column,
        label_column,
        only_active: bool = True,
        order_column=None,
    ):
        """Get lookup records from a model in a shared id/label format.

        Args:
            model:
                SQLAlchemy model class to query.

            id_column:
                Column used as the returned "id" value.

            label_column:
                Column used as the returned "label" value.

            only_active:
                Whether to only return active records.

                If True and the model has an "aktiv" column, only rows where
                aktiv is True are returned.

            order_column:
                Optional column used for sorting.

                If not provided, the label column is used for sorting.

        Returns:
            A list of dictionaries in this format:

                [
                    {
                        "id": 1,
                        "label": "Some value",
                    }
                ]

        Notes:
            This helper keeps the individual lookup methods very small.

            It also makes the frontend easier to work with because all lookup
            endpoints return the same field names: id and label.
        """

        # Default sorting is by the visible label text.
        order_column = order_column or label_column

        # Select only the two fields the frontend needs.
        #
        # The columns are labelled as "id" and "label" so all lookup endpoints
        # return the same structure, even though the database column names are
        # different.
        statement = select(
            id_column.label("id"),
            label_column.label("label"),
        )

        # Many lookup tables have an "aktiv" column.
        #
        # hasattr(model, "aktiv") makes this helper reusable for models that
        # have the column and models that do not.
        if only_active and hasattr(model, "aktiv"):
            statement = statement.where(model.aktiv == true())

        statement = statement.order_by(order_column)

        rows = self.db.execute(statement).mappings().all()

        return [dict(row) for row in rows]


    def get_hjemler(self):
        """Get available hjemler.

        Returns:
            A list of hjemmel records as id/label dictionaries.
        """

        return self._get_lookup_records(
            model=Hjemmel,
            id_column=Hjemmel.hjemmel_id,
            label_column=Hjemmel.hjemmel_tekst,
        )


    def get_afgoerelsesbreve(self):
        """Get available afgørelsesbreve.

        Returns:
            A list of afgørelsesbrev records as id/label dictionaries.
        """

        return self._get_lookup_records(
            model=Afgoerelsesbrev,
            id_column=Afgoerelsesbrev.afgoerelsesbrev_id,
            label_column=Afgoerelsesbrev.afgoerelsesbrev_tekst,
        )


    def get_sagsbehandlere(self):
        """Get available sagsbehandlere.

        Returns:
            A list of sagsbehandler records as id/label dictionaries.
        """

        return self._get_lookup_records(
            model=Sagsbehandler,
            id_column=Sagsbehandler.sagsbehandler_id,
            label_column=Sagsbehandler.sagsbehandler_tekst,
        )


    def get_ppr_sagsbehandlere(self):
        """Get available PPR sagsbehandlere.

        Returns:
            A list of PPR sagsbehandler records as id/label dictionaries.
        """

        return self._get_lookup_records(
            model=PPRSagsbehandler,
            id_column=PPRSagsbehandler.ppr_sagsbehandler_id,
            label_column=PPRSagsbehandler.ppr_sagsbehandler_tekst,
        )


    def get_status(self):
        """Get available status values.

        Returns:
            A list of status records as id/label dictionaries.
        """

        return self._get_lookup_records(
            model=Status,
            id_column=Status.status_id,
            label_column=Status.status_tekst,
        )


    def get_skolematrikel(self):
        """Get available skolematrikler.

        Returns:
            A list of skolematrikel records as id/label/skolekode dictionaries.

        Notes:
            only_active=False means both active and inactive school locations
            are returned.

            This can be useful if old bevillinger reference skolematrikler
            that are no longer active.

            skolekode is included in addition to the standard id/label fields
            so that callers (e.g. the RPA conversion bot) can build a
            skolekode → matrikel_id lookup without a separate query.
        """

        rows = self.db.execute(
            select(
                Skolematrikel.matrikel_id.label("id"),
                Skolematrikel.matrikel_navn.label("label"),
                Skolematrikel.skolekode,
            ).order_by(Skolematrikel.matrikel_navn)
        ).mappings().all()

        return [dict(row) for row in rows]


    def get_hjaelpemidler(self):
        """Get available hjælpemidler.

        Returns:
            A list of hjælpemiddel records as id/label dictionaries.
        """

        return self._get_lookup_records(
            model=Hjaelpemiddel,
            id_column=Hjaelpemiddel.hjaelpemiddel_id,
            label_column=Hjaelpemiddel.hjaelpemiddel_tekst,
        )


    def get_tidspunkter(self):
        """Get available tidspunkter.

        Returns:
            A list of tidspunkt records as id/label dictionaries.
        """

        return self._get_lookup_records(
            model=Tidspunkt,
            id_column=Tidspunkt.tidspunkt_id,
            label_column=Tidspunkt.tidspunkt_tekst,
        )


    def get_koerselstyper(self):
        """Get available kørselstyper/befordringstyper.

        Returns:
            A list of befordringstype records as id/label dictionaries.
        """

        return self._get_lookup_records(
            model=Befordringstype,
            id_column=Befordringstype.befordringstype_id,
            label_column=Befordringstype.befordringstype_tekst,
        )


    def get_koerselstype_tillaeg(self):
        """Get available kørselstype tillæg.

        Returns:
            A list of kørselstype tillæg records as id/label dictionaries.
        """

        return self._get_lookup_records(
            model=KoerselstypeTillaeg,
            id_column=KoerselstypeTillaeg.tillaeg_id,
            label_column=KoerselstypeTillaeg.tillaeg_tekst,
        )


    def get_skolematrikel_coordinates(self, matrikel_id: int):
        """Get latitude and longitude for a single skolematrikel.

        Args:
            matrikel_id:
                Primary key of the skolematrikel to look up.

        Returns:
            A dictionary with matrikel_id, latitude, and longitude,
            or None if no matching row exists.
        """

        row = self.db.execute(
            select(
                Skolematrikel.matrikel_id,
                Skolematrikel.latitude,
                Skolematrikel.longitude,
            ).where(Skolematrikel.matrikel_id == matrikel_id)
        ).mappings().one_or_none()

        return dict(row) if row else None


    def get_ungdomsuddannelse_coordinates(self, ungdomsuddannelse_id: int):
        """Get latitude and longitude for a single ungdomsuddannelse.

        Args:
            ungdomsuddannelse_id:
                Primary key of the ungdomsuddannelse to look up.

        Returns:
            A dictionary with ungdomsuddannelse_id, latitude, and longitude,
            or None if no matching row exists.
        """

        row = self.db.execute(
            select(
                Ungdomsuddannelse.ungdomsuddannelse_id,
                Ungdomsuddannelse.latitude,
                Ungdomsuddannelse.longitude,
            ).where(Ungdomsuddannelse.ungdomsuddannelse_id == ungdomsuddannelse_id)
        ).mappings().one_or_none()

        return dict(row) if row else None


    def get_ungdomsuddannelser(self):
        """Get available ungdomsuddannelser.

        Returns:
            A list of ungdomsuddannelse records as id/label dictionaries.
        """

        return self._get_lookup_records(
            model=Ungdomsuddannelse,
            id_column=Ungdomsuddannelse.ungdomsuddannelse_id,
            label_column=Ungdomsuddannelse.ungdomsuddannelse_navn,
            only_active=False,
        )


    def get_dage(self):
        """Get available weekdays/days.

        Returns:
            A list of weekday records as id/label dictionaries.
        """

        return self._get_lookup_records(
            model=Ugedag,
            id_column=Ugedag.dag_id,
            label_column=Ugedag.dag_tekst,
        )


    def get_adresser(self, q: str):
        """Search addresses by partial text.

        Args:
            q:
                Search string. Only rows where adresse_tekst starts with this
                value are returned. Minimum 2 characters enforced at the
                endpoint level.

        Returns:
            Up to 50 address records as id/label dictionaries, ordered
            alphabetically by address text.
        """

        rows = self.db.execute(
            select(
                Adresse.adresse_id.label("id"),
                Adresse.adresse_tekst.label("label"),
            )
            .where(Adresse.adresse_tekst.like(f"{q}%"))
            .order_by(Adresse.adresse_tekst)
            .limit(50)
        ).mappings().all()

        return [dict(row) for row in rows]


