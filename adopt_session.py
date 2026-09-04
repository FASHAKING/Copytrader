#!/usr/bin/env python3
"""
Adopt a session file created elsewhere (e.g., home network) on the VPS.

- Stores the API credentials from .env in the DB (encrypted with this
  machine's own .encryption_key)
- Marks the session active so load_all_sessions() picks it up on startup

Run from the project directory AFTER copying the .session file here.
"""
import os
import sqlite3

from dotenv import load_dotenv

from database import Database

load_dotenv()

USER_ID = int(os.getenv("ADMIN_USER_ID"))
SESSION_FILE = f"sessions/user_{USER_ID}.session"


def main():
    if not os.path.exists(SESSION_FILE):
        print(f"❌ {SESSION_FILE} not found — copy it from your home machine first:")
        print(f"   scp sessions/user_{USER_ID}.session root@ali:~/op/VultMirror/sessions/")
        return

    db = Database()
    api_id = os.getenv("API_ID")
    api_hash = os.getenv("API_HASH")
    phone = os.getenv("PHONE_NUMBER")

    if not all([api_id, api_hash, phone]):
        print("❌ API_ID / API_HASH / PHONE_NUMBER missing from .env")
        return

    db.update_user_credentials(USER_ID, api_id, api_hash, phone)

    conn = sqlite3.connect(db.db_path)
    conn.execute(
        "UPDATE users SET session_active = 1 WHERE user_id = ?", (USER_ID,)
    )
    conn.commit()
    conn.close()

    print(f"✅ Session adopted for user {USER_ID}")
    print("   Restart the bot — it will load the session automatically.")
    print("   (.venv/bin/python bot.py)")


if __name__ == "__main__":
    main()
