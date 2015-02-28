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
local format = string.format
local ipairs = ipairs
local pairs = pairs
local tostring = tostring
local type = type

-- Modules --
local table_funcs = require("tektite_core.table.funcs")
local var_preds = require("tektite_core.var.predicates")

-- Cookies --
local _name = {}

-- Cached module references --
local _NewSchema_

-- Exports --
local M = {}

--- DOCME
-- @ptable t Table to read.
-- @tparam ?|table|function schema As per @{NewSchema}.
-- @tparam[opt] callable op
-- @treturn function Reader function, called as
--    value = reader(name, how)
-- TODO: MORE
function M.NewReader (t, schema, op)
	assert(t, "Missing table to read")
	assert(op == nil or var_preds.IsCallable(op), "Uncallable op")

	schema, op = _NewSchema_(schema), op or assert

	return function(name, how)
		local state, res_, message = schema(t, name)

		if state == "found" then
			return res_
		elseif how == "strict" or (how ~= "lax" and state == "violation") then
			op(false, format("Field <%s>: %s%s", tostring(name), res_, format(#message > 0 and " (%s)" or "", message)))
		end

		return nil
	end
end

-- Checks whether a variable is callable or nil
local function CheckCallable (var, message)
	if var_preds.IsCallable(var) then
		return var
	elseif var ~= nil then
		assert(false, message)
	end
end

-- Processes data following the aux table format
local function ProcessAuxFields (t, out)
	out = out or t

	for k, v in pairs(t) do
		local elem, what, message = v[1], v[2], v[3]

		if what == "bool" then
			elem = not not elem
		elseif what == "func" then
			CheckCallable(elem, message)
		end

		if out == t then
			v[1] = elem
		else
			out[k] = elem
		end
	end

	return t
end

-- Adds alts entries to the schema
local function AddEntries (into, aux, entries)
	for _, entry in ipairs(entries) do
		local name = entry.name or entry[1]

		assert(name ~= nil, "Empty entry")

		-- Guard against cycles if the first alternative doubles as the name.
		if entry.name == nil then
			entry[1] = _name
		end

		-- Add the entry to the list and remove any now-redundant name field.
		into[name], entry.name = entry

		-- Remove redundant fields.
		ProcessAuxFields(aux, entry)

		for k, v in pairs(aux) do
			if v[1] == entry[k] then
				entry[k] = nil
			end
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

-- Helper to do a table copy
local function Copy (var, message)
	return CheckTable(var, message) and table_funcs.Copy(var)
end

-- Copies a group and its subgroups (or non-table singletons)
local function GroupCopy (group, message)
	local new = {}

	for _, alts in ipairs(group) do
		if type(alts) == "table" then
			new[#new + 1] = Copy(alts, message)
		else
			new[#new + 1] = { alts }
		end
	end

	return new
end

-- Helper to read a bool out of a table, if present
local function ReadBool (entry, aux, name)
	local bool = entry and entry[name]

	if bool == nil then
		return aux[name]
	else
		return bool
	end
end

-- Helper to choose a value which may be in either of two tables
local function Choose (t1, t2, name)
	local first = t1[name]

	if first == nil then
		return t2.name
	else
		return first
	end
end

-- Chooses and runs a predicate, if it exists
local function TryPredicate (res, entry, aux)
	local pred, err = Choose(entry, aux, "predicate")

	if pred == nil or pred(res) then
		return true
	else
		return false, err ~= nil and tostring(err) or "Failed predicate"
	end
end

-- Chooses and checks type information, if it exists
local function TypeCheck (res, entry, aux)
	local expected = Choose(entry, aux, "type")

	if expected == nil then
		return entry.type_func == nil, "Entry has type function, but no type to check"
	end

	local res_type = (Choose(entry, aux, "type_func") or type)(res)

	if res_type == expected then
		return true
	else
		return false, format("Type mismatch; expected %s, got %s", tostring(expected), tostring(res_type))
	end
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
-- @treturn function Schema function, called as
--    state, result, message = schema_func(t, name)
-- where _state_ indicates one of three outcomes of the lookup.
--
-- When _state_ is **"found"**, _result_ is the value that was looked up in _t_.
--
-- Otherwise, no value was found in _t_, and _result_ is a message to that effect. If _name_
-- was in the **required** table, _state_ will be **"violation"**, or **"missing"** if not. TODO: MESSAGE
function M.NewSchema (schema)
	local exists = Schemas[schema]

	assert(type(schema) == "table" or exists, "Invalid schema")

	if not exists then
		-- Prepare any default auxiliary information
		local aux, into = ProcessAuxFields{
			null_ok = { schema.def_null_ok, "bool" },
			required = { schema.def_required, "bool" },
			type = { schema.def_type },
			predicate = { schema.def_predicate, "func", "Uncallable predicate" },
			type_func = { schema.def_type_func, "func", "Uncallable type function" }
		}, {}

		-- Add any alts table entries.
		if CheckTable(schema.alts, "Non-table alts") then
			AddEntries(into, aux, GroupCopy(schema.alts))
		end

		-- Add any alt group entries.
		if CheckTable(schema.alt_groups, "Non-table alt group collection") then
			for gname, group in pairs(schema.alt_groups) do
				local entries = GroupCopy(CheckTable(group, "Non-table alt group"))

				for _, entry in ipairs(entries) do
					-- If requested, prefix each alternative with the group name.
					if group.prefixed then
						for i, v in ipairs(entry) do
							entry[i] = gname .. v
						end
					end

					-- Add the group name as the final alternative.
					entry[#entry + 1] = gname
				end

				AddEntries(into, aux, entries)
			end
		end

		-- Install any defaults table and create the schema function.
		local defs = Copy(schema.defs)

		function schema (t, name)
			-- Check the key alternatives in order.
			local keys, res = into[name]

			for i = 1, #(keys or "") do
				local key = keys[i]

				-- Resolve the key to the entry's name, if necessary. This accounts for the case where a
				-- garbage-collected object was used both as the name and as one of the alternatives.
				if key == _name then
					key = name
				end

				-- Look up the key. If a result was found, check it for integrity. If all is well, return
				-- the result; otherwise, report a violation.
				res = t[key]

				if res ~= nil then
					local ok, err = TypeCheck(res, keys, aux)

					if ok then
						ok, err = TryPredicate(res, keys, aux)

						if ok then
							return "found", res
						end
					end

					return "violation", err, keys.message
				end
			end

			-- No result was found, so try to find a default, returning one if available. Otherwise,
			-- check whether nil itself is acceptable, which if so is also interpreted as found.
			res = defs and defs[name]

			if res ~= nil or ReadBool(keys, aux, "null_ok") then
				return "found", res

			-- The result is indeed missing; report as much, including whether it was also required.
			elseif ReadBool(keys, aux, "required") then
				return "violation", "Required entry is missing", keys and keys.message or ""
			else
				return "missing", "Missing entry", keys and keys.message or ""
			end
		end

		-- Register the schema to avoid spurious recomputation.
		Schemas[schema] = true
	end

	return schema
end

-- Cache module members.
_NewSchema_ = M.NewSchema

-- Export the module.
return M