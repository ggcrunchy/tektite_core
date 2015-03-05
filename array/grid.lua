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
		return row * (w + 2) + col + 1
	end,

	-- Boundary (Horizontal only) layout --
	boundary_horz = function(col, row, w)
		return (row - 1) * (w + 2) + col + 1
	end,

	-- Boundary (Vertical only) layout --
	boundary_vert = function(col, row, w)
		return row * w + col
	end,

	-- weird grid (see tiling sample)... maybe two-tiered grid? (or blocks, as used below) (or grid of grids)
	--[[
		-- "Logical" grid dimensions (i.e. before being broken down into subgrids)... --
		local NCols_Log, NRows_Log = 15, 10 <- w, h (only need w)

		-- ... and "true" dimensions --
		local NCols, NRows = NCols_Log * 4, NRows_Log * 4 <- not needed

		-- Distance between vertically adjacent grid cells --
		local Pitch = NCols_Log * 4 <- need this 4

		local qc, rc = divide.DivRem(col - 1, 4) <- another 4 (same as pitch?)
		local qr, rr = divide.DivRem(row - 1, 4) <- and another

		return 4 * (qr * Pitch + qc * 4 + rr) + rc + 1 <- which 4 is this?
	]]

	-- Hilbert?
}

--- DOCME
function M.CellToIndex_Layout (col, row, w, h, layout)
	if not IsCallable(layout) then
		layout = CellToIndexLayout[layout] or _CellToIndex_
	end

	return layout(col, row, w, h)
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

--
local function ToCell (dw, dc, dr)
	return function(index, w)
		local col, row = _IndexToCell_(index, w + dw)

		return col + dc, row + dr
	end
end

-- --
local IndexToCellLayout = {
	-- Boundary layout --
	boundary = ToCell(2, -1, -1),

	-- Boundary (Horizontal only) layout --
	boundary_horz = ToCell(2, -1, 0),

	-- Boundary (Vertical only) layout --
	boundary_vert = ToCell(0, 0, -1),

	-- weird grid (see tiling sample)
}

--- DOCME
function M.IndexToCell_Layout (index, w, h, layout)
	if not IsCallable(layout) then
		layout = IndexToCellLayout[layout] or _IndexToCell_
	end

	return layout(index, w, h)
end

-- Cache module members.
_CellToIndex_ = M.CellToIndex
_IndexToCell_ = M.IndexToCell

--[=[
-- --
local DirtGroup

-- --
local Nx, Ny

--- DOCME
function M.GetDims ()
	return Nx, Ny
end

--- DOCME
function M.Init (group, nx, ny)
	DirtGroup, Nx, Ny = group, nx, ny
end

-- --
local StencilMethods = {}

StencilMethods.__index = StencilMethods

--
local function ApplyStencil (stencil, midc, midr)
	local center = (midr - 1) * Nx + midc

	for i = 1, #stencil, 3 do
		local col, row = midc + stencil[i + 1], midr + stencil[i + 2]

		if col >= 1 and col <= Nx and row >= 1 and row <= Ny then
			local cell = core.GetCell()

			cell.index, cell.col, cell.row = center + stencil[i], col, row
		end
	end
end

-- --
local TreeY = gameplay_config.TreeY

--
local function GetColRow (stencil, x, y)
	y = y - TreeY

	if stencil.m_use_screen_space then
		y = y - DirtGroup.y
	end

	return floor(.25 * x) + 1, floor(.25 * y) + 1
end

-- --
local StartStencil = { name = "start_stencil" }

--
local function Prep ()
	Runtime:dispatchEvent(StartStencil)
end

--
local function ProcessDirtyList (stencil)
	local mode, arg = stencil.m_mode

	if mode == "non_dirt" then
		mode, arg = "fill", true
	end

	core.VisitCells(mode, arg)
	core.UpdateBlocks()
end

--- AAA
function StencilMethods:Do (x, y)
	Prep()

	local col, row = GetColRow(self, x, y)

	ApplyStencil(self, col, row)
	ProcessDirtyList(self)

	return col, row
end

--- DDD
function StencilMethods:DoList (list)
	Prep()

	for i = 1, #list, 2 do
		local col, row = list[i], list[i + 1]

		if col >= 1 and col <= Nx and row >= 1 and row <= Ny then
			local cell = core.GetCell()

			cell.index, cell.col, cell.row = (row - 1) * Nx + col, col, row
		end
	end

	ProcessDirtyList(self)
end

--- BBB
function StencilMethods:FromTo (x, y, col, row)
	Prep()

	local fcol, frow = GetColRow(self, x, y)

	if fcol ~= col or frow ~= row then
		for c, r in grid_iterators.LineIter(fcol, frow, col, row) do
			ApplyStencil(self, c, r)
		end
-- TODO: optimize for sweep? (two lines and edge table, or hemispheres and line with edge tables)
	else
		ApplyStencil(self, col, row)
	end

	ProcessDirtyList(self)

	return fcol, frow
end

--- DOCME
function StencilMethods:GetCoordinates (x, y)
	local col, row = GetColRow(self, x, y)

	return col, row, col >= 1 and col <= Nx and row >= 1 and row <= Ny
end

--- DOCME
function StencilMethods:SetVisitorFunc (func)
	self.m_mode = func or "wipe"
end

--- DOCME
function StencilMethods:UseFillMode ()
	self.m_mode = "fill"
end

--- DOCME
function StencilMethods:UseForNonDirt ()
	self.m_mode = "non_dirt"
end

--- DOCME
function StencilMethods:UseScreenSpace (use)
	self.m_use_screen_space = not not use
end

--- DOCME
function StencilMethods:UseWipeMode ()
	self.m_mode = "wipe"
end

--- EEE
function M.NewStencil (dim)
	local stencil = { m_mode = "wipe" }

	for y = -dim, dim do
		local row, w = y * Nx, dim - abs(y)

		for x = -w, w do
			stencil[#stencil + 1] = row + x
			stencil[#stencil + 1] = x
			stencil[#stencil + 1] = y
		end
	end

	return setmetatable(stencil, StencilMethods)
end
--]=]

-- Export the module.
return M