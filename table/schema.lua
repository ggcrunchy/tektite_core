--- This module provides some functionality for reading tables, e.g. options, via a schema.

--
-- Permission is hereby granted, free of charge, to any person obtaining
-- a copy of this software and associated documentation files (the
-- "Software"), to deal in the Software without restriction, including
-- without limitation the rights to use, copy, modify, merge, publish,
-- distribute, sublicense, and/or sell copies of the Software, and to
-- permit persons to whom the Software is furnished to do so, subject to
-- the following conditions:
--
-- The above copyright notice and this permission notice shall be
-- included in all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
-- EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
-- MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
-- IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
-- CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
-- TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
-- SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
--
-- [ MIT license: http://www.opensource.org/licenses/mit-license.php ]
--

-- Standard library imports --
local assert = assert
local ipairs = ipairs
local pairs = pairs
local tostring = tostring
local type = type

-- Modules --
local table_funcs = require("tektite_core.table.funcs")

-- Exports --
local M = {}

-- --
local Schemas = setmetatable({}, { __mode = "k" })

--
local function DoOp (var, op, message)
	if type(var) == "table" then
		return table_funcs[op](var)
	elseif message then
		assert(false, message)
	end
end

--
local function DoAndCopy (var, iter, message)
	local copy = DoOp(var, "Copy")

	if copy then
		for k, v in iter(copy) do
			copy[k] = DoOp(v, "Copy", message)
		end
	end

	return copy
end

--
local function Parse (schema)
	 if not Schemas[schema] then
		-- 
		local defs = DoOp(schema.defs, "Copy")
		local null = DoOp(schema.null, "MakeSet")
		local reqs = DoOp(schema.required, "MakeSet")

		--
		local alts = DoAndCopy(schema.alts, pairs, "Non-table alt")
		local alt_groups = DoAndCopy(schema.alt_groups, pairs, "Non-table alt group")
		local ialts = DoAndCopy(schema.ialts, ipairs, "Non-table indexed alt")

		--
		Schemas[schema] = function(opts, var)
			--
		end
	end

	return Schemas[schema]
end

--- DOCME
function M.NewReader (opts, schema)
	assert(opts, "Missing options")
	assert(type(schema) == "table" or Schemas[schema], "Invalid schema")

	--
	schema = Parse(schema)

	return schema and function(name, how)
		local state, res, message = schema(opts, name)

		if state == "found" then
			return res
		elseif how == "strict" or (how ~= "lax" and state == "missing_required") then
			assert(false, "Field " .. tostring(name) .. " is missing")
		end

		return nil
	end
end

-- Export the module.
return M