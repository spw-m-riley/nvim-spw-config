local var_name = function(args)
  local name = args[1][1]
  return string.gsub(name, "(%a)([%w_']*)", function(first, rest)
    return first:lower() .. rest
  end)
end

return var_name
