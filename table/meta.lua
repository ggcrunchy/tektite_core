--- This module provides various metatable operations.

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
local getmetatable = getmetatable
local pairs = pairs
local rawget = rawget
local rawequal = rawequal
local setmetatable = setmetatable
local type = type

-- Modules --
local has_debug, debug = pcall(require, "debug")

-- Cached module references --
local _GetMetafield_
local _FullyWeak_
local _WeakKeyed_

-- Exports --
local M = {}

--
--
--

local function IsTable (v)
	return type(v) == "table"
end

local debug_getmetatable = has_debug and debug.getmetatable

if not debug_getmetatable then
	local getmetatable = getmetatable

	function debug_getmetatable (var)
		local mt = getmetatable(var)

		return IsTable(mt) and mt
	end
end

--
--
--

local function Copy (t, err)
	assert(IsTable(t), err)

	local dt = {}

	for k, v in pairs(t) do
		assert(type(v) == "function", "Non-function property")

		dt[k] = v
	end

	return dt
end

local function MakeIndexWithList (list, old_index)
	local is_table = IsTable(old_index)

	return function(t, k)
		local item = list[k]

		if item ~= nil then
			return item
		elseif is_table then
			return old_index[k]
		else
			return old_index(t, k)
		end
	end
end

local function OldIndexResult (old_index, t, k)
	if IsTable(old_index) then
		return old_index[k]
	elseif old_index then
		return old_index(t, k)
	end
end

local function MakeIndexWithReadProperties (rprops, roldarg, list, old_index)
	rprops = Copy(rprops, "Invalid readable properties (__rprops)")

	if roldarg then
		assert(IsTable(roldarg), "Invalid old __index result argument flags (__roldarg)")

		local old = roldarg

		roldarg = {}

		for k, v in pairs(old) do
			if v then
				roldarg[k] = true
			end
		end
	end

	return function(t, k)
		local prop, old_result = rprops[k]

		if prop then
			if roldarg and roldarg[k] then
				old_result = OldIndexResult(old_index, t, k)
			end

			local what, res = prop(t, k, old_result)

			if what == "use_index_k" then
				k = res
			elseif what ~= "use_index" then
				return what
			end
		end

		local item = list and list[k]

		if item ~= nil then
			return item
		else
			return OldIndexResult(old_index, t, k)
		end
	end
end

local function GetIndexMetamethod (mt, extension)
	local list

	for k, v in pairs(extension) do
		if k ~= "__roldarg" and k ~= "__rprops" and k ~= "__wprops" then
			list = list or setmetatable({}, getmetatable(extension)) -- add lazily, inheriting any lookup behavior
			list[k] = v
		end
	end

	local old_index, rprops = mt and mt.__index, rawget(extension, "__rprops")

	if rprops then
		return MakeIndexWithReadProperties(rprops, rawget(extension, "__roldarg"), list, old_index)
	elseif list and old_index then
		return MakeIndexWithList(list, old_index)
	elseif list then
		return list
	else
		return old_index
	end
end

local function MakeNewIndexWithWriteProperties (wprops, old_newindex)
	wprops = Copy(wprops, "Invalid writeable properties (__wprops)")

	local is_table = IsTable(old_newindex)

	return function(t, k, v)
		local prop = wprops[k]

		if prop then
			local what, res1, res2 = prop(t, v, k)

			if what == "use_newindex_k" then
				k = res1
			elseif what == "use_newindex_v" then
				v = res1
			elseif what == "use_newindex_kv" then
				k, v = res1, res2
			elseif what ~= "use_newindex" then
				return
			end
		end

		if is_table then
			old_newindex[k] = v
		elseif old_newindex then
			old_newindex(t, k, v)
		end
	end
end

local function GetNewIndexMetamethod (mt, extension)
	local old_newindex, wprops = mt and mt.__newindex, rawget(extension, "__wprops")

	if wprops then
		return MakeNewIndexWithWriteProperties(wprops, old_newindex)
	else
		return old_newindex
	end
end

local Cached, Augmented

--- DOCME
-- @ptable object
-- @ptable extension
-- @return _object_.
function M.Augment (object, extension)
	if not Cached then
		Augmented, Cached = _FullyWeak_(), _WeakKeyed_()
	end

	local mt = getmetatable(object)

	assert(IsTable(extension), "Extension must be a table")
	assert(mt == nil or IsTable(mt), "Metatable missing or inaccessible")
	assert(not Augmented[object], "Object's metatable already augmented")

	local cached = Cached[mt]

	if cached then
		assert(rawequal(cached, extension), "Attempt to augment object with different extension")
	else
		local new = { __index = GetIndexMetamethod(mt, extension), __newindex = GetNewIndexMetamethod(mt, extension) }

		setmetatable(object, new)

		Augmented[object], Cached[new] = new, extension
	end

	return object
end

--
--
--

local Choices = { k = {}, v = {}, kv = {} }

for mode, mt in pairs(Choices) do
	mt.__metatable, mt.__mode = true, mode
end

--- DOCME
function M.CanCall (var)
	return type(var) == "function" or _GetMetafield_(var, "__call") ~= nil
end

--
--
--

--- Build a new fully weak table, with a fixed metatable.
-- @treturn table Table.
-- @see WeakKeyed, WeakValued
function M.FullyWeak ()
	return setmetatable({}, Choices.kv)
end

--
--
--

--- DOCMEMORE
--
-- **N.B.** If @{debug.getmetatable} or the @{debug} library itself are absent, a fallback is
-- used internally. This is unreliable in the presence of a **__metatable** key, however. In
-- situations like this, a C utility built on `luaL_getmetafield()` might be in order.
-- @param var Variable to test.
-- @param name Field to request.
-- @treturn boolean _var_ supports the metaproperty?
function M.GetMetafield (var, name)
	local mt = debug_getmetatable(var)

	if IsTable(mt) then
		return rawget(mt, name)
	else
		return nil
	end
end

--
--
--

--- DOCME
function M.HasToString (var)
	return _GetMetafield_(var, "__tostring") ~= nil
end

--
--
--

--- Build a new weak-keyed table, with a fixed metatable.
-- @treturn table Table.
-- @see FullyWeak, WeakValued
function M.WeakKeyed ()
	return setmetatable({}, Choices.k)
end

--
--
--

--- Build a new weak-valued table, with a fixed metatable.
-- @treturn table Table.
-- @see FullyWeak, WeakKeyed
function M.WeakValued ()
	return setmetatable({}, Choices.v)
end

--
--
--

_FullyWeak_ = M.FullyWeak
_GetMetafield_ = M.GetMetafield
_WeakKeyed_ = M.WeakKeyed

return M