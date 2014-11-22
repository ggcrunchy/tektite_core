--- This module is motivated by the situation where an array requires some auxiliary state
-- indicating which of its elements are in use.
--
-- In the common case that an array's negative indices are unused, those slots may be used
-- for this purpose. In such cases, one obvious corollary is that only a single table need
-- be passed around, not two.
--
-- Furthermore, if users are indifferent to the underlying representation of all this state,
-- an alternative to explicit booleans is storing some sort of identifier. Then, instead of
-- checking for an explicit **true**, the in-use predicate passes if this identifier is equal
-- to some known value.
--
-- If this method is used, marking all elements as not in use is an O(1) operation, since it
-- is equivalent to changing the identifier. This facilitates certain generational patterns,
-- e.g. per-frame data construction. (Some care is also taken to account for overflow, though
-- this is rather improbable if Lua's number type is the standard double.)

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
local function AuxBeginGeneration (arr, key, n)
	-- Update the ID for the current generation and overwrite one slot with an invalid ID,
	-- i.e. nil. This is an alternative to clearing all slots one by one: since the ID is
	-- new, no slot matches it, i.e. none remain in use. Overwriting one slot per generation
	-- avoids false positives: since the ID's are just the indices of the array (mod n), all
	-- n slots will have been wiped when the generation comes around again, and could only
	-- have been overwritten with a different ID.
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
			return arr[-index] == nonce

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