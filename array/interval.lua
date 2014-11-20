--- DOCME

-- The idea here is that you can just mark in-use array slots (stored in the negative keys)
-- with an ID, which is updated after every "frame". As opposed to using booleans, you don't
-- need to wipe the whole array, only update the ID. (Although probably not a concern with
-- doubles, you can even ensure you don't have false positives by gradually overwriting
-- one or more entries after each frame.)

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

--[[
--- This class provides some apparatus for dealing with sequential data, where elements
-- may be inserted and removed often and observors dependent on the positioning must be
-- alerted.<br><br>
-- Class.
module Sequence
]]

-- Standard library imports --
local assert = assert
local ipairs = ipairs
local pairs = pairs

-- Imports --
local IsCallable = var_preds.IsCallable
local IsCountable = var_preds.IsCountable
local IndexInRange = numeric_ops.IndexInRange
local New = class.New
local RangeOverlap = numeric_ops.RangeOverlap
local Weak = table_ops.Weak

-- Unique member keys --
local _insert = {}
local _object = {}
local _remove = {}
local _size = {}

-- Sequence state --
local Groups = ...

for _, v in ipairs(Groups) do
	v.elements = table_ops.SubTablesOnDemand()
end

-- Sequence class definition --
class.Define("Sequence", function(Sequence)
	-- Element update helper
	local function UpdateElements (S, op_key, index, count, new_size)
		for _, group in ipairs(Groups) do
			local op = group[op_key]

			for element in pairs(group.elements[S]) do
				op(element, index, count, new_size)
			end
		end
	end

	-- Inserts new items
	-- index: Insertion index
	-- count: Count of items to add
	-- ...: Insertion arguments
	--------------------------------
	function Sequence:Insert (index, count, ...)
		assert(self:IsItemValid(index, true) and count > 0)

		UpdateElements(self, "Insert", index, count, #self + count)

		self[_insert](index, count, ...)
	end

	-- index: Index of item in sequence
	-- is_addable: If true, the end of the sequence is valid
	-- Returns: If true, the item is valid
	---------------------------------------------------------
	function Sequence:IsItemValid (index, is_addable)
		return IndexInRange(index, #self, is_addable)
	end

	-- Returns: Item count
	-----------------------
	function Sequence:__len ()
		local size = self[_size]

		if size then
			return size(self[_object]) or 0
		else
			return #self[_object]
		end
	end

	-- Removes a series of items
	-- index: Removal index
	-- count: Count of items to remove
	-- ...: Removal arguments
	-- Returns: Count of items removed
	-----------------------------------
	function Sequence:Remove (index, count, ...)
		local cur_size = #self

		count = RangeOverlap(index, count, cur_size)

		if count > 0 then
			UpdateElements(self, "Remove", index, count, cur_size - count)

			self[_remove](index, count, ...)
		end

		return count
	end

	--- Class constructor.
	-- @param object Sequenced object.
	-- @param insert Insert routine.
	-- @param remove Remove routine.
	-- @param size Optional size routine.
	function Sequence:__cons (object, insert, remove, size)
		assert(IsCallable(size) or (size == nil and IsCountable(object)), "Invalid sequence parameters")

		-- Sequenced object --
		self[_object] = object

		-- Sequence operations --
		self[_insert] = insert
		self[_remove] = remove
		self[_size] = size
	end
end)

--[[
--- This class is used to track an interval on a <a href="Sequence.html">Sequence</a>,
-- which can grow and shrink in response to element insertions and removals.<br><br>
-- Class.
module Interval
]]

-- Standard library imports --
local assert = assert
local max = math.max
local min = math.min

-- Imports --
local RangeOverlap = numeric_ops.RangeOverlap
local IsType = class.IsType

-- Unique member keys --
local _count = {}
local _index = {}
local _start = {}
local _size = {}

-- Export table --
local Export = {}

-- Interval class definition --
class.Define("Interval", function(Interval)
	--- Clears the selection.
	function Interval:Clear ()
		self[_count] = 0
	end

	--- Gets the starting position of the interval.
	-- @return Current start index, or <b>nil</b> if empty.
	function Interval:GetStart ()
		return self[_count] > 0 and self[_start] or nil
	end

	--- Metamethod.
	-- @return Size of selected interval.
	function Interval:__len ()
		return self[_count]
	end

	--- Selects a range. The selection count is clamped against the sequence size.
	-- @param start Current index of start position.
	-- @param count Current size of range to select.
	function Interval:Set (start, count)
		self[_start] = start
		self[_count] = RangeOverlap(start, count, self[_size])
	end

	--- Class constructor.
	-- @param sequence Reference to owner sequence.
	function Interval:__cons (sequence)
		assert(IsType(sequence, "Sequence"), "Invalid sequence")

		-- Current sequence size --
		self[_size] = #sequence

		-- Selection count --
		self[_count] = 0

		-- Register the interval --
		Export.elements[sequence][self] = true
	end
end)

-- Updates the interval in response to a sequence insert
function Export.Insert (I, index, count, new_size)
	if I[_count] > 0 then
		-- If an interval follows the insertion, move ahead by the insert count.
		if index < I[_start] then
			I[_start] = I[_start] + count

		-- If inserting into the interval, augment it by the insert count.
		elseif index < I[_start] + I[_count] then
			I[_count] = I[_count] + count
		end
	end

	I[_size] = new_size
end

-- Updates the interval in response to a sequence remove
function Export.Remove (I, index, count, new_size)
	if I[_count] > 0 then
		-- Reduce the interval count by its overlap with the removal.
		local endr = index + count
		local endi = I[_start] + I[_count]

		if endr > I[_start] and index < endi then
			I[_count] = I[_count] - min(endr, endi) + max(index, I[_start])
		end

		-- If the interval follows the point of removal, it must be moved back. Reduce its
		-- index by the lesser of the count and the point of removal / start distance.
		if I[_start] > index then
			I[_start] = max(I[_start] - count, index)
		end
	end

	I[_size] = new_size
end

-- Export interval to sequence.
table.insert(..., Export)

--[[
--- A spot is used to track a position on or immediately following a <a href="Sequence.html">
-- Sequence</a>, even as its index adapts to element insertions and removals.<br><br>
-- Class.
module Spot
]]

-- Standard library imports --
local assert = assert
local max = math.max

-- Library imports --
local IndexInRange = numeric_ops.IndexInRange
local IsType = class.IsType

-- Unique member keys --
local _can_migrate = {}
local _index = {}
local _is_add_spot = {}
local _size = {}

-- Export table --
local Export = {}

-- Returns: If true, spot is valid
local function IsValid (S, index)
	return IndexInRange(index or S[_index], S[_size], S[_is_add_spot])
end

-- Spot class definition --
class.Define("Spot", function(Spot)
	--- Invalidates the spot.
	function Spot:Clear ()
		self[_index] = 0
	end

	--- Gets the current index of the position watched by the spot.
	-- @return Index, or <b>nil</b> if the spot is invalid.
	-- @see Spot:Set
	function Spot:GetIndex ()
		if IsValid(self) then
			return self[_index]
		end
	end

	--- Assigns the spot a position in the sequence to watch.
	-- @param index Current position index.
	-- @see Spot:GetIndex
	function Spot:Set (index)
		assert(IsValid(self, index), "Invalid index")

		self[_index] = index
	end

	--- Class constructor.
	-- @param sequence Reference to owner sequence.
	-- @param is_add_spot If true, this spot can occupy the position immediately after the
	-- sequence.
	-- @param can_migrate If true, this spot can migrate if the part of the sequence it
	-- monitors is removed.
	function Spot:__cons (sequence, is_add_spot, can_migrate)
		assert(IsType(sequence, "Sequence"), "Invalid sequence")

		-- Current sequence size --
		self[_size] = #sequence

		-- Currently referenced sequence element --
		self[_index] = 1

		-- Flags --
		self[_is_add_spot] = not not is_add_spot
		self[_can_migrate] = not not can_migrate

		-- Register the spot --
		Export.elements[sequence][self] = true
	end
end)

-- Updates the spot in response to a sequence insert
function Export.Insert (S, index, count, new_size)
	if IsValid(S) then
		-- Move the spot ahead if it follows the insertion.
		if S[_index] >= index then
			S[_index] = S[_index] + count
		end

		-- If the sequence was empty, the spot will follow it. Back up if this is illegal.
		if new_size == count and not S[_is_add_spot] then
			S[_index] = S[_index] - 1
		end
	end

	S[_size] = new_size
end

-- Updates the spot in response to a sequence remove
function Export.Remove (S, index, count, new_size)
	if IsValid(S) then
		-- If a spot follows the range, back up by the remove count.
		if S[_index] >= index + count then
			S[_index] = S[_index] - count

		-- Otherwise, handle removes within the range.
		elseif S[_index] >= index then
			if S[_can_migrate] then
				-- Migrate past the range.
				S[_index] = index

				-- If the range was at the end of the items, the spot will now be past the
				-- end. Back it up if this is illegal.
				if index == new_size + 1 and not S[_is_add_spot] then
					S[_index] = max(index - 1, 1)
				end

			-- Clear non-migratory spots.
			else
				S:Clear()
			end
		end
	end

	S[_size] = new_size
end

-- Export spot to sequence.
table.insert(..., Export)

-- Export the module.
return M