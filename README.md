# Postage

A mailbox upgrade for **WoW: Forever**.

Everything Postage adds lives inside the normal mailbox, so it looks and works like part of the game.

## Inbox

- **Select.** A checkbox on every mail. Shift-click a checkbox to select a range, ctrl-click to
  select everything from that sender. Then **Open** or **Return** the checked mail.
- **Open All.** Opens every mail with gold or items attached, of the kinds you choose
  (right-click the button: auction sold/won/expired/cancelled/outbid, Postmaster, players).
  COD mail is always skipped and reported. It keeps bag slots free if you ask it to, and tells
  you how much gold it collected.
- **Express.** Shift-click a mail to take it, ctrl-click to return it. Scroll the mouse wheel
  over the inbox to change pages.
- **DoNotWant.** Each mail shows how long it has left: yellow means it goes back to the sender,
  red means it will be deleted.
- **Pending auction gold.** A readout at the top of the inbox totals auction sales whose gold
  hasn't arrived yet, and when the next one lands. Hover it for each sale.

## Sending

- **BlackBook.** A contacts button next to the To: box with your alts, people you've mailed,
  friends and guild. Names autocomplete as you type. Your alts are listed once you've logged in
  on each with Postage, or add one by typing its name and choosing "Add ... to Alts".
- **Keep recipient.** Tick it to keep the name in the To: box after sending, so you can send
  several mails to the same person.
- **Alt-click** an item in your bags to attach it; **shift-alt-click** attaches every stack of it.
- **QuickAttach.** Buttons beside the Send Mail frame attach all your cloth, leather, ore, herbs,
  cooking, elemental, enchanting or engineering materials in one click.
- **Wire.** Leave the subject empty when sending gold and it's filled in with the amount.

## Reading

- **Copy** shows a mail's text in a box you can copy from.
- **Forward** starts a new mail with the same subject and text (attachments aren't forwarded).

## Other

- **TradeBlock** declines trades and guild charters while the mailbox is open.
- A **Postage** button on the mailbox and a **minimap button** open the options, where every
  feature can be turned off.

## Commands

| Command | What it does |
|---|---|
| `/postage` | Options |
| `/postage help` | List commands and shortcuts |
| `/postage minimap` | Show or hide the minimap button |
| `/postage freeslots <n>` | Keep `n` bag slots free when opening mail |
| `/postage probe` | Check which mailbox parts Postage found on your client |

## Notes on WoW: Forever

Postage attaches itself to Blizzard's mailbox frames. If a feature doesn't appear, run
`/postage probe` and report what it says is missing. QuickAttach's material categories use the
standard item subclass numbers, which haven't been checked on a Forever client yet; the
"All trade goods" button works either way.
