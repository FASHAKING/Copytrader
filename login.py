#!/usr/bin/env python3
"""
One-time login helper — run this on a TRUSTED network (home / phone hotspot),
NOT on the VPS. Datacenter IPs get codes suppressed by Telegram.

Creates sessions/user_<ADMIN_USER_ID>.session without needing the bot running.
Then copy that file to the VPS and run adopt_session.py there.
"""
import asyncio
import os

from dotenv import load_dotenv
from telethon import TelegramClient

load_dotenv()

API_ID = int(os.getenv("API_ID"))
API_HASH = os.getenv("API_HASH")
PHONE = os.getenv("PHONE_NUMBER")
USER_ID = int(os.getenv("ADMIN_USER_ID"))

SESSION_PATH = f"sessions/user_{USER_ID}"


async def main():
    os.makedirs("sessions", exist_ok=True)
    client = TelegramClient(SESSION_PATH, API_ID, API_HASH)
    # Prompts for the login code right here in the terminal.
    # The code arrives in the Telegram app's service chat (check all devices).
    await client.start(phone=PHONE)

    me = await client.get_me()
    print(f"\n✅ Logged in as {me.first_name} (id={me.id}, username={me.username})")
    print(f"📦 Session saved to: {SESSION_PATH}.session")
    print("\nNext steps:")
    print(f"  1. Copy it to the VPS:")
    print(f"     scp {SESSION_PATH}.session root@ali:~/op/VultMirror/sessions/")
    print("  2. On the VPS, from the project dir run: python3 adopt_session.py")
    print("  3. Restart the bot on the VPS")
    print("\n⚠️  Don't run this script again after copying — one active copy only.")

    await client.disconnect()


if __name__ == "__main__":
    asyncio.run(main())
