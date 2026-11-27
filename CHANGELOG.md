# Postage

## v1.5.18

- Fixed the new-mail sound always playing the game's whisper sound whatever you picked, for the same reason: a sound file that played without the game confirming it was treated as failed

## v1.5.17

- Quick attach: the Jewelcrafting button is now called Gems, and it finds gems the game files under Other trade goods (Malachite, Tigerseye, Moss Agate, Shadowgem, Jade, Lesser Moonstone, Citrine, Aquamarine, pearls and so on). They no longer also show up under Other trade goods.
- Quick attach: the Engineering button also finds parts by name (casings, tubes, bolts, wiring, modulators, blasting powder and similar), not just the ones filed as parts.

## v1.5.16

- Personal sounds can be dropped into Media\\personal and listed in PersonalSounds.lua; they show up in the same picker (this file and folder are not part of the public release)
- New option: play a sound when new mail arrives (off until you switch it on). Pick from 15 sounds made for Postage, ten of the game's own sounds, or your own file saved as Media\\mysound.ogg. Choosing a sound plays it, and there is a Play it button. Find it under New mail sound in the options (Alt-click the minimap button)

## v1.5.15

- Redrawn anarchy symbol with a hand-brushed, worn look

## v1.5.14

- New background symbols: sword, crossed swords, shield, sun and paw print
- The background symbol can now be rotated and mirrored

## v1.5.13

- New background symbols: Celtic cross, anarchy, peace sign, skull and crossbones, radiation, atom, infinity, lightning bolt, anchor, Helm of Awe, valknut, Eye of Providence, triskele and fleur-de-lis
- The background symbol can now be moved left, right, up and down, and resized
- Picking a color for a piece of artwork now turns its own-color option on, so the color changes at once

## v1.5.12
- Every piece of artwork (corners, crest, edge pattern, title banner, divider, middle emblem) can now have its own color. New "Your file" emblem slots show your own faction, race and city images from the Media folder.

## v1.5.11
- More emblems: religious, Wiccan, Pagan, Druid, Satanic and occult symbols from many faiths, and the names are tidied.
- The artwork can have a color of its own (Artwork section): corners, crest, edges, banner, divider and the middle emblem.
- The close button in the top right can be restyled (the game's X, boxed, plain, red, filled or hidden) with its own size and color.
- The game-icon emblems (faction crests, race and city icons) are removed; looks that used them show your class emblem.
- Fixed the list preview staying open after a pick; the divider under the title no longer runs through the search row.

## v1.5.10
- Emblem list: Pinnacle star, Sunburst, Crown, Crossed swords, Flame and Compass rose; the game's own race sigils and city banners (Stormwind, Orgrimmar and the rest); religious symbols (cross, Celtic cross, Star of David, crescent and star, Wheel of Dharma, yin and yang, ankh, lotus, hamsa, triquetra, torii gate).
- Pointing at an entry in the emblem, corner, crest, edge, banner and divider lists shows a small preview of it.
- The Horde and Alliance crests use the game's round PvP emblem; the title banner is centered with the title.

## v1.5.9
- Gradients: pick both colors, each end's opacity, vertical, horizontal, diagonal, middle-out or center-to-borders, over or instead of the background texture; plus a theme with its own emblem, corners, crest and edge for every talent spec, and a "My spec" automatic theme.
- Look profiles: save your look under a name and switch between saved looks at any time; every character remembers which profile it wears (Look panel, top).
- World of Warcraft flavored art, all optional: nine class themes (Warrior to Druid) with an original emblem, corner pieces, crest and colors for each class, plus a "My class (automatic art)" theme that picks yours; Blue and gold kingdom, Red and iron war camp, Moonlit grove and Plaguelands themes; new spiked corners, horn, crescent and skull crests, and an iron spike edge. The emblem in the middle of the window can also show your class or your talent tree using the game's own icons. Find them in the window options under Colors > Theme and Artwork.
- More optional artwork for the window box: ornament strips along the edges (rope, chain, pearls, runes, vine), a banner behind the title (ribbon, riveted plaque, scroll, jeweled plate), a divider with an ornament under the title, and a faint emblem in the middle of the window (compass rose, shield, laurel wreath, star, runic rings). All in the new Artwork section of the window options; the eight art themes now use them, and the crest sits above the top edge.
- New optional artwork in the window look: seven textured backgrounds (wood planks, aged paper, arcane starfield, runed slate, riveted iron, damask tapestry, dragon scales), five carved corner pieces (filigree, vines, runes, iron plates, arcane sigil), four crests for the top edge (winged, jeweled, scrollwork, crown), and eight ready-made art themes (Arcane library, Dwarven forge, Elven glade, Old tome, Runestone, Royal court, Dragonscale, Oak lodge). Pick them in the window options (Colors > Theme, Background, Border > Corner artwork and Crest). Everything is off until you choose it and syncs between your add-ons like the rest of the look.
- Works completely on its own. Professions for alts you have not logged in with yet are borrowed from another add-on's saved data only when that add-on is loaded; otherwise they appear once you log in on them.
- Removed the add-on-to-add-on theming hooks and cross-add-on names from the window look code; the shared look sync between your add-ons works the same.
- The "Pulse the flair" option now also pulses the edge finish (soft, bevel, double line and glow), not just the corner studs.

## v1.5.8
- Look sync: the first time your add-ons meet, they now all take on the same look right away instead of waiting for you to change something.

## v1.5.7
- Your custom look is now shared with your other add-ons: change colors, background, border or opacity in one and the rest follow (the newest change wins). It is on by default; untick "Sync my look with my other add-ons" in the Look window to turn it off.
- The subject line now fills itself with the first attached item's name (with the stack size when it is more than one) when you attach items without sending gold, and clears again if you take the items off.

## v1.5.5
- Inbox: the paging row (Prev, Next, Open All) is now measured on screen and lifted whenever any part of it hangs over the bottom edge of the window, whatever skin or scale is in use.

## v1.5.4
- Inbox: the Prev / Next arrows and Open All no longer hang over the bottom edge of the window; the window has a little more room under the paging row.

## v1.5.3
- The two leather quick-attach buttons (raw hides and cured leather) are now one Leather button that attaches both.

## v1.5.2
- Fonts: the font pack now ships inside this add-on (Fonts folder), so the separate Look Fonts add-on is no longer needed, and there are about 60 more fonts to pick from under Look > Font.
- Alts on a different realm (for example your PvE characters while on a PvP realm) are no longer listed, since you can't mail them from there.
- Fix: the Alts list showed a long realm suffix after names (and overlapped the profession tags) when an alt's realm was saved with different spelling than the current one.
- Also treats a realm saved with a prefix (for example "CAMWOWUS2Realm1PvE") as the same as the current realm.

## v1.5.1
- Fix: two-part character names; New: /issues log.

## v1.5.0
- Alts list: each alt now shows its professions in shorthand next to its name (BS, LW, ALC, HRB, MIN, TAI, ENG, ECH, SKN, JC, INS; main professions only). Each alt records its professions when you log in on it (and when you learn a new one). Alts you haven't logged in on yet borrow what Guildie's armory or Profiteer already saved for them (English profession names only).
- Quick attach: new Jewelcrafting button that attaches all your gems, cut and uncut. Switch it off with the other profession buttons in the Mailbox tab.
- Quick attach: new gear button that attaches every armor piece and weapon in your bags that is not soulbound and is uncommon (green) or better, so you can mail it to an enchanter to disenchant. Bags with soulbound gear are left alone. Switch it off with the other buttons in the Mailbox tab.

## v1.4.4
- Send: attach items from the reagent bag too (quick-attach buttons, Shift+Alt+click, counts).
- Characters window: full names in class colors, delete saved characters, deleted ones removed automatically.
- Inbox paper follows the look.
- Shared look: background color picker, 13 new backgrounds with brightness and grain, a gold trim option, and buttons and slots stay visible on a pure black panel.
