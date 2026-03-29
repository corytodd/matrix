"""
pingbot responds "pong" to "!ping" in Matrix rooms.

* Encrypted and unencrypted rooms are supported!

E2EE notes:
- Device trust is handled at the crypto layer (ignore_device) independently of
  the application-level allowed_users check. This is required for nio to share
  outbound group sessions with room members.
- The sync loop catches OlmUnverifiedDeviceError (raised when a new device is
  discovered mid-sync before trust is established), resets next_batch so the
  same events are retried, then trusts all devices before the next sync.
- The Olm crypto store is persisted at ./bot_store (Docker volume) so the bot
  keeps the same device ID across restarts. Without this, every redeploy looks
  like a new device to senders and requires re-establishing sessions.

Environment variables (see docker-compose.yml):
  BOT_HOMESERVER     Matrix homeserver URL
  BOT_USERNAME       Bot's Matrix user ID (@pingbot:example.com)
  BOT_PASSWORD       Bot account password
  BOT_ALLOWED_USERS  Comma-separated Matrix user IDs the bot will respond to
"""

import asyncio
import logging
import os
import sys

from nio import (
    AsyncClient,
    InviteEvent,
    MegolmEvent,
    OlmUnverifiedDeviceError,
    RoomMessageText,
)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)],
)
logger = logging.getLogger(__name__)


class Bot:
    def __init__(self, homeserver, user_id, password, store_path, allowed_users):
        self.client = AsyncClient(homeserver, user_id, store_path=store_path)
        self.password = password
        self.allowed_users = allowed_users

    async def start(self):
        self.client.add_event_callback(self.cb_invite, InviteEvent)
        self.client.add_event_callback(self.cb_message, RoomMessageText)
        self.client.add_event_callback(self.cb_encrypted, MegolmEvent)

        await self.client.login(self.password)
        await self.client.keys_upload()

        while True:
            # Save token so we can rewind if the sync throws OlmUnverifiedDeviceError
            # before all callbacks have fired.
            token = self.client.next_batch
            try:
                await self.client.sync(timeout=30000)
            except OlmUnverifiedDeviceError:
                logger.info("New unverified device found, trusting and retrying")
                self.client.next_batch = token
            self._trust_all_devices()

    async def cb_invite(self, room, event):
        """Only join rooms invited by allowed users; others are silently ignored."""
        # Without this check any Matrix user could get the bot's megolm session keys.
        if event.sender not in self.allowed_users:
            logger.warning(f"Ignoring invite from {event.sender}")
            return
        await self.client.join(room.room_id)
        logger.info(f"Joined {room.room_id}")

    async def cb_message(self, room, event):
        """Respond to !ping with pong."""
        if event.sender not in self.allowed_users:
            return
        if event.body == "!ping":
            await self.client.room_send(
                room_id=room.room_id,
                message_type="m.room.message",
                content={"msgtype": "m.text", "body": "pong"},
            )

    def _trust_all_devices(self):
        """Mark all unreviewed devices as ignored so nio can share group sessions.

        Ignored devices receive encrypted messages from the bot but are not
        cryptographically verified. Access control is enforced separately via
        allowed_users in the message callbacks.
        """
        for user_devices in self.client.device_store.values():
            for device in user_devices.values():
                if (
                    not device.verified
                    and not device.blacklisted
                    and not device.ignored
                ):
                    self.client.ignore_device(device)

    async def cb_encrypted(self, room, event):
        """Fired when a message cannot be decrypted (no session key available).

        This typically happens on the first message after a redeploy if the
        sender's client hasn't shared the new megolm session with the bot yet.
        The sync loop will retry and subsequent messages will be decryptable.
        """
        if event.sender not in self.allowed_users:
            return
        logger.warning(f"Undecryptable message from {event.sender} in {room.room_id}")


async def run_bot():
    homeserver = os.environ["BOT_HOMESERVER"]
    username = os.environ["BOT_USERNAME"]
    password = os.environ["BOT_PASSWORD"]
    allowed_users = set(os.environ["BOT_ALLOWED_USERS"].split(","))
    store_path = "./bot_store"
    bot = Bot(homeserver, username, password, store_path, allowed_users)
    await bot.start()


if __name__ == "__main__":
    asyncio.run(run_bot())
