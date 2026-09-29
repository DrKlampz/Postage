# Postage

A Postal-style mailbox addon for **WoW: Forever**.

Postage replaces the default mailbox's 7-row paged inbox with one scrollable list showing
every mail at once, with checkboxes and the shift/ctrl/alt-click shortcuts Postal is known for.

## What's in v1.0.0

- **A real inbox list.** Every mail at once, not 7 at a time with pages.
- **Select.** Checkboxes per mail, with Shift-click to select a range and Ctrl-click to select
  everything from one sender.
- **Express.** Shift-click a mail to take it, Ctrl-click to return it.
- **Open Selected / Open All / Return Selected**, queued safely: it won't try to loot mail your
  bags don't have room for, and it keeps going even if a mail vanishes mid-queue (taken some
  other way) instead of getting stuck.
- **A "expiring soon" warning** on mail with less than a day left that still has money or items
  attached.
- **Auction House mail is tagged** so it's easy to spot in the list.
- **Wire.** If you send mail with gold attached and leave the subject blank, Postage fills it in
  with the amount.
- **TradeBlock.** Declines trade requests and guild charter signatures while you're at the
  mailbox, so a mass-mailing session doesn't get derailed by a popup.

## Commands

| Command | What it does |
|---|---|
| `/postage help` | List commands |
| `/postage tradeblock` | Toggle blocking trades/charters while at the mailbox |
| `/postage wire` | Toggle auto-filling the subject with the gold amount |
| `/postage freeslots <n>` | Always leave `n` bag slots open when opening mail |

## What's not here yet

Postal's contact list (BlackBook), quick multi-item attach for mass-mailing, and
resend/forward are planned for a later version.

## Notes on WoW: Forever

Mail actions (sending, looting, returning) aren't flagged as restricted anywhere in Forever's
own API documentation, unlike guild invites or chat, which the client does gate behind a real
click. These are old, stable globals that have worked the same way in every WoW version for
about twenty years. If anything about mail turns out to be click-gated on this client after all,
please open an issue — Postage doesn't yet have a fallback for that.

Bug reports and ideas welcome.
