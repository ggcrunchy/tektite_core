--- This module is motivated by the fact that, when an array's elements are required to be
-- non-numbers, an element may be removed&mdash;without disturbing the positions of elements
-- elsewhere in the array&mdash;by stuffing an integer into the vacated slot.
--
-- Furthermore, these same integers can be used to maintain a free list, thus providing O(1)
-- retrieval of free array slots.

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
local type = type

-- Exports --
local M = {}

--
--
--

--- DOCME
-- @array arr
-- @uint n
-- @tparam ?|uint|nil free
function M.Extend (arr, n, free)
	if n > 0 then
		local last = #arr

		for i = last + 1, last + n - 1 do
			arr[i] = i + 1
		end

		arr[last + n], free = free, last + 1
	end

	return free
end

--- DOCME
-- @array arr
-- @tparam ?|uint|nil free
-- @treturn uint X
-- @treturn uint F
function M.GetInsertIndex (arr, free)
	if free and free > 0 then
		return free, arr[free]
	else
		return #arr + 1, free or 0
	end
end

--- DOCME
-- @array arr
-- @int index
-- @treturn boolean B
function M.InUse (arr, index)
	local elem = index > 0 and arr[index] or 0 -- invalid indices coerced to number

	return type(elem) ~= "number"
end

--- DOCME
-- @array arr
-- @int index
-- @tparam ?|uint|nil free
-- @treturn uint X
function M.RemoveAt (arr, index, free)
	local n = #arr

	-- Final slot: trim the array.
	if index == n then
		n, arr[index] = n - 1

		-- If the new final slot also happens to be the head of the free list, it is clearly
		-- not in use. Trim slots one at a time until this is no longer so, possibly emptying
		-- the free list entirely.
		while n > 0 and n == free do
			free, n, arr[n] = arr[n], n - 1
		end

	-- Otherwise, the removed slot becomes the free stack top.
	elseif index >= 1 and index < n then
		arr[index], free = free, index
	end

	-- Adjust the free stack top.
	return free
end

return M