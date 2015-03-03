--- An assortment of useful grid operations.

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
local floor = math.floor

-- Modules --
local var_preds = require("tektite_core.var.predicates")

-- Imports --
local IsCallable = var_preds.IsCallable

-- Cached module references --
local _CellToIndex_
local _IndexToCell_

-- Exports --
local M = {}

--- Gets the index of a grid cell when that grid is considered as a flat array.
-- @int col Column index.
-- @int row Row index.
-- @uint w Grid row width.
-- @treturn int Index.
-- @see IndexToCell
function M.CellToIndex (col, row, w)
	return (row - 1) * w + col
end

-- --
local CellToIndexLayout = {
	-- Boundary layout --
	boundary = function(col, row, w)
		return row * w + col + 1
	end,

	-- Boundary (Horizontal only) layout --
	boundary_horz = function(col, row, w)
		return (row - 1) * w + col + 1
	end,

	-- Boundary (Vertical only) layout --
	boundary_vert = function(col, row, w)
		return row * w + col
	end,

	-- weird grid (see tiling sample)
}

--- DOCME
function M.CellToIndex_Layout (col, row, w, h, layout)
	if IsCallable(layout) then
		return layout(col, row, w, h)
	else
		return (CellToIndexLayout[layout] or _CellToIndex_)(col, row, w, h)
	end
end

--- DOCME
function M.GridChecker (w, h, ncols, nrows)
	return function(x, y, xbase, ybase)
		x, y = x - (xbase or 0), y - (ybase or 0)

		local col, row = floor(x / w) + 1, floor(y / h) + 1

		if col >= 1 and col <= ncols and row >= 1 and row <= nrows then
			return true, col, row
		else
			return false
		end
	end
end

--- DOCME
function M.GridChecker_Blocks (block_w, block_h, nblock_cols, nblock_rows, cols_in_block, rows_in_block)
	local cfrac, rfrac = cols_in_block / block_w, rows_in_block / block_h

	return function(x, y, xbase, ybase)
		x, y = x - (xbase or 0), y - (ybase or 0)

		local bcol, brow = floor(x / block_w), floor(y / block_h)

		if bcol >= 0 and bcol < nblock_cols and brow >= 0 and brow < nblock_rows then
			local col = bcol * cols_in_block + floor((x - bcol * block_w) * cfrac) + 1
			local row = brow * rows_in_block + floor((y - brow * block_h) * rfrac) + 1

			return true, col, row, bcol + 1, brow + 1
		else
			return false
		end
	end
end

--- Gets the cell components of a flat array index when the array is considered as a grid.
-- @int index Array index.
-- @uint w Grid row width.
-- @treturn int Column index.
-- @treturn int Row index.
-- @see CellToIndex
function M.IndexToCell (index, w)
	local quot = floor((index - 1) / w)

	return index - quot * w, quot + 1
end

-- --
local IndexToCellLayout = {
	-- Boundary layout --
	boundary = function(index, w)
	--	index = row * w + col + 1
	end,

	-- Boundary (Horizontal only) layout --
	boundary_horz = function(index, w)
	--	index = (row - 1) * w + col + 1
	end,

	-- Boundary (Vertical only) layout --
	boundary_vert = function(index, w)
	--	index = row * w + col
	end,

	-- weird grid (see tiling sample)
}

--- DOCME
function M.IndexToCell_Layout (index, w, h, layout)
	if IsCallable(layout) then
		return layout(index, w, h)
	else
		return (IndexToCellLayout[layout] or _IndexToCell_)(index, w, h)
	end
end

-- Cache module members.
_CellToIndex_ = M.CellToIndex
_IndexToCell_ = M.IndexToCell

-- Export the module.
return M