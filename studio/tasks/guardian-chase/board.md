# guardian-chase — board

- Opened: 2026-10-19 · From: owner (chat) · Task 5 of 8. Built on `cursor/biome-banner-87c7`.

## Original ask (quoted, key lines)

> Guardians are powerful, biome-specific monsters that chase players carrying newly collected seeds or plants ... forcing players to escape and return to their own base to secure their loot.
> 15 unique Guardians ... Day or night ... Digging does not trigger a chase ... Picking up a seed triggers the chase ... Siren warning ... Red screen flash ... approximately 2–3 seconds ... RUN! banner ... large red banner with bold white RUN! text at the top-center ... Guardian targeting: Each Guardian pursues only the player who triggered its chase ... Guardian speed: Each Guardian's movement speed is determined by its biome's Recommended Speed value. A balanced scaling formula converts that value into playable movement speed ... Chase UI: Keep the RUN! banner visible while the chase is active ... DROP button.
> Knockback ... briefly stuns them. Seed drops at the catch location. No teleporting back ... 20-second recovery timer ... Timer resets on pickup ... Chase restarts ... Caught again: ... drops at the new catch location ... Timer expires: ... disappears permanently. Banking secures the seed: When the player reaches their own base and banks the seed, it becomes secured and the chase ends.
> Chase activation, catch detection, knockback, seed drop location, timer, recovery, and banking must be validated by the server ... Only one player can recover a particular dropped seed at a time ... The Guardian should not keep attacking after the player has successfully banked the seed.
> Core rule: A Guardian chase begins when a player collects a seed or plant, regardless of the time of day. Getting caught causes knockback and drops the seed at the catch location, giving the player 20 seconds to recover it and try escaping again.

Full rows: `studio/tasks/intake-2026-10-19.md` section 5.
