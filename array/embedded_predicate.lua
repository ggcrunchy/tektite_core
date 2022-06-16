--- Many arrays must answer some yes-or-no question about their elements, e.g. if a given
-- one is currently active.
--
-- This might be cumbersome to manage via the elements themselves. Tables often forgo any
-- negative integer indices, however, leaving them available for this sort of state. As an
-- added benefit, index -_i_ can correspond to element #_i_.
--
-- This obviously eliminates the need to track two tables. Furthermore, if the underlying
-- representation makes no difference to the user, an integer may be stored instead of an
-- explicit boolean. A "yes" then boils down to its value matching some master ID.
--
-- Importantly, by assigning a fresh master ID, all elements become "no" in one fell swoop.

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

-- Exports --
local M = {}

--
--
--

local function NextID (id, n, arr)
	if n and id >= (n == "size" and #arr or n) then
		return 1
	else
		return id + 1
	end
end

local function AuxBeginGeneration (arr, id_key, n)
	-- Update the master ID for the current generation and invalidate one slot, using the
	-- master ID as slot index for convenience. This is an alternative to clearing all slots
	-- one by one: since the master ID is new, no slots match, therefore none remain "yes".

	-- Slots are marked by assigning them the current master ID. The ID is implemented as a
	-- counter (mod n), where n is the array length.

	-- Because of the cyclical nature, the master ID would seem to not in fact always be new;
  -- false positives should be possible after n generations, for slots that had never been
  -- updated in the meantime. However, exactly n invalidations will have happened as well,
  -- so no entry will begin a generation with the new master ID.

	-- That said, where numbers are doubles, 64-bit integers, etc. this is largely a formality,
  -- given how impractically long it would take to increment them to overflow.
	local gen_id = NextID(arr[id_key] or 0, n, arr)

	arr[id_key], arr[-gen_id] = gen_id
end

--- DOCME
-- @array arr
-- @ptable[opts] opts
function M.BeginGeneration_ID (arr, opts)
	AuxBeginGeneration(arr, (opts and opts.id) or "id", opts and opts.n)
end

--
--
--

--- DOCME
-- @array arr
-- @uint[opt=#arr] n
function M.BeginGeneration_Zero (arr, n)
	AuxBeginGeneration(arr, 0, n)
end

--
--
--

--- DOCME
-- @array arr
-- @uint index
-- @param[opt="id"] id
-- @treturn boolean B
function M.CheckSlot_ID (arr, index, id)
	return arr[-index] == arr[id or "id"]
end

--
--
--

--- DOCME
-- @array arr
-- @uint index
-- @treturn boolean B
function M.CheckSlot_Zero (arr, index)
	return arr[-index] == arr[0]
end

--
--
--

--- DOCME
-- @array arr
-- @uint index
function M.ClearSlot (arr, index)
	arr[-index] = nil
end

--
--
--

--- DOCME
-- @array arr
-- @uint index
-- @param[opt="id"] id
function M.MarkSlot_ID (arr, index, id)
	arr[-index] = arr[id or "id"]
end

--
--
--

--- DOCME
-- @array arr
-- @uint index
function M.MarkSlot_Zero (arr, index)
	arr[-index] = arr[0]
end

--
--
--

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

--
--
--

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

--
--
--

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
		local mark_value = Commands[what]

		if mark_value ~= nil then
			local is_marked = arr[-index] == gen_id

			if what ~= "check" then
				if what == "set" then
					mark_value = arg
				end

				arr[-index] = mark_value and gen_id or nil

				return is_marked == not mark_value
			else
				return is_marked
			end

		-- Begin Generation --
		elseif what == "begin_generation" then
			gen_id = NextID(gen_id, n, arr) -- cf. AuxBeginGeneration()

			arr[-gen_id] = nil

		-- Get Info --
		elseif what == "get_info" then
			return arr, gen_id
		end
	end, arr
end

--
--
--

return M