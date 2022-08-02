--- Various coordinate system utilities.

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

local function Component (vx, vy, wx, wy, normalized)
  local dot = vx * wx + vy * wy

  if normalized then
    return dot
  else
    return dot / (wx^2 + wy^2)
  end
end

--- DOCME
function M.GetComponents (lcs, x, y)
	if lcs then
    local cx, cy = lcs("global_origin")
		local dx, dy = x - cx, y - cy
    local rx, ry, ux, uy, normalized = lcs("axes")
		local s = Component(dx, dy, rx, ry, normalized)
		local t = Component(dx, dy, ux, uy, normalized)

		return s, t
	else
		return x, y
	end
end

--
--
--

--- DOCME
function M.GlobalToLocal (lcs, x, y, how)
	if lcs then
    local cx, cy = lcs("global_origin")
		local dx, dy = x - cx, y - cy
    local rx, ry, ux, uy, normalized = lcs("axes")

		x = Component(dx, dy, rx, ry, normalized)
		y = Component(dx, dy, ux, uy, normalized)

    local x0, y0 = lcs("local_origin")

    x, y = x + (x0 or 0), y + (y0 or 0)
	end

  return x, y
end

--
--
--

--- DOCME
function M.LocalToGlobal (lcs, x, y, how)
	if lcs then
    local x0, y0 = lcs("local_origin")

    x, y = x - (x0 or 0), y - (y0 or 0)

    local cx, cy = lcs("global_origin")
    local rx, ry, ux, uy = lcs("axes") -- n.b. may not be normalized

		x, y = cx + x * rx + y * ux, cy + x * ry + y * uy
  end

  return x, y
end

--
--
--

return M