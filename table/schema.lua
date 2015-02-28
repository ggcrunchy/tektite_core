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

-- Cookies --
local _name = {}

-- Cached module references --
local _NewSchema_

-- Exports --
local M = {}

-- TODO: Non-tables default to singletons...
-- TODO: null, required as "true"
-- TODO: predicates, types
-- ^^^ Actually, redesign to incorporate into entries
-- ^^^ Top-level defaults?

--- DOCME
-- @ptable t Table to read.
-- @tparam ?|table|function schema As per @{NewSchema}.
-- @treturn function Reader function, called as
--    value = reader(name, how)
-- TODO: MORE
function M.NewReader (t, schema)
	assert(t, "Missing table to read")

	schema = _NewSchema_(schema)

	return function(name, how)
		local state, res_ = schema(t, name)

		if state == "found" then
			return res_
		elseif how == "strict" or (how ~= "lax" and state == "violation") then
			assert(false, res_ or ("Field <" .. tostring(name) .. "> is missing"))
		end

		return nil
	end
end

-- Adds alts entries to the schema
local function AddEntries (into, entries)
	for _, entry in ipairs(entries) do
		local name = entry.name or entry[1]

		if name then
			if entry.name == nil then
				entry[1] = _name
			end

			into[name], entry.name = entry
		end
	end
end

-- Checks whether a variable is a table or nil
local function CheckTable (var, message)
	if type(var) == "table" then
		return var
	elseif var ~= nil then
		assert(false, message)
	end
end

-- Helper to do a table operation
local function DoOp (var, op, message)
	return CheckTable(var, message) and table_funcs[op](var)
end

-- Copies a group and its subgroups
local function GroupCopy (group, message)
	local new = {}

	for _, alts in ipairs(group) do
		new[#new + 1] = DoOp(alts, "Copy", message)
	end

	return new
end

-- Registered schemas --
local Schemas = setmetatable({}, { __mode = "k" })

--- DOCME
-- @tparam ?|table|function schema As a function, this must be a return value from an
-- earlier call. In this case, the function is a no-op, returning _schema_.
--
-- TODO: AS A TABLE
-- * alts:
-- * alt_groups:
-- * defs:
-- * null:
-- * required:
-- @treturn function Schema function, called as
--    state, result = schema_func(t, name)
-- where _state_ is one of **"found"**, **"missing"**, or **"violation"**.
--
-- When _state_ is **"found"**, _result_ is the value that was looked up in _t_ (if a **null**
-- table is provided and _name_ is found there, this may be **nil**).
--
-- Otherwise, no value was found in _t_, and _result_ is a message to that effect. If _name_
-- was in the **required** table, _state_ will be **"violation"**, or **"missing"** if not.
function M.NewSchema (schema)
	local exists = Schemas[schema]

	assert(type(schema) == "table" or exists, "Invalid schema")

	if not exists then
		local into = {}

		-- Try to add alts table entries.
		if CheckTable(schema.alts, "Non-table alts") then
			AddEntries(into, GroupCopy(schema.alts))
		end

		-- Try to add alt group entries.
		if CheckTable(schema.alt_groups, "Non-table alt group collection") then
			for gname, group in pairs(schema.alt_groups) do
				local entries = GroupCopy(CheckTable(group, "Non-table alt group"))

				for _, entry in ipairs(entries) do
					entry[#entry + 1] = gname
				end

				AddEntries(into, entries)
			end
		end

		-- Install any special lookup tables and create the schema function.
		local defs = DoOp(schema.defs, "Copy")
		local null = DoOp(schema.null, "MakeSet")
		local reqs = DoOp(schema.required, "MakeSet")

		function schema (t, name)
			-- Check the key alternatives in order.
			local keys, res = into[name]

			for i = 1, #(keys or "") do
				local key = keys[i]

				-- Resolve the key to the entry's name, if necessary. This is a paranoid accounting for
				-- the case where a garbage collected object is used as both key and value.
				if key == _name then
					key = name
				end

				-- Look up the key. If a result was found, return it.
				res = t[key]

				if res ~= nil then
					return "found", res
				end
			end

			-- No result was found, so try to find a default, returning it if found. Otherwise, check
			-- whether the key being nil is acceptable, in which case it is also interpreted as found.
			res = defs and defs[name]

			if res ~= nil or (null and null[name]) then
				return "found", res

			-- The result is indeed missing; report as much, according to whether it was required.
			else
				return (reqs and reqs[name] and "violation") or "missing", keys and keys.message or "Missing"
			end
		end

		-- Register the schema to avoid spurious reparses.
		Schemas[schema] = true
	end

	return schema
end

-- Cache module members.
_NewSchema_ = M.NewSchema

-- Export the module.
return M