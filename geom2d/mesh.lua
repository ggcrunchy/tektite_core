--- Mesh utilities.

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
local abs = math.abs
local ipairs = ipairs
local pairs = pairs
local remove = table.remove
local sort = table.sort

-- Cached module references --
local _GetAdjacentTriangle_Tri_
local _GetIndices_
local _GetVertexPos_

-- Exports --
local M = {}

--
--
--

--- DOCME
function M.AddVertex (mesh, x, y)
	local pos = mesh.pos
	local index = #pos + 1

	pos[index], pos[index + 1] = x, y

	return index
end

--
local function Dot (x1, y1, x2, y2)
	return x1 * y1 + x2 * y2
end

--
local function LineComp (x1, y1, x2, y2, x, y)
	local ex, ey = x2 - x1, y2 - y1

	return Dot(ex, ey, x - x1, y - y1) / (ex^2 + ey^2)
end

-- --
local Walk = {}

--
local function TryPush (tri, id, n)
	if tri.id ~= id then
		n, tri.id = n + 1, id

		Walk[n] = tri
	end

	return n
end

-- --
local Neighbors = {}

local Mesh = {}

do
	-- vertex index = 1 through N
	-- vertex index list = empty or { vertex index; vertex index list VList }
	-- edge list = empty or { edge e; edge list EList }
	-- triangle list = empty or { tri t; triangle list TList }
	-- vertex = { vertex index; edge list Elist; triangle list TList } -> { uint, {edge...}, {tri...} }
	-- edge = { vertex index v[2]; triangle list TList } -> { uint1, uint2, tri1[, tri2] }
	-- tri = { vertex index list VList } -> { uint1, uint2, uint3 }

local function AuxRemove (vertices, index, elem)
	for i = 1, index do -- n.b. count and index coincide
		local list = vertices[elem[i]][index] 
		local n = #list

		for j = 1, n do
			if list[j] == elem then
				list[j] = list[n]
				list[n] = nil

				break
			end
		end
	end
end

local function RemoveTriangle (vertices, tri)
	AuxRemove(vertices, 3, tri)
end

local function RemoveEdge (vertices, edge)
	AuxRemove(vertices, 2, edge)

	for i = 3, edge[4] and 4 or 3 do
		RemoveTriangle(vertices, edge[i])
	end
end
	-- add vertex:
		-- new index
		-- locate triangle, if any
			-- if on edge
				-- ???
			-- if in tri
				-- split up!
			-- else
				-- err...

		-- remove vertex:
			-- try to merge neighbors

	-- Adapted from "Geometric Tools for Computer Graphics"

	local TriStack = {}

	local function FindEdgeFromPair (vertices, i1, i2)
		local vertex, isum = vertices[i1], i1 + i2

		for _, edge in ipairs(vertex[2]) do
			local e1 = edge[1]

			if isum == e1 + edge[2] and (i1 == e1 or i2 == e1) then
				return edge
			end
		end
	end

	local function VisitEdgesInStack (mesh, func, get, acc)
		local vertices = mesh.vertices

		repeat
			local tri = get(acc)
			local i1, i2, i3 = tri[1], tri[2], tri[3]

			func(FindEdgeFromPair(vertices, i1, i2), tri)
			func(FindEdgeFromPair(vertices, i2, i3), tri)
			func(FindEdgeFromPair(vertices, i3, i1), tri)
		until #TriStack == 0
	end

	local GenerationID = 0

	local function IsUnvisited (tri)
		return tri and tri.gen_id ~= GenerationID
	end

	local function PushTriangle (tri)
		TriStack[#TriStack + 1], tri.gen_id = tri, GenerationID
	end

	local function PushAdjacentTriangles (edge)
		for i = 3, 4 do
			local tri = edge[i]

			if IsUnvisited(tri) then
				PushTriangle(tri)
			end
		end
	end

	local function GetUnvisitedTriangle (mesh)
		local tris = mesh.triangles

		for i = mesh.index + 1, #tris do
			local tri = tris[i]

			if IsUnvisited(tri) then
				return tri, i
			end
		end
	end

	local function PushUnvisitedTriangle (mesh)
		local tri, index = GetUnvisitedTriangle(mesh)

		if tri then
			PushTriangle(tri)

			mesh.index = index

			return true
		end
	end

	local function PopTriangle ()
		return remove(TriStack)
	end

	local function PopAndAccumulateTriangle (acc)
		local tri = PopTriangle()

		acc[#acc+ 1] = tri

		return tri
	end

	local function Prepare (mesh)
		mesh.index, GenerationID = 0, GenerationID + 1
	end

	--- DOCME
	function Mesh:GetComponents ()
		local list, n = {}, 0

		Prepare(self)

		while PushUnvisitedTriangle(self) do
			list[n + 1], n = {}, n + 1

			VisitEdgesInStack(self, PushAdjacentTriangles, PopAndAccumulateTriangle, list[n])
		end

		return list
	end

	--- DOCME
	function Mesh:IsConnected ()
		Prepare(self)
		PushUnvisitedTriangle(self)
		VisitEdgesInStack(self, PushAdjacentTriangles, PopTriangle)

		return not GetUnvisitedTriangle(self)
	end

	local function ContainsOrderedEdge (tri, vi1, vi2)
		local i1, i2, i3 = tri[1], tri[2], tri[3]

		return (i1 == vi1 and i2 == vi2) or (i2 == vi1 and i3 == vi2) or (i3 == vi1 and i1 == vi2)
	end

	local function ReorderVertices (tri)
		tri[1], tri[2], tri[3] = tri[3], tri[2], tri[1]
	end

	local function TriangleAdjacentToEdge (tri, edge)
		return edge[edge[4] == tri and 3 or 4]
	end

	local function AuxMakeConsistent (edge, tri)
		local adjacent = TriangleAdjacentToEdge(tri, edge)

		if IsUnvisited(adjacent) then
			if ContainsOrderedEdge(adjacent, edge[1], edge[2]) then
				ReorderVertices(adjacent)
			end

			PushTriangle(adjacent)
		end
	end

	--- DOCME
	function Mesh:MakeConsistent ()
		Prepare(self)
		PushUnvisitedTriangle(self)
		VisitEdgesInStack(self, AuxMakeConsistent, PopTriangle)
	end
end

--
local function AddNeighbor (mesh, tri, index, cost)
	local neighbor = _GetAdjacentTriangle_Tri_(mesh, tri, index)

	neighbor.cost = cost

	Neighbors[#Neighbors + 1] = neighbor
end

--
local function CostComp (t1, t2)
	return t1.cost < t2.cost
end

--
local function GetVert (verts, i)
	local vert = verts[i] or {}

	verts[i] = vert

	return vert
end

--
local function GetEdge (verts, i1, i2)
	local v1, v2 = GetVert(verts, i1), GetVert(verts, i2)
	local edge = v1[i2] or {}

	v1[i2], v2[i1] = edge, edge

	return edge
end

--
local function TestTriangle (mesh, tri, x, y, id, n)
	local i1, i2, i3 = _GetIndices_(tri)
	local x1, y1 = _GetVertexPos_(mesh, tri, i1)
	local x2, y2 = _GetVertexPos_(mesh, tri, i2)
	local x3, y3 = _GetVertexPos_(mesh, tri, i3)

	--
	local s = LineComp(x1, y1, x2, y2, x, y)
	local t = LineComp(x1, y1, x3, y3, x, y)
	local u, cont = 1 - (s + t)

	--
	if s >= 0 and t >= 0 and u >= 0 then
		--
		if s < 1e-3 then
			return GetEdge(mesh.verts, i1, i3), "edge"
		elseif t < 1e-3 then
			return GetEdge(mesh.verts, i1, i2), "edge"
		elseif u < 1e-3 then
			return GetEdge(mesh.verts, i2, i3), "edge"

		--
		else
			return tri, "tri"
		end

	--
	else
		n = n - 1

		if s < 0 then
			AddNeighbor(mesh, tri, 2, s)
		end

		if t < 0 then
			AddNeighbor(mesh, tri, 3, t)
		end

		if u < 0 then
			AddNeighbor(mesh, tri, 1, u)
		end

		if #Neighbors > 0 then
			sort(Neighbors, CostComp)

			for i = 1, #Neighbors do
				n, Neighbors[i] = TryPush(Neighbors[i], id, n)
			end
		end
	end

	return n, cont
end

-- --
local WalkID = 0

--- DOCME
function M.Container (mesh, x, y)
	local tri0 = mesh[1]

	if tri0 then
		WalkID = WalkID + 1

		local n, cont = TryPush(tri0, WalkID, 0)

		while n > 0 and not cont do
			local tri = Walk[n]

			n, cont = TestTriangle(mesh, tri, x, y, WalkID, n)
		end

		--
		for i = #Walk, 1, -1 do
			Walk[i] = nil
		end
	end

	--
	return cont
end

--- DOCME
function M.GetAdjacentTriangle_Edge (edge, i)
	return edge[i]
end

--
local function NextIndex (tri, i)
	return tri[i + 1] or tri[1]
end

--- DOCME
function M.GetAdjacentTriangle_Tri (mesh, tri, i)
	local vert, j = mesh.verts[tri[i]], NextIndex(tri, i)
	local edge = vert[j]

	if edge[1] == tri then
		return edge[2]
	else
		return edge[1]
	end
end

--- DOCME
function M.GetEdge (mesh, tri, i)
	local vert, j = mesh.verts[tri[i]], NextIndex(tri, i)

	return vert[j]
end

--- DOCME
function M.GetIndex (tri, index)
	return NextIndex(tri, index - 1)
end

--- DOCME
function M.GetIndices (tri)
	return tri[1], tri[2], tri[3]
end

--- DOCME
function M.GetVertexPos (mesh, tri, index)
	local pos = mesh.pos

	return pos[index], pos[index + 1]
end

--- DOCME
function M.InsertTriangle (mesh, i1, i2, i3)
	local tri = { i1, i2, i3 }
	local edges, verts, ti = mesh.edges, mesh.verts, tri.indices

	for i = 1, 3 do
		local edge = GetEdge(verts, tri[i], NextIndex(tri, i))

		edge[#edge + 1] = tri
	end

	mesh[#mesh + 1] = tri

	return tri
end

--- DOCME
function M.NewMesh ()
	return { pos = {}, verts = {} }
end

--
local function FindAndRemove (t, elem)
	for i = 1, #t do
		if t[i] == elem then
			return remove(t, i)
		end
	end
end

--- DOCME
function M.RemoveTriangle (mesh, tri)
	--
	if FindAndRemove(mesh, tri) then
		local verts = mesh.verts

		for j = 1, 3 do
			local i1, ne = tri[j], 0
			local vert = verts[i1]

			for i2, edge in pairs(vert) do
				--
				FindAndRemove(edge, tri)

				--
				ne = ne + 1

				if #edge == 0 then
					ne, vert[i2] = ne - 1
				end
			end

			if ne == 0 then
				verts[i1] = nil
-- ^^ TODO: kill x, y too? (e.g. by sparse array) (special case supertriangle points?)
			end
		end
	end
end

_GetAdjacentTriangle_Tri_ = M.GetAdjacentTriangle_Tri
_GetIndices_ = M.GetIndices
_GetVertexPos_ = M.GetVertexPos

return M