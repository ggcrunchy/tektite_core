--- Some utilities for dealing with sampled functions.

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
local floor = math.floor
local insert = table.insert
local remove = table.remove

-- Modules --
local range = require("tektite_core.number.range")

-- Cached module references --
local _Append_
local _Init_
local _Lookup_

-- Exports --
local M = {}

--
local function AuxLookup (samples, x, start)
	local n = samples.n

	assert(n > 0, "Empty sample set")

	-- Too-low x, or single sample: clamp to first sample.
	if n == 1 or x < samples[1].x then
		return 1, 0, samples[1].x > x

	-- Too-high x: clamp to last sample, but also account for x exactly at end.
	elseif x >= samples[n].x then
		return n - 1, 1, samples[n].x < x

	-- A binary search will now succeed, with x known to be within the interval.
	else
		local lo, hi, i = 1, n, range.ClampIn(start or floor(.5 * n), 1, n)

		while true do
			-- Narrow interval: just do a linear search.
			if hi - lo <= 5 then
				i = lo - 1

				repeat
					i = i + 1
				until x < samples[i + 1].x

				return i

			-- x is in an earlier interval.
			elseif x < samples[i].x then
				hi = i - 1

			-- x is in a later interval.
			elseif x >= samples[i + 1].x then
				lo = i + 1

			-- x found.
			else
				return i
			end

			-- Tighten the search and try again.
			i = floor(.5 * (lo + hi))
		end
	end
end

--- DOCME
-- @tparam Samples samples
-- @tparam Param x
-- @tparam Value y
-- @param[opt] data
-- @treturn uint INDEX
function M.AddEntry (samples, x, y, data)
	local n = assert(samples.n, "Uninitialized sampling state")

	if n == 0 or x > samples[n].x then
		_Append_(samples, x, y, data)
	else
		local entry, at

		if x < samples[1].x then
			at = 1
		else
			local bin, frac = AuxLookup(samples, x)

			-- Matches left side --
			if frac == 0 then
				entry = samples[bin]

			-- Matches right side --
			elseif bin == n - 1 and frac == 1 then
				entry = samples[bin + 1]

			-- Within interval --
			else
				at = bin + 1
			end
		end

		--
		if at then
			entry = remove(samples, n + 1) or {}

			insert(samples, at, entry)
		end

		entry.x, entry.y, entry.data = x, y, data
	end
end

--- DOCME
-- @tparam Samples samples
-- @tparam Param x
-- @tparam Value y
-- @param[opt] data
function M.Append (samples, x, y, data)
	local n = assert(samples.n, "Uninitialized sampling state")
	local entry = samples[n + 1] or {}

	assert(n == 0 or x > samples[n].x, "x <= previous sample's x")

	entry.x, entry.y, entry.data = x, y, data

	samples[n + 1], samples.n = entry, n + 1
end

--- DOCME
-- @tparam ?|table|Samples
function M.Init (samples)
	samples.n = 0

	return samples
end

--
local function FindBin (samples, x, start)
	local i, frac, oob = AuxLookup(samples, x, start)

	return i, frac, oob and (frac == 0 and "<" or ">"), samples[i], i < samples.n and samples[i + 1] -- account for one-sample case
end

--- Resolves a parameter to a p.
-- @bool add_01_wrapper Return wrapper function?
-- @array[opt] lut The underlying lookup table. If absent, a table is supplied.
--
-- In a well-formed, populated table, each element  will have **number** members **s** and
-- **t**. In the first element, both values will be 0. In the final elemnt, **t** will be
-- 1. In element _lut[i + 1]_, **s** and **t** must each be larger than the respective
-- members in element _lut[i]_.
-- @treturn function Lookup function, called as
--    t1, t2, index, u, s1, s2 = func(s, start)
-- where _s_ is the arc length to search and _start_ is an (optional) index where the search
-- may be started (when performing multiple "nearby" lookups, this might speed up search).
--
-- _t1_ and _t2_ are the t parameter bounds of the interval, _s1_ and _s2_ are the arc length
-- bounds of the same, _index_ is the interval index (e.g. for passing again as _start_), and
-- _u_ is an interpolation factor &isin; [0, 1], which may be used to approximate _t_, given
-- _t1_ and _t2_.
--
-- The arc length is clamped to [0, _s_), _s_ being the final **s** in the lookup table.
-- @treturn array _lut_.
-- @treturn ?function If _add\_01\_wrapper_ is true, this is a function that behaves like the
-- lookup function, except the input range is scaled to [0, 1].


--
local function GetFraction (x, entry, next)
	local x1 = entry.x

	return next and (x - x1) / (next.x - x1) or 0
end

--- DOCME
function M.Lookup (samples, result, x, start)
	local bin, frac, oob, entry, next = FindBin(samples, x, start)

	result.bin, result.frac = bin, frac or GetFraction(x, entry, next)
	result.out_of_bounds = oob or false

	next = next or entry -- account for one-sample case

	result.x1, result.y1, result.data1 = entry.x, entry.y, entry.data
	result.x2, result.y2, result.data2 = next.x, next.y, next.data
end

--- DOCME
function M.Lookup_01 (samples, result, x, start)
	local last = samples[samples.n]

	_Lookup_(samples, result, last and x * last.x, start) -- if samples are empty, assert will fire off
end

--- DOCME
-- @tparam Samples samples
-- @uint index
-- @tparam Param x
-- @tparam Value y
-- @param[opt] data
function M.SetEntry (samples, index, x, y, data)
	local n = assert(samples.n, "Uninitialized sampling state")

	if index == n + 1 then
		_Append_(samples, x, y, data)
	else
		local entry = assert(index <= n and samples[index], "Invalid entry")

		assert(index == 1 or x > samples[1].x, "x <= previous sample's x")
		assert(index == n or x < samples[index + 1].x, "x >= next sample's x")

		entry.x, entry.y, entry.data = x, y, data
	end
end

--- DOCME
-- @tparam Samples samples
-- @tparam Param x
-- @int[opt] start
-- @treturn ?|uint|boolean BIN
-- @treturn ?number FRAC
function M.ToBin (samples, x, start)
	local i, frac, oob, entry, next = FindBin(samples, x, start)

	if oob then
		return false
	else
		return i, frac or GetFraction(x, entry, next)
	end
end

--- DOCME
-- @tparam Samples samples
-- @tparam Param x
-- @int[opt] start
-- @treturn uint BIN
-- @treturn number FRAC
-- @treturn ?|string|boolean OOB
function M.ToBin_Clamped (samples, x, start)
	local i, frac, oob, entry, next = FindBin(samples, x, start)

	return i, frac or GetFraction(x, entry, next), oob
end

-- Cache module members.
_Append_ = M.Append
_Init_ = M.Init
_Lookup_ = M.Lookup

-- Export the module.
return M