"""
Write .env by asking for the Azure SQL details, so nobody has to edit a connection string by hand.

    .venv/bin/python etl/setup_env.py

Run it yourself in Terminal. The password stays hidden as you type and is never printed. The
finished connection string is also put on the Mac's clipboard, ready to paste into the GitHub
repository secret AZURE_SQL_URL.
"""

from __future__ import annotations

import getpass
import subprocess
import sys
from pathlib import Path
from urllib.parse import quote

ENV = Path(__file__).resolve().parent.parent / ".env"


def main() -> None:
    print("Find these in the Azure portal: SQL databases, then your database, then Overview.\n")
    login = input("SQL login [Nandita]: ").strip() or "Nandita"
    server = input("Server name, the part before .database.windows.net: ").strip()
    server = server.replace(".database.windows.net", "").strip()
    database = input("Database name: ").strip()
    password = getpass.getpass("Password (it stays hidden as you type): ")
    if not (server and database and password):
        sys.exit("Nothing saved: the server, the database and the password are all needed.")

    # Symbols in a password would break the connection string, so they are encoded here.
    url = (f"mssql+pymssql://{quote(login, safe='')}:{quote(password, safe='')}"
           f"@{server}.database.windows.net:1433/{quote(database, safe='')}")
    ENV.write_text("# Written by etl/setup_env.py. Gitignored: never commit or share this file.\n"
                   f"AZURE_SQL_URL={url}\n")
    ENV.chmod(0o600)        # readable by this Mac user only

    try:
        subprocess.run(["pbcopy"], input=url.encode(), check=True)
        print("\nSaved .env. The connection string is also on your clipboard: paste it as the value "
              "of the GitHub secret AZURE_SQL_URL, then copy something else so it does not linger.")
    except (OSError, subprocess.CalledProcessError):
        print("\nSaved .env.")


if __name__ == "__main__":
    main()
