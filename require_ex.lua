--- Some extended @{require} functionality.

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
local getmetatable = getmetatable
local ipairs = ipairs
local newproxy = newproxy
local pairs = pairs
local require = require
local setmetatable = setmetatable
local type = type

-- Exports --
local M = {}

-- Helper logic for DoList and GetNames
local function AuxDo (from, list, action, categories, base_prefix, names_as_keys, acc, splice)
	local category, prefix, n, res = from._category, from._prefix or base_prefix, splice and #list

	categories = categories or (category and {})
	prefix = prefix and prefix .. "." or ""

	for k, v in pairs(from) do
		if k ~= "_category" and k ~= "_prefix" then
			res, acc = action(v, prefix, acc)

			if names_as_keys then
				list[v] = res
			elseif n and type(k) == "number" and k % 1 == 0 then
				list[n + k] = res
			else
				list[k] = res
			end

			if category then
				categories[v] = category
			end
		end
	end

	return acc, categories
end

--
local function Do (name, action)
	local from, list, acc = require(name), {}
	local is_array, base_prefix, names_as_keys, categories = from._is_array, from._prefix, from._names_as_keys

	if is_array then
		local splice = categories or is_array == "splice_sequence"

		for _, v in ipairs(from) do
			acc, categories = AuxDo(v, list, action, categories, base_prefix, names_as_keys, acc, splice)
		end
	else
		acc, categories = AuxDo(from, list, action, categories, base_prefix, names_as_keys)
	end

	return list, acc, categories
end

--
local function Require (v, prefix)
	return require(prefix .. v)
end

--- Helper to require multiple modules at once.
-- @string name Name of a list module.
--
-- The result of @{require}'ing this module is assumed to be a table. If it contains a
-- true **_is\_array** key, it is treated as an array, about which more below; otherwise, it
-- is interpreted as a list of key-name pairs. If there is a **_prefix** key in the list, its
-- value is prepended to each name, i.e. `name = prefix.name`. Otherwise, keys may be
-- arbitrary, e.g. the list can be an array.
--
-- Each name is passed to @{require} and the result added to a key-module pairs list.
--
-- When treating the table as an array, each element is assumed to be a list of key-name
-- pairs, as described above. Duplicate keys lead to undefined behavior.
--
-- If the value of **_is\_array** is **"splice_sequence"**, the array length, #_t_ (of the
-- table to be returned), is cached at the beginning of each list; this amount is added to
-- any integer key in the list, to give its index in the output. The gist of this is that,
-- when the array parts are spliced together, the final result is also a proper sequence.
-- @treturn table Key-module pairs; a module is found under the same key as was its name.
-- @treturn boolean Is non-categorized list?
function M.DoList (name)
	local list, _, categories = Do(name, Require)

	return list, categories
end

--- Variant of @{DoList} that takes a list of names.
-- @ptable names Key-name pairs, e.g. as collected by @{GetNames}. The names are passed to
-- @{require}, and the results added to a name-module pairs list.
-- @string[opt=""] prefix Prefix prepended to each name.
--
-- **N.B.** If not empty, this must include the trailing dot.
-- @treturn table Name-module pairs.
function M.DoList_Names (names, prefix)
	local list = {}

	if type(prefix) == "table" then
		for _, name in pairs(names) do
			list[name] = require(prefix[name] .. name)
		end
	else
		prefix = prefix or ""

		for _, name in pairs(names) do
			list[name] = require(prefix .. name)
		end
	end

	return list
end

--
local function GroupPrefixAndReturn (name, prefix, acc)
	acc = acc or {}

	acc[name] = prefix

	return name, acc
end

--- This performs half of the work of @{DoList}, namely getting the module names, which
-- may be useful in their own right. What is said about keys in @{DoList} applies here.
-- @string name Name of a list module.
-- @treturn table Key-name pairs.
-- @treturn string If a **_prefix** key was found in the list, its value (plus a trailing
-- dot); otherwise, the empty string.
-- @treturn ?|table|nil Categorized names.
function M.GetNames (name)
	return Do(name, GroupPrefixAndReturn)
end

-- Lazy require proxies --
local ProxyToInfo = setmetatable({}, { __mode = "k" })

local function GetModule (proxy)
	local info = ProxyToInfo[proxy]

	if not info.module then
		info.module = require(info.name)
	end

	return info.module
end

local ProxyProto = newproxy(true)

local ProxyProtoMT = getmetatable(ProxyProto)

function ProxyProtoMT:__call (...)
	return GetModule(self)(...)
end

function ProxyProtoMT:__index (k)
	return GetModule(self)[k]
end

--- Helper to deal with circular module require situations. Provided module access is not
-- needed immediately (in particular, it can wait until the requiring module has loaded),
-- the lazy-required module looks like and may be treated as a normal module.
-- @string name Module name, as passed to @{require}.
-- @treturn table Module proxy, to be accessed like the module proper.
function M.Lazy (name)
	local proxy = newproxy(ProxyProto)

	ProxyToInfo[proxy] = { name = name }

	return proxy
end

-- Export the module.
return M