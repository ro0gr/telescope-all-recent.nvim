-- local frecency = require "telescope._extensions.frecency.db_client"
-- local sql_wrapper = require "telescope._extensions.frecency.sql_wrapper"
local cache = require "telescope-all-recent.cache"
package.loaded["telescope-all-recent.frecency"] = nil
local db_client = require "telescope-all-recent.frecency"
package.loaded["telescope-all-recent.override"] = nil
local override = require "telescope-all-recent.override"

db_client.init()

-- TODO: fix TodoTelescope
local default_config = {
  default = {
    disable = false,
    use_cwd = true,
    sorting = 'frecency'
  },
  pickers = {
    planets = {
      disable = false,
      use_cwd = false
    },
    commands = {
      use_cwd = false
    },
  }
}
local config = default_config

local function establish_picker_settings()
  local picker_info = cache.picker_info
  -- for now we must have the name of the picker and an existing picker object
  -- TODO: in the future it should be possible to configure exact details as config
  if type(picker_info.name) ~= "string" or not picker_info.object then
    -- print('no name or object')
    cache.reset()
    return
  end

  local name = cache.picker_info.name
  local cwd = cache.picker_info.cwd
  -- disable option
  local picker_config = config.pickers[name]
  local function get_config(value)
    if picker_config and picker_config[value] ~= nil then
      return picker_config[value]
    end
    return config.default[value]
  end

  if get_config('disable') then
    -- print('disabled')
    cache.reset()
    return
  end

  -- cwd options
  if not cwd then
    if get_config('use_cwd') then
      cwd = vim.fn.getcwd()
    else
      cwd = ''
    end
  end
  cache.picker = { name = name, cwd = cwd }

  -- sorting options
  cache.sorting = get_config('sorting')
  print(cache.sorting)
end

local on_new_picker = function()
  establish_picker_settings()
  if not cache.picker then
    return
  end

  -- TODO: pass sorting function
  local entry_scores = db_client.get_picker_scores(cache.picker, cache.sorting)
  local scoring_boost_table = {}
  for i, entry_score in ipairs(entry_scores) do
    scoring_boost_table[entry_score.entry.value] = (#entry_scores - i + 1) * 0.000001
  end
  cache.sorting_function_generator = function(original_sorting_function)
    return function(sorter, prompt, line)
      local score = original_sorting_function(sorter, prompt, line)
      if score > 0 then
        score = score - (scoring_boost_table[line] or 0)
        if score < 0 then score = 0 end
      end
      -- print("new score", score, "item", line, "scoring boost", scoring_boost_table[line])
      return score
    end
  end
end

local on_entry_confirm = function(value)
  if cache.picker then
    db_client.update_entry(cache.picker, value)
    cache.reset()
  end
end
-- TODO: on telescope exit also reset the cache

local M = {}
function M.setup(opts)
  config = vim.tbl_deep_extend('force', default_config, opts)
  override.restore_original()
  override.override(on_new_picker, on_entry_confirm)
end

M.setup {}
-- override.restore_original()

return M
