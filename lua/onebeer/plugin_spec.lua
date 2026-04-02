---@alias onebeer.PluginOpts table
---@alias onebeer.PluginOptsFactory fun(): onebeer.PluginOpts
---@alias onebeer.PluginConfig fun(spec: onebeer.PluginSpec, opts: onebeer.PluginOpts|nil)
---@alias onebeer.PluginDependency string|onebeer.PluginSpec
---@alias onebeer.PluginModule onebeer.PluginSpec|onebeer.PluginSpec[]

---@class onebeer.PluginKey
---@field [1] string
---@field [2] string|fun()|nil
---@field mode? string|string[]
---@field desc? string

---@class onebeer.PluginSpec
---@field [1]? string
---@field src? string
---@field name? string
---@field version? string
---@field branch? string
---@field main? string
---@field lazy? boolean
---@field priority? integer
---@field event? string|string[]
---@field ft? string|string[]
---@field cmd? string|string[]
---@field keys? onebeer.PluginKey[]
---@field init? fun()
---@field opts? onebeer.PluginOpts|onebeer.PluginOptsFactory
---@field config? boolean|onebeer.PluginConfig
---@field build? string
---@field dependencies? onebeer.PluginDependency[]
---@field enabled? boolean|fun():boolean

return {}
