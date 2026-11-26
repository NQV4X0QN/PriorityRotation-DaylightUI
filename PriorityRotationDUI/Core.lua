-- Priority Rotation (DaylightUI Plugin) / Core.lua
-- Registers the plugin and its module with DaylightUI through its public API (DaylightUI/API.md:
-- "A plugin of your own", "Put your settings on a Daylight UI page"). Nothing here touches
-- DaylightUI's internals. One line in chat, from DaylightUI, when its API is too old or another major.

local ADDON, ns = ...

local DUI = _G.DaylightUI
local API = DUI and DUI.API
if type(API) ~= "table" or API.major ~= 1 then return end

ns.API = API
ns.me = API.For(ADDON)

ns.MODULE = ADDON
ns.NEEDS = { 1, 3 }   -- Paint, hooks, texts and settings (API.md "The promise")

DUI:RegisterPlugin(ADDON, {
    needs = ns.NEEDS,
    short = "Rotation",
    color = "7fb2ff",
    blurb = "A one-button rotation from a spell list you build.",
})

ns.defaults = {}

ns.pages = {
    { id = "main", label = "Priority Rotation",
      desc = "A one-button rotation: each press casts the next spell on your list that is ready.",
      groups = {
          { label = "Getting started", items = {
              { type = "text", label = "The rotation, error message and sound settings arrive in the next builds." },
          } },
      } },
}

DUI:RegisterModule(ns.MODULE, {
    plugin = ADDON,
    label = "Priority Rotation",
    defaults = ns.defaults,
    options = { pages = ns.pages },
})
