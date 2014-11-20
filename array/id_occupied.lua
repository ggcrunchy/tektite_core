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
	-- Update the ID for the current maze and overwrite one slot with an invalid ID. A slot
	-- is considered "explored" if it contains the current ID. This is a subtle alternative
	-- to overwriting all slots or building a new table: Since the current ID iterates over
	-- the number of available slots (and then resets), and since every slot is invalidated
	-- between occurrences of the ID taking on a given value, all slots will either contain
	-- some other ID or be invalid, i.e. none will be already explored.
	local new = array_index.RotateIndex(open.id, #open)

	open.id, open[-new] = new

	-- Compute the deltas between rows of the maze event block (using its width).
	local col1, col2 = block:GetColumns()

	Deltas[1] = col1 - col2 - 1
	Deltas[3] = col2 - col1 + 1

	-- Choose a random maze tile and do a random flood-fill of the block.
	Maze[#Maze + 1] = random(#open / 4)

	repeat
		local index = Maze[#Maze]

		-- Mark this tile slot as explored.
		open[-index] = new

		-- Examine each direction out of the tile. If the direction was already marked
		-- (borders are pre-marked in the relevant direction), or the relevant neighbor
		-- has already been explored, ignore it. Otherwise, add it to the choices.
		local oi, n = (index - 1) * 4, 0

		for i, delta in ipairs(Deltas) do
			if not (open[oi + i] or open[-(index + delta)] == new) then
				n = n + 1

				Choices[n] = i
			end
		end

		-- If there are no choices left, remove the tile from the list. Otherwise, choose
		-- one of the available directions and mark it, plus the reverse direction in the
		-- relevant neighbor, and try to resume the flood-fill from that neighbor.
		if n > 0 then
			local i = Choices[random(n)]
			local delta = Deltas[i]

			open[oi + i] = true

			oi = oi + delta * 4
			i = (i + 1) % 4 + 1

			open[oi + i] = true

			Maze[#Maze + 1] = index + delta
		else
			remove(Maze)
		end
	until #Maze == 0
]]

--[[
	-- If this is a later probe (i.e. it doesn't begin at the start), it will have one or
	-- more predecessors pointing at it from various directions. Turn this around: put our
	-- probe into the successor list in each such predecessor (and reinterpret it as a
	-- regular node).
	if tile ~= start then
		for _, prev in ipairs(visited[-tile]) do
			prev.next = prev.next or { is_branch = true }

			insert(prev.next, probe)

			-- Back-propagate the patch.
			PatchUp(prev, visited, paths, start)
		end
]]

-- ...

--[[
				-- More than one route open:
				-- Any probes leaving a tile in a given direction share the same future(s).
				-- Thus, we only ever need one outgoing probe per direction in any given
				-- tile, even if said tile was approached from more than one direction. A
				-- consequence of this is that only probes that arrive at the tile early
				-- (i.e. when not visited, or during the same iteration) are considered;
				-- otherwise, their paths will already be too long (like goals, as above),
				-- i.e. they constitute loops or backtracking. If accepted, the probe is
				-- added to the tile's predecessor list.
				local jinfo = visited[-tile]

				if N > 1 and (not jinfo or jinfo.iteration == iteration) then
					jinfo = jinfo or { iteration = iteration }

					for j = 1, N do
						local dir = Dirs[j].dir

						if not jinfo[dir] then
							insert(probes, { dt = Dirs[j].dt, tile, dir })

							jinfo[dir] = true
						end
					end

					insert(jinfo, cur)

					visited[-tile] = jinfo
]]

-- Export the module.
return M