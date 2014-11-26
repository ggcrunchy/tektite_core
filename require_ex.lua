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
local ipairs = ipairs
local pairs = pairs
local require = require
local setmetatable = setmetatable

-- Exports --
local M = {}

-- Helper logic for DoList
local function AuxDoList (from, list)
	local prefix = from._prefix

	prefix = prefix and prefix .. "." or ""

	for k, v in pairs(from) do
		if k ~= "_prefix" then
			list[k] = require(prefix .. v)
		end
	end
end

--- Helper to require multiple modules at once.
-- @string name Name of a list module.
--
-- The result of @{require}'ing this module is assumed to be a table. If it contains an
-- **_is\_array** key, it is treated as an array, about which more below; otherwise, it is
-- interpreted as a list of key-name pairs. If there is a **_prefix** key in the list, its
-- value is prepended to each name, i.e. `name = prefix.name`. Otherwise, keys may be
-- arbitrary, e.g. the list can be an array.
--
-- Each name is passed to @{require} and the result added to a key-module pairs list.
--
-- When treating the table as an array, each element is assumed to be a list of key-name
-- pairs, as described above. Duplicate keys lead to undefined behavior.
-- @treturn table Key-module pairs; a module is found under the same key as was its name.
function M.DoList (name)
	local from, list = require(name), {}

	if from._is_array ~= nil then
		for _, v in ipairs(from) do
			AuxDoList(v, list)
		end
	else
		AuxDoList(from, list)
	end

	return list
end

--- Variant of @{DoList} that takes a list of names.
-- @ptable names Key-name pairs, e.g. as collected by @{GetNames}. The names are passed to
-- @{require}, and the results added to a name-module pairs list.
-- @string[opt=""] prefix Prefix prepended to each name.
--
-- **N.B.** If not empty, this must include the trailing dot.
-- @treturn table Name-module pairs.
function M.DoList_Names (names, prefix)
	prefix = prefix or ""

	local list = {}

	for _, name in pairs(names) do
		list[name] = require(prefix .. name)
	end

	return list
end

--- This performs half of the work of @{DoList}, namely getting the module names, which
-- may be useful in their own right. What is said about keys in @{DoList} applies here.
-- @string name Name of a list module.
-- @treturn table Key-name pairs.
-- @treturn string If a **_prefix** key was found in the list, its value (plus a trailing
-- dot); otherwise, the empty string.
function M.GetNames (name)
	local from = require(name)
	local prefix, list = from._prefix, {}

	for k, v in pairs(from) do
		if k ~= "_prefix" then
			list[k] = v
		end
	end

	return list, prefix and prefix .. "." or ""
end

--- Helper to deal with circular module require situations. Provided module access is not
-- needed immediately (in particular, it can wait until the requiring module has loaded),
-- the lazy-required module looks like and may be treated as a normal module.
-- @string name Module name, as passed to @{require}.
-- @treturn table Module proxy, to be accessed like the module proper.
function M.Lazy (name)
	local mod

	return setmetatable({}, {
		__index = function(_, k)
			mod = mod or require(name)

			return mod[k]
		end
	})
end

-- Export the module.
return M