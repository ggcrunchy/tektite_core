--- This module provides various utilities that make or operate on arrays.

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
local ipairs = ipairs
local pairs = pairs
local type = type

-- Modules --
local wipe = require("tektite_core.array.wipe")

-- Exports --
local M = {}

--
--
--

local function CheckOpts (opts)
	assert(opts == nil or type(opts) == "table", "Invalid options")

	return opts and opts.out or {}
end

--- Builds a new array with _count_ elements, each of which is a table.
--
-- When called in a bound table context, the binding is used as the destination array.
-- @uint count
-- @ptable[opt] opts TODO!
-- @treturn array Array.
function M.ArrayOfTables (count, opts)
	local dt = CheckOpts(opts)

	for i = 1, count do
		dt[i] = {}
	end

	return dt
end

--- Removes the element from index _i_ in _arr_, replacing it with the last element.
--
-- The array is assumed to be hole-free. If the element was last in the array, no replacement
-- is performed.
-- @array arr
-- @uint i
function M.Backfill (arr, i)
	local n = #arr

	arr[i] = arr[n]
	arr[n] = nil
end

--- Visits each entry of _arr_ in order, removing unwanted entries. Entries are moved
-- down to fill in gaps.
-- @array arr Array to filter.
-- @callable func Visitor function called as
--    func(entry, arg)
-- where _entry_ is the current element and _arg_ is the parameter.
--
-- If the function returns a true result, this entry is kept. As a special case, if the
-- result is 0, all entries kept thus far are removed beforehand.
-- @param arg Argument to _func_.
-- @bool clear_dead Clear trailing dead entries?
--
-- Otherwise, a **nil** is inserted after the last live entry.
-- @treturn uint Size of array after culling.
function M.Filter (arr, func, arg, clear_dead)
	local kept = 0
	local size = 0

	for i, v in ipairs(arr) do
		size = i

		-- Put keepers back into the table. If desired, empty the table first.
		local result = func(v, arg)

		if result then
			kept = (result ~= 0 and kept or 0) + 1

			arr[kept] = v
		end
	end

	-- Wipe dead entries or place a sentinel nil.
	wipe.WipeRange(arr, kept + 1, clear_dead and size or kept + 1)

	-- Report the new size.
	return kept
end

--- Collects all keys, arbitrarily ordered, into an array.
--
-- When called in a bound table context, the binding is used as the destination array.
-- @array arr Array from which to read keys.
-- @ptable[opt] opts TODO!
-- @treturn table Key array.
function M.GetKeys (arr, opts)
    local dt = CheckOpts(opts)

	for k in pairs(arr) do
		dt[#dt + 1] = k
	end

	return dt
end

local Visited = {}

local NaNKey = Visited

--- DOCME
function M.RemoveDups (arr)
	local n, wpos, had_nan = #arr, 0

	for i = 1, n do
		local cur = arr[i]
		local key = cur ~= cur and NaNKey or cur

		if not Visited[key] then
			arr[wpos + 1], wpos, Visited[key] = cur, wpos + 1, true
		end
	end

	for i = n, wpos + 1, -1 do
		arr[i] = nil
	end

	for k in pairs(Visited) do
		Visited[k] = nil
	end
end

--- Reverses array elements in-place, in the range [1, _count_].
-- @array arr Array to reverse.
-- @uint[opt=#arr] count Range to reverse.
function M.Reverse (arr, count)
	local i, j = 1, count or #arr

	while i < j do
		arr[i], arr[j] = arr[j], arr[i]

		i = i + 1
		j = j - 1
	end
end

return M