"""Load data/marketing_AB.csv into PostgreSQL as table ab_test.

Usage (from the repo root):
    export DATABASE_URL="postgresql+psycopg2://USER:PASSWORD@HOST:5432/DBNAME"
    python scripts/load_to_postgres.py

The connection string is read from an environment variable so credentials never enter git.
Works with a local PostgreSQL or a hosted one such as Neon.
"""
import os
import sys
from pathlib import Path

import pandas as pd
from sqlalchemy import create_engine, text

ROOT = Path(__file__).resolve().parents[1]


def load_clean() -> pd.DataFrame:
    """Read the CSV exactly as the notebook does: first column is the row index, spaces -> underscores."""
    df = pd.read_csv(ROOT / "data" / "marketing_AB.csv", index_col=0)
    df.columns = df.columns.str.replace(" ", "_")
    return df


def main() -> None:
    url = os.environ.get("DATABASE_URL")
    if not url:
        sys.exit("Set DATABASE_URL first, e.g. postgresql+psycopg2://user:pass@localhost:5432/abtest")

    df = load_clean()
    engine = create_engine(url)
    # chunksize + method="multi" sends many rows per INSERT, which is much faster for 588K rows
    df.to_sql("ab_test", engine, if_exists="replace", index=False, chunksize=20_000, method="multi")

    with engine.begin() as conn:
        conn.execute(text("CREATE INDEX IF NOT EXISTS ix_ab_test_group ON ab_test (test_group)"))
        n = conn.execute(text("SELECT COUNT(*) FROM ab_test")).scalar()
    print(f"Loaded {n:,} rows into ab_test (CSV had {len(df):,}).")
    assert n == len(df), "Row count mismatch between CSV and database"


if __name__ == "__main__":
    main()
