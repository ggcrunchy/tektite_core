--- This module is motivated by the situation where an array requires some additional state
-- to indicate which of its elements are in use. In the most common case, where an array's
-- negative indices would otherwise go unused, these may be commandeered for this purpose.
--
-- Obviously, this eliminates the need to track two tables. Furthermore, if the underlying
-- representation makes no difference to the user, an integer may be stored instead of an
-- explicit boolean. A slot is said to be "in use" if this integer matches some master ID.
--
-- When this technique is used, marking all elements as **not** in use is an O(1) operation;
-- to do so, one simply changes the master ID. This facilitates certain patterns that occur
-- periodically, e.g. per-frame and per-timeout actions.

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

-- Helper to kick off a new generation
local function AuxBeginGeneration (arr, key, n)
	-- Update the master ID for the current generation and overwrite one slot with an invalid
	-- ID (nil); for convenience, the index of this slot is the master ID's value. This is an
	-- alternative to clearing all slots one by one: the master ID is new, and ipso facto no
	-- slot has a match, therefore none remain in use.

	-- When a slot is marked, it gets assigned the current value of the master ID. The ID is
	-- implemented as a counter (mod n), where n is the array length. After n generations, when
	-- the counter rolls back around to the same value, the overwrite will have been applied to
	-- exactly n slots. Thus, there will not be any false positives for "in use", on account of
	-- dangling instances of the master ID in the array.

	-- That said, if this is stock Lua or LuaJIT, say, where numbers are still doubles (or in
	-- 5.3+, where integers are still 64-bit), much of this is a formality, given how incredibly
	-- long it would take to increment these to overflow.
	local gen_id = RotateIndex(arr[key] or 0, n or #arr)

	arr[key], arr[-gen_id] = gen_id
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
-- @uint[opt] n
-- @treturn function X
-- @treturn array _arr_.
function M.Wrap (arr, n)
	local gen_id = 0

	return function(what, index)
		-- Check --
		-- index: Index in array to check
		if what == "check" then
			return arr[-index] == gen_id

		-- Mark --
		-- index: Index in array to mark
		elseif what == "mark" then
			arr[-index] = gen_id

		-- Begin Generation --
		elseif what == "begin_generation" then
			gen_id = RotateIndex(gen_id, n or #arr) -- see the comment in AuxBeginGeneration()

			arr[-gen_id] = nil

		-- Get Array --
		elseif what == "get_array" then
			return arr
		end
	end, arr
end

-- Export the module.
return M