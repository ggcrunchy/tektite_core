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

-- Standard library imports --
local max = math.max
local min = math.min

-- Modules --
local index_funcs = require("tektite_core.array.index")

-- Imports --
local IndexInRange = index_funcs.IndexInRange

--- DOCME
-- @uint index
-- @uint new_start
-- @uint new_count
-- @uint new_size
-- @bool add_spot
-- @treturn uint INDEX
function M.IndexAfterInsert (index, new_start, new_count, new_size, add_spot)
	if IndexInRange(index, new_size, add_spot) then
		-- Move the spot ahead if it follows the insertion.
		if index >= new_start then
			index = index + new_count
		end

		-- If the sequence was empty, the spot will follow it. Back up if this is illegal.
		if new_size == new_count and not add_spot then
			return index - 1
		end
	end

	return index
end

--- DOCME
-- @uint index
-- @uint new_start
-- @uint new_count
-- @uint new_size
-- @bool add_spot
-- @bool can_migrate
-- @treturn uint INDEX
function M.IndexAfterRemove (index, new_start, new_count, new_size, add_spot, can_migrate)
	if IndexInRange(index, new_size, add_spot) then
		-- If a spot follows the range, back up by the remove count.
		if index >= new_start + new_count then
			return index - new_count

		-- Otherwise, handle removes within the range.
		elseif index >= new_start then
			if can_migrate then
				-- Migrate past the range.
				index = new_start

				-- If the range was at the end of the items, the spot will now be past the
				-- end. Back it up if this is illegal.
				if new_start == new_size + 1 and not add_spot then
					return max(new_start - 1, 1)
				end

			-- Clear non-migratory spots.
			else
				return 0
			end
		end
	end

	return index
end

--- DOCME
-- @uint old_start
-- @uint old_count
-- @uint new_start
-- @uint new_count
-- @treturn uint INDEX
-- @treturn uint COUNT
function M.IntervalAfterInsert (old_start, old_count, new_start, new_count)
	if old_count > 0 then
		-- If an interval follows the insertion, move ahead by the insert count.
		if new_start < old_start then
			old_start = old_start + new_count

		-- If inserting into the interval, augment it by the insert count.
		elseif new_start < old_start + old_count then
			old_count = old_count + new_count
		end
	end

	return old_start, old_count
end

--- DOCME
-- @uint old_start
-- @uint old_count
-- @uint new_start
-- @uint new_count
-- @treturn uint INDEX
-- @treturn uint COUNT
function M.IntervalAfterRemove (old_start, old_count, new_start, new_count)
	if old_count > 0 then
		-- Reduce the interval count by its overlap with the removal.
		local endr = new_start + new_count
		local endi = old_start + old_count

		if endr > old_start and new_start < endi then
			old_count = old_count - min(endr, endi) + max(new_start, old_start)
		end

		-- If the interval follows the point of removal, it must be moved back. Reduce its
		-- index by the lesser of the count and the point of removal / start distance.
		if old_start > new_start then
			old_start = max(old_start - new_count, new_start)
		end
	end

	return old_start, old_count
end

-- Export the module.
return M