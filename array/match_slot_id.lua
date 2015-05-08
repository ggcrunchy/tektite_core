--- This module is motivated by the situation where an array must be ready to answer some
-- yes-or-no question about each of its elements. For example: is element X in use?
--
-- It will usually be difficult to maintain the necessary state in the elements themselves.
-- It is quite common in the case of arrays, however, that the table's negative integer
-- indices go unused. When this is so, these may be commandeered to store the state; this
-- conveniently allows a boolean at index -_i_ to describe an element at index _i_.
--
-- Obviously, this eliminates the need to track two tables. Furthermore, if the underlying
-- representation makes no difference to the user, an integer may be stored instead of an
-- explicit boolean. The element then has a "yes" if this integer matches some master ID.
--
-- When this technique is used, setting all elements to "no" is an O(1) operation; one simply
-- changes the master ID. This is useful in various periodic patterns, such as per-frame and
-- per-timeout actions.

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

-- Modules --
local index_funcs = require("tektite_core.array.index")

-- Imports --
local RotateIndex = index_funcs.RotateIndex

-- Exports --
local M = {}

--
local function NextID (id, n, arr)
	if n then
		return RotateIndex(id, n == "size" and #arr or n)
	else
		return id + 1
	end
end

-- Helper to kick off a new generation
local function AuxBeginGeneration (arr, key, n)
	-- Update the master ID for the current generation and overwrite one slot with an invalid
	-- ID (nil); for convenience, the index of this slot is the master ID's value. This is an
	-- alternative to clearing all slots one by one: the master ID is new, and ipso facto no
	-- slot has a match, therefore none remain "yes".

	-- When a slot is marked, it gets assigned the current value of the master ID. The ID is
	-- implemented as a counter (mod n), where n is the array length. After n generations,
	-- when the counter rolls back around to the same value, the overwrite will have been
	-- applied to exactly n slots. Thus, there will not be any false "yes" positives on
	-- account of dangling instances of the master ID in the array.

	-- That said, if this is stock Lua or LuaJIT, say, where numbers are still doubles (or in
	-- 5.3+, where integers are still 64-bit), much of this is a formality, given how very
	-- long it would take to increment these to overflow.
	local gen_id = NextID(arr[key] or 0, n, arr)

	arr[key], arr[-(gen_id + 1)] = gen_id
end

--- DOCME
-- @array arr
-- @ptable[opts] opts
function M.BeginGeneration_ID (arr, opts)
	AuxBeginGeneration(arr, (opts and opts.id) or "id", opts and opts.n)
end

--- DOCME
-- @array arr
-- @uint[opt=#arr] n
function M.BeginGeneration_Zero (arr, n)
	AuxBeginGeneration(arr, 0, n)
end

--- DOCME
-- @array arr
-- @uint index
-- @param[opt="id"] id
-- @treturn boolean B
function M.CheckSlot_ID (arr, index, id)
	return arr[-index] == arr[id or "id"]
end

--- DOCME
-- @array arr
-- @uint index
-- @treturn boolean B
function M.CheckSlot_Zero (arr, index)
	return arr[-index] == arr[0]
end

--- DOCME
-- @array arr
-- @uint index
function M.ClearSlot (arr, index)
	arr[-index] = nil
end

--- DOCME
-- @array arr
-- @uint index
-- @param[opt="id"] id
function M.MarkSlot_ID (arr, index, id)
	arr[-index] = arr[id or "id"]
end

--- DOCME
-- @array arr
-- @uint index
function M.MarkSlot_Zero (arr, index)
	arr[-index] = arr[0]
end

--- DOCME
-- @array arr
-- @uint index
-- @bool set
-- @param[opt="id"] id
function M.SetSlot_ID (arr, index, set, id)
	local value

	if set then
		value = arr[id or "id"]
	end

	arr[-index] = value
end

--- DOCME
-- @array arr
-- @uint index
-- @bool set
function M.SetSlot_Zero (arr, index, set)
	local value

	if set then
		value = arr[0]
	end

	arr[-index] = value
end

-- --
local Commands = { check = true, clear = false, mark = true, set = true }

--- DOCME
-- @array arr
-- @uint[opt] n
-- @treturn function X
-- @treturn array _arr_.
function M.Wrap (arr, n)
	local gen_id = 0

	return function(what, index, arg)
		-- Check / Clear / Mark / Set --
		-- index: Index in array to check / clear / mark / set
		-- Return: Was the index marked ("check")? Or did it change (otherwise)?
		local how = Commands[what]

		if how ~= nil then
			local marked = arr[-index] == gen_id

			if what ~= "check" then
				if what == "set" then
					how = arg
				end

				arr[-index] = how and gen_id or nil

				return marked == not how
			else
				return marked
			end

		-- Begin Generation --
		elseif what == "begin_generation" then
			gen_id = NextID(gen_id, n, arr) -- see the comment in AuxBeginGeneration()

			arr[-(gen_id + 1)] = nil

		-- Get Array --
		elseif what == "get_array" then
			return arr
		end
	end, arr
end

-- Export the module.
return M