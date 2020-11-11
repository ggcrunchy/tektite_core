--- Some utilities for building arc-length lookup tables, built atop @{tektite_core.number.sampling}.
--
-- The samples' **x** values correspond to the arc length, _s_, and go from 0 to the full
-- length of the curve. The **y** values correspond to a "curve time", _t_, that increases
-- monotonically from 0 to 1.
--
-- For purposes of this module, an instance of type **Vector** is a value, e.g. a table,
-- that has and / or receives **number** members **x** and **y**. (**N.B.** The samples from
-- the previous paragraph are unrelated, despite the coincidence of field names.)

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

-- Adds the final "full" arc length to the LUT and makes it ready to use
local function CloseLUT (lut, s)
	lut:Add(s, 1)

	return s
end

--- Populate an arc &rarr; parameter lookup table given a function to integrate over [0, 1].
-- @array lut Lookup table, cf. @{tektite_core.number.sampling.Lookup}.
-- @callable integrator Called as `ds = integrator(func, a, b, tolerance)` to evaluate _func_
-- from _a_ to _b_ and return the corresponding arc length delta.
-- @callable func Function to integrate, e.g. an integrand supplied by @{spline_ops.polynomial.LineIntegrand}.
-- @int[opt] nsamples Number of samples to load into _lut_. If absent, a default is used.
-- @number[opt] tolerance Tolerance, useful to some integrators. If absent, a default is used.
-- @treturn number Total arc length.
function M.PopulateLUT_Integrator (lut, integrator, func, nsamples, tolerance)
	nsamples, tolerance = nsamples or 20, tolerance or 1e-3

	local a, s, dt = 0, 0, 1 / nsamples

	for _ = 1, nsamples do
		lut:Add(s, a)

		local b = a + dt
		local ds = integrator(func, a, b, tolerance)

		a, s = b, s + ds
	end

	return CloseLUT(lut, s)
end

--
--
--

-- Intermediate values, partitions --
local Left, Right = {}, {}

--- DOCMEMORE
-- Build up the LUT from a set of values
-- TODO
function M.PopulateLUT_Subdivide (lut, values, subdivide, nsamples, func, tolerance)
	nsamples = nsamples or 20

	local s, t, dt = 0, 0, 1 / nsamples

	repeat
		lut:Add(s, t)

		-- Divide the curve into parts of length u = 1 / nsamples. On the first iteration,
		-- the subdivision parameter is trivially u itself, leaving a right-hand side of
		-- length (nsamples - 1) / nsamples. On the second iteration, to maintain length u,
		-- we have 1 / nsamples = t * (nsamples - 1) / nsamples, i.e. new parameter t = 1 /
		-- (nsamples - 1). In general, on interation i, t = 1 / (nsamples - i + 1). (On the
		-- final iteration, t = 1, and the right-hand side is empty.)
		subdivide(values, Left, Right, 1 / nsamples)

		local ds = func(Left, tolerance)

		values, s, t, nsamples = Right, s + ds, t + dt, nsamples - 1
	until nsamples == 0

	return CloseLUT(lut, s)
end

--
--
--

return M