-- =====================================================================
-- AuraCue - Data.lua  (shipped starter catalog)
-- =====================================================================
-- This file lets you publish a base aura catalog with the addon, so new
-- users open the picker to a useful list instead of an empty one.
--
-- HOW TO BUILD / UPDATE IT
--   1. In-game, build up the catalog you want to ship: play, run
--      `/cue gather` on dummies / in zones, and add via normal use so the
--      auras land in your account-wide list.
--   2. Open AuraCue options -> Sharing -> "Export catalog" and copy the
--      string (it starts with CSC1!).
--   3. Paste it as `string` below, and bump `version` by 1.
--
-- HOW IT'S APPLIED
--   On load, if the bundled `version` is higher than what the player has
--   already received, the catalog is merged into their list (only auras
--   they don't already have are added — nothing they changed is touched).
--   Players who delete a starter aura keep it gone until you bump `version`.
--
-- Leave `string` empty (and `version` at 0) to ship no starter data.
-- =====================================================================
local _, ns = ...

ns.BASE_CATALOG = {
    version = 0,
    string  = "",
}
