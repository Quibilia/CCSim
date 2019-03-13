socketstatus, socket = pcall(require, "socket")
cursesstatus, curses = pcall(require, "curses")

_time = os.clock
if socketstatus then _time = socket.gettime end

Person = require("CCSCommon.Person")()
Party = require("CCSCommon.Party")()
City = require("CCSCommon.City")()
Region = require("CCSCommon.Region")()
Country = require("CCSCommon.Country")()
World = require("CCSCommon.World")()

printf = function(stdscr, fmt, ...)
	if stdscr then
		local y, x = stdscr:getyx()
		stdscr:move(y, 0)
		stdscr:clrtobot()
		stdscr:addstr(string.format(fmt, ...))
		stdscr:addstr("\n")
		stdscr:refresh()
	else
		io.write("\r")
		io.write(string.format(fmt, ...))
		io.write("\n")
	end
end

printl = function(stdscr, fmt, ...)
	if stdscr then
		local y, x = stdscr:getyx()
		stdscr:move(y, 0)
		stdscr:clrtobot()
		stdscr:addstr(string.format(fmt, ...))
		stdscr:move(y, 0)
		stdscr:refresh()
	else
		io.write("\r")
		io.write(string.format(fmt, ...))
		io.write("\r")
	end
end

printp = function(stdscr, fmt, ...)
	if stdscr then
		local y, x = stdscr:getyx()
		stdscr:move(y, 0)
		stdscr:clrtobot()
		stdscr:addstr(string.format(fmt, ...))
		stdscr:refresh()
	else
		io.write("\r")
		io.write(string.format(fmt, ...))
	end
end

printc = function(stdscr, fmt, ...)
	if stdscr then
		local y, x = stdscr:getyx()
		stdscr:clrtobot()
		local str = string.format(fmt, ...)
		if x+str:len() < curses:cols() then stdscr:addstr(str) elseif x+3 < curses:cols() then stdscr:addstr("...") end
	else io.write(string.format(fmt, ...)) end
end

readl = function(stdscr)
	if stdscr then return stdscr:getstr()
	else return io.read() end
end

return
	function()
		local CCSCommon = {
			alpha = {},
			c_events = {
				{
					name="Coup d'Etat",
					chance=10,
					target=nil,
					args=1,
					inverse=false,
					eString="",
					performEvent=function(self, parent, c)
						c:event(parent, "Coup d'Etat")

						parent:rseed()
						local dchance = math.random(1, 100)
						if dchance < 26 then -- Executed
							for q=1,#c.people do if c.people[q] and c.people[q].isruler then c:delete(parent, q) end end
						else -- Exiled
							local newC = parent:randomChoice(parent.thisWorld.countries)
							if parent.numCountries > 1 then while newC.name == c.name do newC = parent:randomChoice(parent.thisWorld.countries) end end
							local ruler = nil
							for q, r in pairs(c.people) do if r.isruler then ruler = r end end
							if r then newC:add(parent, r) end
						end

						c.hasruler = -1
						c:checkRuler(parent)

						c.stability = c.stability-10
						if c.stability < 1 then c.stability = 1 end

						return -1
					end
				},
				{
					name="Revolution",
					chance=5,
					target=nil,
					args=1,
					eString="",
					inverse=false,
					performEvent=function(self, parent, c)
						parent:rseed()
						local dchance = math.random(1, 100)
						if dchance < 51 then -- Executed
							for q=1,#c.people do if c.people[q] and c.people[q].isruler then c:delete(parent, q) end end
						else -- Exiled
							local newC = parent:randomChoice(parent.thisWorld.countries)
							if parent.numCountries > 1 then while newC.name == c.name do newC = parent:randomChoice(parent.thisWorld.countries) end end
							local ruler = nil
							for q, r in pairs(c.people) do if r.isruler then ruler = r end end
							if r then newC:add(parent, r) end
						end

						c.hasruler = -1

						local oldsys = parent.systems[c.system].name
						while parent.systems[c.system].name == oldsys do c.system = math.random(1, #parent.systems) end
						c.snt[parent.systems[c.system].name] = c.snt[parent.systems[c.system].name]+1

						c:event(parent, "Revolution: "..oldsys.." to "..parent.systems[c.system].name)
						c:event(parent, "Establishment of the "..parent:ordinal(c.snt[parent.systems[c.system].name]).." "..c.demonym.." "..c.formalities[parent.systems[c.system].name])

						c:checkRuler(parent)

						if c.snt[parent.systems[c.system].name] > 1 then
							if parent.systems[c.system].dynastic then
								local newRuler = -1
								for i=1,#c.people do if c.people[i].isruler then newRuler = i end end
								if c.people[newRuler].LastRoyalAncestor ~= "" then
									msg = "Enthronement of "..c.people[newRuler].title.." "..c.people[newRuler].royalName.." "..parent:roman(c.people[newRuler].number).." of "..c.name..", "..parent:generationString(c.people[newRuler].royalGenerations, c.people[newRuler].gender).." of "..c.people[newRuler].LastRoyalAncestor
									c:event(parent, msg)
								end
							end
						end

						c.stability = c.stability-15
						if c.stability < 1 then c.stability = 1 end

						if math.floor(#c.people/10) > 1 then
							for d=1,math.random(1, math.floor(#c.people/10)) do
								local z = math.random(1, #c.people)
								c:delete(parent, z)
							end
						end

						return -1
					end
				},
				{
					name="Civil War",
					chance=2,
					target=nil,
					args=1,
					eString="",
					inverse=false,
					status=0,
					opIntervened = {},
					govIntervened = {},
					beginEvent=function(self, parent, c)
						c.civilWars = c.civilWars+1
						c:event(parent, "Beginning of "..parent:ordinal(c.civilWars).." civil war")
						self.status = 0 -- -100 is victory for the opposition side; 100 is victory for the present government.
						self.status = self.status+parent:strengthFactor(c)
						local statString = ""
						if self.status <= -10 then statString = tostring(math.floor(math.abs(self.status))).."%% opposition"
						elseif self.status >= 10 then statString = tostring(math.floor(math.abs(self.status))).."%% government"
						else statString = "tossup" end
						if self.status <= -100 then statString = "opposition victory"
						elseif self.status >= 100 then statString = "government victory" end
						self.eString = parent:ordinal(c.civilWars).." "..c.demonym.." civil war ("..statString..")"
						self.opIntervened = {}
						self.govIntervened = {}
					end,
					doStep=function(self, parent, c)
						for i, cp in pairs(parent.thisWorld.countries) do
							if cp.name ~= c.name then
								local interv = false
								for j=1,#self.opIntervened do if self.opIntervened[j] == cp.name then interv = true end end
								for j=1,#self.govIntervened do if self.govIntervened[j] == cp.name then interv = true end end
								if not interv then
									if cp.relations[c.name] then
										if cp.relations[c.name] < 20 then
											local intervene = math.random(1, cp.relations[c.name])
											if intervene == 1 then
												c:event(parent, "Intervention on the side of the opposition by "..cp.name)
												cp:event(parent, "Intervened in the "..parent:ordinal(c.civilWars).." "..c.demonym.." civil war on the side of the opposition")
												table.insert(self.opIntervened, cp.name)
											end
										elseif cp.relations[c.name] > 70 then
											local intervene = math.random(50, 150-cp.relations[c.name])
											if intervene == 50 then
												c:event(parent, "Intervention on the side of the government by "..cp.name)
												cp:event(parent, "Intervened in the "..parent:ordinal(c.civilWars).." "..c.demonym.." civil war on the side of the government")
												table.insert(self.govIntervened, cp.name)
											end
										end
									end
								end
							end
						end

						local varistab = parent:strengthFactor(c)

						for i=1,#self.opIntervened do
							local cp = parent.thisWorld.countries[self.opIntervened[i]]
							if cp then
								local extFactor = parent:strengthFactor(cp)
								if extFactor < 0 then varistab = varistab-(extFactor/10) end
							end
						end

						for i=1,#self.govIntervened do
							local cp = parent.thisWorld.countries[self.govIntervened[i]]
							if cp then
								local extFactor = parent:strengthFactor(cp)
								if extFactor > 0 then varistab = varistab+(extFactor/10) end
							end
						end

						self.status = self.status+math.random(math.floor(varistab-5), math.ceil(varistab+5))/2

						local statString = ""
						if self.status <= -10 then statString = tostring(math.abs(math.floor(self.status))).."%% opposition"
						elseif self.status >= 10 then statString = tostring(math.abs(math.floor(self.status))).."%% government"
						else statString = "tossup" end
						if self.status <= -100 then statString = "opposition victory"
						elseif self.status >= 100 then statString = "government victory" end
						self.eString = parent:ordinal(c.civilWars).." "..c.demonym.." civil war ("..statString..")"

						if self.status <= -100 then return self:endEvent(parent, c) end
						if self.status >= 100 then return self:endEvent(parent, c) end
						return 0
					end,
					endEvent=function(self, parent, c)
						if self.status >= 100 then -- Government victory
							c:event(parent, "End of civil war; victory for "..c.rulers[#c.rulers].title.." "..c.rulers[#c.rulers].name.." "..parent:roman(c.rulers[#c.rulers].number).." of "..c.rulers[#c.rulers].Country)
							for i=1,#self.opIntervened do
								local opC = parent.thisWorld.countries[self.opIntervened[i]]
								if opC then opC:event(parent, "Defeat with opposition forces in the "..parent:ordinal(c.civilWars).." "..c.demonym.." civil war") end
							end
							for i=1,#self.govIntervened do
								local opC = parent.thisWorld.countries[self.govIntervened[i]]
								if opC then opC:event(parent, "Victory with government forces in the "..parent:ordinal(c.civilWars).." "..c.demonym.." civil war") end
							end
						else -- Opposition victory
							local dchance = math.random(1, 100)
							if dchance < 51 then -- Executed
								for q=1,#c.people do if c.people[q] and c.people[q].isruler then c:delete(parent, q) end end
							else -- Exiled
								local newC = parent:randomChoice(parent.thisWorld.countries)
								if parent.numCountries > 1 then while newC.name == c.name do newC = parent:randomChoice(parent.thisWorld.countries) end end
								local ruler = nil
								for q, r in pairs(c.people) do if r.isruler then ruler = r end end
								if r then newC:add(parent, r) end
							end

							for i=1,#self.opIntervened do
								local opC = parent.thisWorld.countries[self.opIntervened[i]]
								if opC then opC:event(parent, "Victory with opposition forces in the "..parent:ordinal(c.civilWars).." "..c.demonym.." civil war") end
							end
							for i=1,#self.govIntervened do
								local opC = parent.thisWorld.countries[self.govIntervened[i]]
								if opC then opC:event(parent, "Defeat with government forces in the "..parent:ordinal(c.civilWars).." "..c.demonym.." civil war") end
							end

							c.hasruler = -1

							local oldsys = parent.systems[c.system].name
							c.system = math.random(1, #parent.systems)
							c.snt[parent.systems[c.system].name] = c.snt[parent.systems[c.system].name]+1
							c:event(parent, "Establishment of the "..parent:ordinal(c.snt[parent.systems[c.system].name]).." "..c.demonym.." "..c.formalities[parent.systems[c.system].name])

							c:checkRuler(parent)

							local newRuler = nil
							for i=1,#c.people do if c.people[i].isruler then newRuler = i end end

							local namenum = 0
							local prevtitle = ""
							if c.people[newRuler].prevtitle then prevtitle = c.people[newRuler].prevtitle.." " end

							if prevtitle == "Homeless " then prevtitle = "" end
							if prevtitle == "Citizen " then prevtitle = "" end
							if prevtitle == "Mayor " then prevtitle = "" end

							if parent.systems[c.system].dynastic then
								for i=1,#c.rulers do if c.rulers[i].Country == c.name and tonumber(c.rulers[i].From) >= c.founded and c.rulers[i].name == c.people[newRuler].royalName and c.rulers[i].title == c.people[newRuler].title then namenum = namenum+1 end end

								c:event(parent, "End of civil war; victory for "..prevtitle..c.people[newRuler].name.." "..c.people[newRuler].surname.." of the "..c.people[newRuler].party..", now "..c.people[newRuler].title.." "..c.people[newRuler].royalName.." "..parent:roman(namenum).." of "..c.name)
								if c.snt[parent.systems[c.system].name] > 1 then
									if parent.systems[c.system].dynastic then
										if c.people[newRuler].LastRoyalAncestor ~= "" then
											msg = "Enthronement of "..c.people[newRuler].title.." "..c.people[newRuler].royalName.." "..parent:roman(c.people[newRuler].number).." of "..c.name..", "..parent:generationString(c.people[newRuler].royalGenerations, c.people[newRuler].gender).." of "..c.people[newRuler].LastRoyalAncestor
											c:event(parent, msg)
										end
									end
								end
							else
								c:event(parent, "End of civil war; victory for "..prevtitle..c.people[newRuler].name.." "..c.people[newRuler].surname.." of the "..c.people[newRuler].party..", now "..c.people[newRuler].title.." "..c.people[newRuler].royalName.." "..c.people[newRuler].surname.." of "..c.name)
								if c.snt[parent.systems[c.system].name] > 1 then
									if parent.systems[c.system].dynastic then
										if c.people[newRuler].LastRoyalAncestor ~= "" then
											msg = "Enthronement of "..c.people[newRuler].title.." "..c.people[newRuler].royalName.." "..parent:roman(c.people[newRuler].number).." of "..c.name..", "..parent:generationString(c.people[newRuler].royalGenerations, c.people[newRuler].gender).." of "..c.people[newRuler].LastRoyalAncestor
											c:event(parent, msg)
										end
									end
								end
							end
						end

						return -1
					end,
					performEvent=function(self, parent, c)
						for i=1,#c.ongoing-1 do if c.ongoing[i].name == self.name then return -1 end end
						return 0
					end
				},
				{
					name="War",
					chance=10,
					target=nil,
					args=2,
					status=0,
					eString="",
					inverse=true,
					beginEvent=function(self, parent, c1)
						c1:event(parent, "Declared war on "..self.target.name)
						self.target:event(parent, "War declared by "..c1.name)
						self.status = 0 -- -100 is victory for the target; 100 is victory for the initiator.
						self.status = self.status+parent:strengthFactor(c1)
						self.status = self.status-parent:strengthFactor(self.target)
						local statString = ""
						if self.status <= -10 then statString = tostring(math.floor(math.abs(self.status))).."%% "..self.target.name
						elseif self.status >= 10 then statString = tostring(math.floor(math.abs(self.status))).."%% "..c1.name
						else statString = "tossup" end
						if self.status <= -100 then statString = self.target.demonym.." victory"
						elseif self.status >= 100 then statString = c1.demonym.." victory" end
						self.eString = c1.demonym.."-"..self.target.demonym.." war ("..statString..")"
					end,
					doStep=function(self, parent, c1)
						if not self.target then return -1 end

						local ao = parent:getAllyOngoing(c1, self.target, self.name)
						local ac = c1.alliances

						for i=1,#ac do
							local c3 = nil
							for j, cp in pairs(parent.thisWorld.countries) do if cp.name == ac[i] then c3 = cp end end
							if c3 then
								local already = false
								for j=1,#ao do if c3.name == ao[j].name then already = true end end
								if not already then
									local ic = math.random(1, 25)
									if ic == 10 then
										table.insert(c3.allyOngoing, self.name.."?"..c1.name..":"..self.target.name)

										self.target:event(parent, "Intervention by "..c3.name.." on the side of "..c1.name)
										c1:event(parent, "Intervention by "..c3.name.." against "..self.target.name)
										c3:event(parent, "Intervened on the side of "..c1.name.." in war with "..self.target.name)
									end
								end
							end
						end

						ao = parent:getAllyOngoing(self.target, c1, self.name)
						ac = self.target.alliances

						for i=1,#ac do
							local c3 = nil
							for j, cp in pairs(parent.thisWorld.countries) do if cp.name == ac[i] then c3 = cp end end
							if c3 then
								local already = false
								for j=1,#ao do if c3.name == ao[j].name then already = true end end
								if not already then
									local ic = math.random(1, 25)
									if ic == 10 then
										table.insert(c3.allyOngoing, self.name.."?"..self.target.name..":"..c1.name)

										c1:event(parent, "Intervention by "..c3.name.." on the side of "..self.target.name)
										self.target:event(parent, "Intervention by "..c3.name.." against "..c1.name)
										c3:event(parent, "Intervened on the side of "..self.target.name.." in war with "..c1.name)
									end
								end
							end
						end

						local str1Factor = parent:strengthFactor(c1)
						local str2Factor = parent:strengthFactor(self.target)

						local varistab = str1Factor-str2Factor

						ao = parent:getAllyOngoing(c1, self.target, self.name)

						for i=1,#ao do
							local extFactor = parent:strengthFactor(ao[i])
							varistab = varistab+(extFactor/10)
						end

						ao = parent:getAllyOngoing(self.target, c1, self.name)

						for i=1,#ao do
							local extFactor = parent:strengthFactor(ao[i])
							varistab = varistab-(extFactor/10)
						end

						self.status = self.status+math.random(math.floor(varistab-5), math.ceil(varistab+5))/2

						local statString = ""
						if self.status <= -10 then statString = tostring(math.floor(math.abs(self.status))).."%% "..self.target.name
						elseif self.status >= 10 then statString = tostring(math.floor(math.abs(self.status))).."%% "..c1.name
						else statString = "tossup" end
						if self.status <= -100 then statString = self.target.demonym.." victory"
						elseif self.status >= 100 then statString = c1.demonym.." victory" end
						self.eString = c1.demonym.."-"..self.target.demonym.." war ("..statString..")"

						if self.status <= -100 then return self:endEvent(parent, c1) end
						if self.status >= 100 then return self:endEvent(parent, c1) end
						return 0
					end,
					endEvent=function(self, parent, c1)
						local c1strength = c1.strength
						local c2strength = self.target.strength

						if self.status >= 100 then
							c1:event(parent, "Victory in war with "..self.target.name)
							self.target:event(parent, "Defeat in war with "..c1.name)

							c1.stability = c1.stability+10
							self.target.stability = self.target.stability-10

							local ao = parent:getAllyOngoing(c1, self.target, self.name)

							for i=1,#ao do
								if ao[i] then
									c1strength = c1strength+ao[i].strength
									ao[i]:event(parent, "Victory with "..c1.name.." in war with "..self.target.name)
								end
							end

							ao = parent:getAllyOngoing(self.target, c1, self.name)

							for i=1,#ao do
								if ao[i] then
									c2strength = c2strength+ao[i].strength
									ao[i]:event(parent, "Defeat with "..self.target.name.." in war with "..c1.name)
								end
							end

							parent:removeAllyOngoing(c1, self.target, self.name)
							parent:removeAllyOngoing(self.target, c1, self.name)

							if c1strength > c2strength+(c2strength/5) then
								local rcount = 0
								for q, b in pairs(self.target.regions) do rcount = rcount+1 end
								if rcount > 1 then
									local rname = parent:randomChoice(self.target.regions).name
									parent:RegionTransfer(c1, self.target, rname, false)
								end
							end
						elseif self.status <= -100 then
							c1:event(parent, "Defeat in war with "..self.target.name)
							self.target:event(parent, "Victory in war with "..c1.name)

							c1.stability = c1.stability-25
							self.target.stability = self.target.stability+25

							local ao = parent:getAllyOngoing(c1, self.target, self.name)

							for i=1,#ao do
								c1strength = c1strength+ao[i].strength
								ao[i]:event(parent, "Defeat with "..c1.name.." in war with "..self.target.name)
							end

							ao = parent:getAllyOngoing(self.target, c1, self.name)

							for i=1,#ao do
								c2strength = c2strength+ao[i].strength
								ao[i]:event(parent, "Victory with "..self.target.name.." in war with "..c1.name)
							end

							parent:removeAllyOngoing(c1, self.target, self.name)
							parent:removeAllyOngoing(self.target, c1, self.name)

							if c2strength > c1strength+(c1strength/5) then
								local rcount = 0
								for q, b in pairs(c1.regions) do rcount = rcount+1 end
								if rcount > 1 then
									local rname = parent:randomChoice(c1.regions).name
									parent:RegionTransfer(self.target, c1, rname, false)
								end
							end
						end

						return -1
					end,
					performEvent=function(self, parent, c1, c2)
						for i=1,#c1.ongoing-1 do if c1.ongoing[i].name == self.name and c1.ongoing[i].target.name == c2.name then return -1 end end

						if parent.doR then
							local border = false
							local water = {}
							for i=1,#c1.nodes do
								local x = c1.nodes[i][1]
								local y = c1.nodes[i][2]
								local z = c1.nodes[i][3]

								for j=1,#parent.thisWorld.planet[x][y][z].neighbors do
									local neighbor = parent.thisWorld.planet[x][y][z].neighbors[j]
									local nx = neighbor[1]
									local ny = neighbor[2]
									local nz = neighbor[3]
									local nnode = parent.thisWorld.planet[nx][ny][nz]
									if nnode.country == c2.name then border = true end
									if not nnode.land then water[1] = 1 end
								end
							end

							for i=1,#c2.nodes do
								local x = c2.nodes[i][1]
								local y = c2.nodes[i][2]
								local z = c2.nodes[i][3]

								for j=1,#parent.thisWorld.planet[x][y][z].neighbors do
									local neighbor = parent.thisWorld.planet[x][y][z].neighbors[j]
									local nx = neighbor[1]
									local ny = neighbor[2]
									local nz = neighbor[3]
									local nnode = parent.thisWorld.planet[nx][ny][nz]
									if nnode.country == c1.name then border = true end
									if not nnode.land then water[2] = 1 end
								end
							end

							if not border then if not water[1] or not water[2] then return -1 end end
						end

						if c1.relations[c2.name] then
							if c1.relations[c2.name] < 30 then
								self.target = c2
								return 0
							end
						end

						return -1
					end
				},
				{
					name="Alliance",
					chance=15,
					target=nil,
					args=2,
					inverse=true,
					eString="",
					beginEvent=function(self, parent, c1)
						c1:event(parent, "Entered military alliance with "..self.target.name)
						self.target:event(parent, "Entered military alliance with "..c1.name)

						self.eString = c1.demonym.."-"..self.target.demonym.." alliance"
					end,
					doStep=function(self, parent, c1)
						if not self.target then return -1 end

						if c1.relations[self.target.name] then
							if c1.relations[self.target.name] < 35 then
								local doEnd = math.random(1, 50)
								if doEnd < 5 then return self:endEvent(parent, c1) end
							end
						end

						local doEnd = math.random(1, 500)
						if doEnd < 5 then return self:endEvent(parent, c1) end

						self.eString = c1.demonym.."-"..self.target.demonym.." alliance"

						return 0
					end,
					endEvent=function(self, parent, c1)
						c1:event(parent, "Military alliance severed with "..self.target.name)
						self.target:event(parent, "Military alliance severed with "..c1.name)

						for i=#self.target.alliances,1,-1 do
							if self.target.alliances[i] == c1.name then
								table.remove(self.target.alliances, i)
								i = 0
							end
						end

						for i=#c1.alliances,1,-1 do
							if c1.alliances[i] == self.target.name then
								table.remove(c1.alliances, i)
								i = 0
							end
						end

						return -1
					end,
					performEvent=function(self, parent, c1, c2)
						for i=1,#c1.alliances do if c1.alliances[i] == c2.name then return -1 end end
						for i=1,#c2.alliances do if c2.alliances[i] == c1.name then return -1 end end

						if c1.relations[c2.name] then
							if c1.relations[c2.name] > 80 then
								self.target = c2
								table.insert(c2.alliances, c1.name)
								table.insert(c1.alliances, c2.name)
								return 0
							end
						end

						return -1
					end
				},
				{
					name="Independence",
					chance=6,
					target=nil,
					args=1,
					inverse=false,
					performEvent=function(self, parent, c)
						parent:rseed()

						local values = 0
						for i, j in pairs(c.regions) do values = values+1 end

						if values > 1 then
							local newl = Country:new()
							local nc = parent:randomChoice(c.regions)
							for i, j in pairs(parent.thisWorld.countries) do if j.name == nc.name then return -1 end end
							
							newl.name = nc.name

							for i=1,#nc.nodes do
								local x = nc.nodes[i][1]
								local y = nc.nodes[i][2]
								local z = nc.nodes[i][3]

								parent.thisWorld.planet[x][y][z].country = newl.name
								parent.thisWorld.planet[x][y][z].region = ""
							end

							newl.rulers = {}
							for i=1,#c.rulers do newl.rulers[i] = c.rulers[i] end
							
							for i=1,#c.rulernames do newl.rulernames[i] = c.rulernames[i] end
							table.remove(newl.rulernames, math.random(1, #newl.rulernames))
							table.insert(newl.rulernames, parent:name(true))
							for i=1,#c.frulernames do newl.frulernames[i] = c.frulernames[i] end
							table.remove(newl.frulernames, math.random(1, #newl.frulernames))
							table.insert(newl.frulernames, parent:name(true))

							local retrieved = false
							
							for i, j in pairs(parent.final) do
								if j.name == newl.name then
									local conqYear = nil
									local retrieve = true
									for k, l in pairs(j.events) do
										if l.Event:match("Conquered") then if not conqYear or l.Year > conqYear then
											conqYear = l.Year
											retrieve = true
										end end
										if conqYear and not l.Event:match("Conquered") and not l.Event:match("Loss of") and not l.Event:match("Capital moved") and l.Year > conqYear then retrieve = false end
									end

									if retrieve then										
										retrieved = true
										
										for k=1,#j.rulers do
											local written = false
											for l=1,#newl.rulers do if not written then
												if j.rulers[k].From >= newl.rulers[#newl.rulers].From then
													table.insert(newl.rulers, l, j.rulers[k])
													written = true
												end
											end end
											if not written then table.insert(newl.rulers, j.rulers[k]) end
										end
										
										for k, l in pairs(j.events) do table.insert(newl.events, l) end
									
										local found = parent.years
										for i=1,#newl.rulers do if newl.rulers[i].Country == newl.name and newl.rulers[i].From <= found then found = newl.rulers[i].From end end
										newl.founded = found
										
										local rIndex = 1
										for k, l in pairs(j.rulers) do
											table.insert(newl.rulers, rIndex, l)
											rIndex = rIndex+1
										end
										
										newl.snt = j.snt
										newl.dfif = j.dfif
										newl.formalities = j.formalities
										newl.civilWars = j.civilWars
										newl.agPrim = j.agPrim
										
										newl.rulernames = {}
										newl.frulernames = {}
										for i=1,#j.rulernames do newl.rulernames[i] = j.rulernames[i] end
										for i=1,#j.frulernames do newl.frulernames[i] = j.frulernames[i] end
										
										for i, j in pairs(nc.subregions) do newl.regions[j.name] = j end
										
										for i, j in pairs(newl.regions) do for k, l in pairs(j.nodes) do
											local x = l[1]
											local y = l[2]
											local z = l[3]
											
											for k, l in pairs(c.regions) do for m, n in pairs(l.cities) do if j.cities[n.name] then l.cities[n.name] = nil end end end
										end end

										parent.final[i] = nil
									end
								end
							end

							newl:event(parent, "Independence from "..c.name)
							c:event(parent, "Granted independence to "..newl.name)

							for i=#c.people,1,-1 do if c.people[i] and c.people[i].def and not c.people[i].isruler and c.people[i].region == newl.name then newl:add(parent, c.people[i]) end end

							for i=1,math.floor(#c.people/5) do
								local p = parent:randomChoice(c.people)
								while p.isruler do p = parent:randomChoice(c.people) end
								newl:add(parent, p)
							end
							
							newl:set(parent)
							if parent.doR then newl:setTerritory(parent) end

							c.regions[newl.name] = nil
							parent.thisWorld:add(newl)
							parent:getAlphabeticalCountries()

							c.stability = c.stability-math.random(3, 10)
							if c.stability < 1 then c.stability = 1 end

							if c.capitalregion == newl.name then
								for i, j in pairs(newl.regions) do
									for k, l in pairs(j.cities) do
										if l.name == c.capitalcity then
											local oldcap = c.capitalcity
											local oldreg = c.capitalregion

											local nr = parent:randomChoice(c.regions)
											c.capitalregion = nr.name
											c.capitalcity = parent:randomChoice(nr.cities, true)

											local msg = "Capital moved"
											if oldcap ~= "" then msg = msg.." from "..oldcap end
											msg = msg.." to "..c.capitalcity

											c:event(parent, msg)
										end
									end
								end
							end
							
							newl:checkRuler(parent)
						end

						return -1
					end
				},
				{
					name="Invade",
					chance=6,
					target=nil,
					args=2,
					inverse=true,
					performEvent=function(self, parent, c1, c2)
						for i=1,#c1.alliances do if c1.alliances[i] == c2.name then return -1 end end
						for i=1,#c2.alliances do if c2.alliances[i] == c1.name then return -1 end end

						if c1.relations[c2.name] then
							if c1.relations[c2.name] < 16 then
								c1:event(parent, "Invaded "..c2.name)
								c2:event(parent, "Invaded by "..c1.name)

								c1.stability = c1.stability-5
								if c1.stability < 1 then c1.stability = 1 end
								c2.stability = c2.stability-10
								if c2.stability < 1 then c2.stability = 1 end
								c1:setPop(parent, math.ceil(c1.population/1.25))
								c2:setPop(parent, math.ceil(c2.population/1.75))

								local rcount = 0
								for q, b in pairs(c2.regions) do rcount = rcount+1 end
								if rcount > 1 and c1.strength > c2.strength+(c2.strength/5) then
									local rchance = math.random(1, 30)
									if rchance < 5 then
										local rname = parent:randomChoice(c2.regions).name
										parent:RegionTransfer(c1, c2, rname, false)
									end
								end
							end
						end

						return -1
					end
				},
				{
					name="Conquer",
					chance=3,
					target=nil,
					args=2,
					inverse=true,
					performEvent=function(self, parent, c1, c2)
						for i=1,#c1.alliances do if c1.alliances[i] == c2.name then return -1 end end
						for i=1,#c2.alliances do if c2.alliances[i] == c1.name then return -1 end end

						if c1.relations[c2.name] then
							if c1.relations[c2.name] < 11 then
								c1:event(parent, "Conquered "..c2.name)
								c2:event(parent, "Conquered by "..c1.name)

								local newr = Region:new()
								newr.name = c2.name
								
								for i=#c2.people,1,-1 do
									c2.people[i].region = c2.name
									c2.people[i].nationality = c1.name
									c2.people[i].military = false
									c2.people[i].isruler = false
									c2.people[i].level = 2
									c2.people[i].title = "Citizen"
									c2.people[i].parentRuler = false
									table.insert(c1.people, table.remove(c2.people, i))
								end
								
								c2.people = nil
								
								for i, j in pairs(c2.regions) do
									table.insert(newr.subregions, j)
									for k, l in pairs(j.cities) do newr.cities[k] = l end
								end
								
								for i=#c2.nodes,1,-1 do
									local x = c2.nodes[i][1]
									local y = c2.nodes[i][2]
									local z = c2.nodes[i][3]
									parent.thisWorld.planet[x][y][z].country = c1.name
									parent.thisWorld.planet[x][y][z].region = c2.name
									table.insert(c1.nodes, {x, y, z})
									table.insert(newr.nodes, {x, y, z})
									c2.nodes[i] = nil
								end

								c1.stability = c1.stability-5
								if c1.stability < 1 then c1.stability = 1 end
								if #c2.rulers > 0 then c2.rulers[#c2.rulers].To = parent.years end
								
								c1.regions[newr.name] = newr

								parent.thisWorld:delete(parent, c2)
							end
						end

						return -1
					end
				},
				{
					name="Capital Migration",
					chance=3,
					target=nil,
					args=1,
					inverse=false,
					performEvent=function(self, parent, c)
						local cCount = 0
						for i, j in pairs(c.regions) do for k, l in pairs(j.cities) do cCount = cCount+1 end end

						if cCount > 2 then
							local oldcap = c.capitalcity
							if not oldcap then oldcap = "" end
							c.capitalregion = nil
							c.capitalcity = nil

							while not c.capitalcity do
								for i, j in pairs(c.regions) do
									for k, l in pairs(j.cities) do
										if l.name ~= oldcap then
											if not c.capitalcity then
												local chance = math.random(1, 100)
												if chance == 35 then
													c.capitalregion = j.name
													c.capitalcity = k

													local msg = "Capital moved"
													if oldcap ~= "" then msg = msg.." from "..oldcap end
													msg = msg.." to "..c.capitalcity

													c:event(parent, msg)
												end
											end
										end
									end
								end
							end
						end

						return -1
					end
				},
				{
					name="Annex",
					chance=6,
					target=nil,
					args=2,
					inverse=false,
					performEvent=function(self, parent, c1, c2)
						local patron = false

						for i=1,#c2.rulers do if c2.rulers[i].Country == c1.name then patron = true end end
						for i=1,#c1.rulers do if c1.rulers[i].Country == c2.name then patron = true end end

						if not patron then
							if c1.majority == c2.majority then
								if c1.relations[c2.name] then
									if c1.relations[c2.name] > 85 then
										c1:event(parent, "Annexed "..c2.name)
										c2:event(parent, "Annexed by "..c1.name)

										local newr = Region:new()
										newr.name = c2.name
										
										for i=#c2.people,1,-1 do
											c2.people[i].region = c2.name
											c2.people[i].nationality = c1.name
											c2.people[i].military = false
											c2.people[i].isruler = false
											c2.people[i].level = 2
											c2.people[i].title = "Citizen"
											c2.people[i].parentRuler = false
											table.insert(c1.people, table.remove(c2.people, i))
										end
										
										c2.people = nil
										
										for i, j in pairs(c2.regions) do
											table.insert(newr.subregions, j)
											for k, l in pairs(j.cities) do newr.cities[k] = l end
										end
										
										for i=#c2.nodes,1,-1 do
											local x = c2.nodes[i][1]
											local y = c2.nodes[i][2]
											local z = c2.nodes[i][3]
											parent.thisWorld.planet[x][y][z].country = c1.name
											parent.thisWorld.planet[x][y][z].region = c2.name
											table.insert(c1.nodes, {x, y, z})
											table.insert(newr.nodes, {x, y, z})
											c2.nodes[i] = nil
										end

										c1.stability = c1.stability-5
										if c1.stability < 1 then c1.stability = 1 end
										if #c2.rulers > 0 then c2.rulers[#c2.rulers].To = parent.years end

										c1.regions[newr.name] = newr
										
										parent.thisWorld:delete(parent, c2)
									end
								end
							end
						end

						return -1
					end
				}
			},
			clrcmd = "",
			consonants = {"b", "c", "d", "f", "g", "h", "j", "k", "l", "m", "n", "p", "r", "s", "t", "v", "w", "z"},
			disabled = {},
			doR = false,
			endgroups = {"land", "ia", "lia", "gia", "ria", "nia", "cia", "y", "ar", "ic", "a", "us", "es", "is", "ec", "tria", "tra", "um"},
			ged = false,
			genLimit = 3,
			initialgroups = {"Ab", "Ac", "Af", "Ag", "Al", "Am", "An", "Ar", "As", "At", "Au", "Av", "Ba", "Be", "Bh", "Bi", "Bo", "Bu", "Ca", "Ce", "Ch", "Ci", "Cl", "Co", "Cr", "Cu", "Da", "De", "Di", "Do", "Du", "Dr", "Ec", "El", "Er", "Fa", "Fr", "Ga", "Ge", "Go", "Gr", "Gh", "Ha", "He", "Hi", "Ho", "Hu", "Ic", "Id", "In", "Io", "Ir", "Is", "It", "Ja", "Ji", "Jo", "Ka", "Ke", "Ki", "Ko", "Ku", "Kr", "Kh", "La", "Le", "Li", "Lo", "Lu", "Lh", "Ma", "Me", "Mi", "Mo", "Mu", "Na", "Ne", "Ni", "No", "Nu", "Pa", "Pe", "Pi", "Po", "Pr", "Ph", "Ra", "Re", "Ri", "Ro", "Ru", "Rh", "Sa", "Se", "Si", "So", "Su", "Sh", "Ta", "Te", "Ti", "To", "Tu", "Tr", "Th", "Va", "Vi", "Vo", "Wa", "Wi", "Wo", "Wh", "Za", "Ze", "Zi", "Zo", "Zu", "Zh", "Tha", "Thu", "The", "Thi", "Tho"},
			maxyears = 1,
			middlegroups = {"gar", "rit", "er", "ar", "ir", "ra", "rin", "bri", "o", "em", "nor", "nar", "mar", "mor", "an", "at", "et", "the", "thal", "cri", "ma", "na", "sa", "mit", "nit", "shi", "ssa", "ssi", "ret", "thu", "thus", "thar", "then", "min", "ni", "ius", "us", "es", "ta", "dos", "tho", "tha", "do", "to", "tri"},
			numCountries = 0,
			partynames = {
				{"National", "United", "Citizens'", "General", "People's", "Joint", "Workers'", "Free", "New"},
				{"National", "United", "Citizens'", "General", "People's", "Joint", "Workers'", "Free", "New"},
				{"Liberal", "Moderate", "Conservative", "Centralist", "Democratic", "Republican", "Economical", "Moral", "Ethical", "Union", "Unionist", "Revivalist", "Labor", "Monarchist", "Nationalist", "Reformist"},
				{"Liberal", "Moderate", "Conservative", "Centralist", "Democratic", "Republican", "Economical", "Moral", "Ethical", "Union", "Unionist", "Revivalist", "Labor", "Monarchist", "Nationalist", "Reformist"},
				{"Party", "Group", "Front", "Coalition", "Force", "Alliance", "Caucus", "Fellowship"},
			},
			popLimit = 2000,
			royals = {},
			showinfo = 0,
			startyear = 1,
			stdscr = nil,
			systems = {
				{
					name="Monarchy",
					ranks={"Homeless", "Citizen", "Mayor", "Knight", "Lord", "Baron", "Viscount", "Earl", "Marquis", "Duke", "Prince", "King"},
					franks={"Homeless", "Citizen", "Mayor", "Dame", "Lady", "Baroness", "Viscountess", "Countess", "Marquess", "Duchess", "Princess", "Queen"},
					formalities={"Kingdom", "Crown", "Lordship", "Dominion", "High Kingship", "Domain"},
					dynastic=true
				},
				{
					name="Republic",
					ranks={"Homeless", "Citizen", "Commissioner", "Mayor", "Councillor", "Governor", "Judge", "Senator", "Minister", "President"},
					formalities={"Republic", "United Republic", "Nation", "Commonwealth", "Federation", "Federal Republic"},
					dynastic=false
				},
				{
					name="Democracy",
					ranks={"Homeless", "Citizen", "Mayor", "Councillor", "Governor", "Minister", "Speaker", "Prime Minister"},
					formalities={"Union", "Democratic Republic", "Free State", "Realm", "Electorate", "State"},
					dynastic=false
				},
				{
					name="Oligarchy",
					ranks={"Homeless", "Citizen", "Mayor", "Councillor", "Governor", "Minister", "Oligarch", "Premier"},
					formalities={"People's Republic", "Premiership", "Patriciate", "Autocracy", "Collective"},
					dynastic=false
				},
				{
					name="Empire",
					ranks={"Homeless", "Citizen", "Mayor", "Lord", "Governor", "Viceroy", "Prince", "Emperor"},
					franks={"Homeless", "Citizen", "Mayor", "Lady", "Governor", "Vicereine", "Princess", "Empress"},
					formalities={"Empire", "Emirate", "Magistracy", "Imperium", "Supreme Crown", "Imperial Crown"},
					dynastic=true
				}
			},
			vowels = {"a", "e", "i", "o", "u", "y"},
			years = 1,
			yearstorun = 0,
			final = {},
			thisWorld = {},
			
			-- Although a console clear command will wipe the visible part of the screen, some terminals will clear scrollback only if the clear command is repeated. Most require only two, but for certainty, execute the clear command three times in rapid succession.
			-- All of this assuming we don't have Curses, of course.
			clearTerm = function(self)
				if not self.stdscr and cursesstatus then
					self.stdscr = curses.initscr()
					curses.cbreak(true)
					curses.echo(true)
					curses.nl(true)
				end
			
				if cursesstatus then
					self.stdscr:refresh()
					self.stdscr:clear()
					self.stdscr:move(0, 0)
				else for i=1,3 do os.execute(self.clrcmd) end end
			end,

			deepcopy = function(self, obj)
				local res = nil
				local t = type(obj)
				local exceptions = {"spouse", "target", "__index"}

				if t == "table" then
					res = {}
					for i, j in pairs(obj) do
						local isexception = false
						for k=1,#exceptions do if exceptions[k] == tostring(i) then isexception = true end end
						if not isexception then res[self:deepcopy(i)] = self:deepcopy(j) end
					end
					if getmetatable(obj) then setmetatable(res, self:deepcopy(getmetatable(obj))) end
				elseif t == "function" then
					res = self:fncopy(obj)
				else
					res = obj
				end

				return res
			end,

			finish = function(self)
				self:clearTerm()
				
				if self.doR then self.thisWorld:rOutput(self, "final.r") end
				
				printf(self.stdscr, "Printing result...")
				local f = io.open("output.txt", "w+")

				local ged = nil
				local fams = {}

				local cKeys = {}
				local alphaOrder = {a=1, b=2, c=3, d=4, e=5, f=6, g=7, h=8, i=9, j=10, k=11, l=12, m=13, n=14, o=15, p=16, q=17, r=18, s=19, t=20, u=21, v=22, w=23, x=24, y=25, z=26}
				for i, j in pairs(self.final) do
					if #cKeys ~= 0 then
						local found = false
						for k=1,#cKeys do if cKeys[k] then if not found then
							local ind = 1
							local chr1 = alphaOrder[cKeys[k]:sub(ind, ind):lower()]
							local chr2 = alphaOrder[j.name:sub(ind, ind):lower()]
							while chr2 == chr1 do
								ind = ind+1
								chr1 = alphaOrder[cKeys[k]:sub(ind, ind):lower()]
								chr2 = alphaOrder[j.name:sub(ind, ind):lower()]
							end
							if not chr1 then
								table.insert(cKeys, k+1, j.name)
								found = true
							elseif not chr2 then
								table.insert(cKeys, k, j.name)
								found = true
							elseif chr2 < chr1 then
								table.insert(cKeys, k, j.name)
								found = true
							end
						end end end
						if not found then table.insert(cKeys, j.name) end
					else table.insert(cKeys, j.name) end
				end

				for i=1,#cKeys do
					local cp = nil
					for j, k in pairs(self.final) do if k.name == cKeys[i] then cp = k end end
					if cp then
						local newc = false
						local pr = 1
						f:write(string.format("Country: "..cp.name.."\nFounded: "..cp.founded..", survived for "..tostring(cp.age).." years\n\n"))

						local rWritten = 1
						local rDone = {}
						
						for k=1,#cp.events do if pr == 1 then
							if cp.events[k].Event:sub(1, 12) == "Independence" and cp.events[k].Year <= cp.founded+1 then
								newc = true
								pr = tonumber(cp.events[k].Year)
							end
						end end

						if newc then
							f:write(string.format(self:getRulerString(cp.rulers[1]).."\n"))
							local nextFound = false
							for k=1,#cp.rulers do
								if tonumber(cp.rulers[k].From) < pr and cp.rulers[k].Country ~= cp.name then
									if tostring(cp.rulers[k].To) == "Current" or tonumber(cp.rulers[k].To) and tonumber(cp.rulers[k].To) >= pr then
										if not nextFound then
											nextFound = true
											f:write("...\n")
											f:write(string.format(self:getRulerString(cp.rulers[k]).."\n"))
											k = #cp.rulers+1
										end
									end
								end
							end
						end

						for j=1,self.maxyears do
							for k=1,#cp.events do if tonumber(cp.events[k].Year) == j and cp.events[k].Event:sub(1, 10) == "Revolution" then f:write(string.format(cp.events[k].Year..": "..cp.events[k].Event.."\n")) end end

							for k=1,#cp.rulers do if tonumber(cp.rulers[k].From) == j and cp.rulers[k].Country == cp.name and not rDone[self:getRulerString(cp.rulers[k])] then
								f:write(string.format(rWritten..". "..self:getRulerString(cp.rulers[k]).."\n"))
								rWritten = rWritten+1
								rDone[self:getRulerString(cp.rulers[k])] = true
							end end

							for k=1,#cp.events do if tonumber(cp.events[k].Year) == j and cp.events[k].Event:sub(1, 10) ~= "Revolution" then f:write(string.format(cp.events[k].Year..": "..cp.events[k].Event.."\n")) end end
						end

						f:write("\n\n\n")
						f:flush()
					end
				end

				f:close()
				f = nil

				printf(self.stdscr, "")

				if self.ged then
					printf(self.stdscr, "Sorting living individuals...")
					local cCount = 0
					local cIndex = 1
					local finished = 0
					for i, j in pairs(self.thisWorld.countries) do cCount = cCount+1 end
					for i, j in pairs(self.thisWorld.countries) do
						printl(self.stdscr, "Country %d/%d", cIndex, cCount)
						j:destroy(self)
						cIndex = cIndex+1
					end

					printf(self.stdscr, "\nFiltering duplicate or irrelevant individuals. This might take a moment...\n")
					local fams = self:sortAscendants()

					ged = io.open(tostring(os.time())..".ged", "w+")
					ged:write("0 HEAD\n1 SOUR CCSim\n2 NAME Compact Country Simulator\n1 GEDC\n2 VERS 5.5\n2 FORM LINEAGE-LINKED\n1 CHAR UTF-8\n1 LANG English\n")

					local sRoyals = {}
					local ind = 1
					for i, j in pairs(self.royals) do if not j.removed then
						j.gIndex = ind
						sRoyals[ind] = j
						ind = ind+1
					end end
					local fInd = 1
					local fCount = 0
					for i, j in pairs(fams) do if j.husb.gIndex ~= 0 and j.wife.gIndex ~= 0 then 
						j.fIndex = fInd
						fCount = fCount+1
						fInd = fInd+1
					end end
					
					for i=#sRoyals,1,-1 do
						local linked = false
						for q, b in pairs(sRoyals[i].fams) do if b.fIndex ~= 0 then linked = true end end
						for q, b in pairs(sRoyals[i].famc) do if b.fIndex ~= 0 then linked = true end end
						if not linked then table.remove(sRoyals, i) end
					end
					
					for i=#sRoyals,1,-1 do sRoyals[i].gIndex = i end
					printf(self.stdscr, "Writing individuals...")

					for i=1,#sRoyals do
						local j = sRoyals[i]
						local jname = j.name
						if j.royalName ~= "" then jname = j.royalName end
						if j.death >= self.years then j.death = 0 end
						local msgout = "0 @I"..tostring(i).."@ INDI\n1 SEX "..j.gender.."\n1 NAME "..jname.." /"..j.surname.."/"
						if j.number ~= 0 then msgout = msgout.." "..self:roman(j.number) end
						if j.title ~= "" then msgout = msgout.."\n2 NPFX "..j.title end
						msgout = msgout.."\n2 GIVN "..jname.."\n2 SURN "..j.surname.."\n"
						if j.number ~= 0 then msgout = msgout.."2 NSFX "..self:roman(j.number).."\n" end
						msgout = msgout.."1 BIRT\n2 DATE "..math.abs(j.birth)
						if j.birth < 0 then msgout = msgout.." B.C." end
						msgout = msgout.."\n2 PLAC "..j.birthplace
						if j.death ~= 0 then msgout = msgout.."\n1 DEAT\n2 DATE "..tostring(j.death).."\n2 PLAC "..j.deathplace end
						if j.ethnicity then
							local ie = true
							for q, b in pairs(j.ethnicity) do
								local eth = string.format("%.2f", b)
								if ie then msgout = msgout.."\n1 NOTE Descent:" end
								msgout = msgout.."\n2 CONT "..eth.."% "..tostring(q)
								ie = nil
							end
						end

						for q, b in pairs(j.fams) do if b.fIndex ~= 0 then msgout = msgout.."\n1 FAMS @F"..tostring(b.fIndex).."@" end end
						for q, b in pairs(j.famc) do if b.fIndex ~= 0 then msgout = msgout.."\n1 FAMC @F"..tostring(b.fIndex).."@" end end

						msgout = msgout.."\n"

						ged:write(msgout)

						finished = finished+1
						printl(self.stdscr, "%.2f%% done", (finished/#sRoyals*10000)/100)
					end

					ged:flush()
					printf(self.stdscr, "\nWriting families...")
					finished = 0

					for i, j in pairs(fams) do if j.fIndex ~= 0 then 
						local msgout = "0 @F"..tostring(j.fIndex).."@ FAM\n"

						msgout = msgout.."1 HUSB @I"..tostring(j.husb.gIndex).."@\n"
						msgout = msgout.."1 WIFE @I"..tostring(j.wife.gIndex).."@\n"

						for k=1,#j.chil do if j.chil[k].gString ~= j.husb.gString and j.chil[k].gString ~= j.wife.gString and j.chil[k].gIndex ~= 0 then msgout = msgout.."1 CHIL @I"..tostring(j.chil[k].gIndex).."@\n" end end

						ged:write(msgout)

						finished = finished+1
						printl(self.stdscr, "%.2f%% done", (finished/fCount*10000)/100)
					end end

					msgout = "0 TRLR\n"

					ged:write(msgout)
					ged:flush()
					ged:close()
					ged = nil
				end
			end,

			fncopy = function(self, fn)
				dumped = string.dump(fn)
				cloned = loadstring(dumped)
				i = 1
				while true do
					name = debug.getupvalue(fn, i)
					if not name then break end
					debug.upvaluejoin(cloned, i, fn, i)
					i = i+1
				end
				return cloned
			end,

			fromFile = function(self, datin)
				self.doR = false

				printf(self.stdscr, "Opening data file...")
				local f = assert(io.open(datin, "r"))
				local done = false
				self.thisWorld = World:new()

				printf(self.stdscr, "Reading data file...")

				local fc = nil
				local fr = nil
				local sysChange = true

				while not done do
					local l = f:read()
					if not l then done = true
					else
						local mat = {}
						for q in string.gmatch(l, "%S+") do table.insert(mat, tostring(q)) end
						if mat[1] == "Year" then
							self.startyear = tonumber(mat[2])
							self.years = tonumber(mat[2])
							self.maxyears = self.maxyears+self.startyear
						elseif mat[1] == "Disable" then
							local sEvent = mat[2]
							for q=3,#mat do sEvent = sEvent.." "..mat[q] end
							self.disabled["!"..sEvent:lower()] = true
						elseif mat[1] == "C" then
							local nl = Country:new()
							nl.name = mat[2]
							for q=3,#mat do nl.name = nl.name.." "..mat[q] end
							for q=1,#self.systems do nl.snt[self.systems[q].name] = 0 end
							nl.system = -1
							self.thisWorld:add(nl)
							fc = nl
						elseif mat[1] == "R" then
							local r = Region:new()
							r.name = mat[2]
							for q=3,#mat do r.name = r.name.." "..mat[q] end
							fc.regions[r.name] = r
							fr = r
						elseif mat[1] == "S" then
							local s = City:new()
							s.name = mat[2]
							for q=3,#mat do s.name = s.name.." "..mat[q] end
							fr.cities[s.name] = s
						elseif mat[1] == "P" then
							local s = City:new()
							s.name = mat[2]
							for q=3,#mat do s.name = s.name.." "..mat[q] end
							fc.capitalregion = fr.name
							fc.capitalcity = s.name
							fr.cities[s.name] = s
						else
							local dynastic = false
							local number = 1
							local gend = "Male"
							local to = self.years
							if #fc.rulers > 0 then for i=1,#fc.rulers do if fc.rulers[i].name == mat[2] and fc.rulers[i].title == mat[1] then number = number+1 end end end
							if mat[1] == "Prime" then if mat[2] == "Minister" then
								mat[1] = "Prime Minister"
								for i=2,#mat-1 do mat[i] = mat[i+1] end
								mat[#mat] = nil
							end end
							if mat[1] == "King" then dynastic = true end
							if mat[1] == "Emperor" then dynastic = true end
							if mat[1] == "Queen" then dynastic = true end
							if mat[1] == "Empress" then dynastic = true end
							if dynastic then table.insert(fc.rulers, {title=mat[1], name=mat[2], number=tostring(number), From=mat[3], To=mat[4], Country=fc.name})
							else table.insert(fc.rulers, {title=mat[1], name=mat[2], surname=mat[3], number=mat[3], From=mat[4], To=mat[5], Country=fc.name}) end
							if mat[1] == "King" then
								local oldsystem = fc.system
								fc.system = 1
								if oldsystem ~= fc.system then fc.snt[self.systems[fc.system].name] = fc.snt[self.systems[fc.system].name]+1 end
							end
							if mat[1] == "President" then
								local oldsystem = fc.system
								fc.system = 2
								if oldsystem ~= fc.system then fc.snt[self.systems[fc.system].name] = fc.snt[self.systems[fc.system].name]+1 end
							end
							if mat[1] == "Prime Minister" then
								local oldsystem = fc.system
								fc.system = 3
								if oldsystem ~= fc.system then fc.snt[self.systems[fc.system].name] = fc.snt[self.systems[fc.system].name]+1 end
							end
							if mat[1] == "Premier" then
								local oldsystem = fc.system
								fc.system = 4
								if oldsystem ~= fc.system then fc.snt[self.systems[fc.system].name] = fc.snt[self.systems[fc.system].name]+1 end
							end
							if mat[1] == "Emperor" then
								local oldsystem = fc.system
								fc.system = 5
								if oldsystem ~= fc.system then fc.snt[self.systems[fc.system].name] = fc.snt[self.systems[fc.system].name]+1 end
							end
							if mat[1] == "Queen" then
								local oldsystem = fc.system
								fc.system = 1
								if oldsystem ~= fc.system then fc.snt[self.systems[fc.system].name] = fc.snt[self.systems[fc.system].name]+1 end
								gend = "Female"
							end
							if mat[1] == "Empress" then
								local oldsystem = fc.system
								fc.system = 5
								if oldsystem ~= fc.system then fc.snt[self.systems[fc.system].name] = fc.snt[self.systems[fc.system].name]+1 end
								gend = "Female"
							end
							local found = false
							for i, cp in pairs(fc.rulernames) do if cp == mat[2] then found = true end end
							for i, cp in pairs(fc.frulernames) do if cp == mat[2] then found = true end end
							if not found then
								if gend == "Female" then
									table.insert(fc.frulernames, mat[2])
								else
									table.insert(fc.rulernames, mat[2])
								end
							end
						end
					end
				end
				
				self:getAlphabeticalCountries()
				
				printf(self.stdscr, "Constructing initial populations...\n")
				local cCount = 0
				local cDone = 0
				
				for i, cp in pairs(self.thisWorld.countries) do cCount = cCount+1 end

				for i, cp in pairs(self.thisWorld.countries) do
					if cp then
						if #cp.rulers > 0 then
							cp.founded = tonumber(cp.rulers[1].From)
							cp.age = self.years-cp.founded
						else
							cp.founded = self.years
							cp.age = 0
							cp.system = math.random(1, #self.systems)
							cp.snt[self.systems[cp.system].name] = cp.snt[self.systems[cp.system].name]+1
						end

						cp:makename(self, 3)
						cp:setPop(self, 500)

						table.insert(self.final, cp)
					end
					
					cDone = cDone+1
					printl(self.stdscr, "Country %d/%d", cDone, cCount)
				end

				self.thisWorld.fromFile = true
			end,

			generationString = function(self, n, gen)
				local msgout = ""

				if n > 1 then
					if n > 2 then
						if n > 3 then
							if n > 4 then msgout = tostring(n-2).."-times-great-grand"
							else msgout = "great-great-grand" end
						else msgout = "great-grand" end
					else msgout = "grand" end
				end
				
				if gen == "Male" then msgout = msgout.."son" else msgout = msgout.."daughter" end

				return msgout
			end,

			getAllyOngoing = function(self, country, target, event)
				local acOut = {}

				local ac = #country.alliances
				for i=1,ac do
					local c3 = nil
					for j, cp in pairs(self.thisWorld.countries) do if cp.name == country.alliances[i] then c3 = cp end end

					if c3 then for j=#c3.allyOngoing,1,-1 do if c3.allyOngoing[j] == event.."?"..country.name..":"..target.name then table.insert(acOut, c3) end end end
				end

				return acOut
			end,

			getAlphabeticalCountries = function(self)
				if self.showinfo == 1 then
					local cKeys = {}
					local alphaOrder = {a=1, b=2, c=3, d=4, e=5, f=6, g=7, h=8, i=9, j=10, k=11, l=12, m=13, n=14, o=15, p=16, q=17, r=18, s=19, t=20, u=21, v=22, w=23, x=24, y=25, z=26}
					for i, cp in pairs(self.thisWorld.countries) do
						if #cKeys ~= 0 then
							local found = false
							for j=1,#cKeys do if not found then
								local ind = 1
								local chr1 = alphaOrder[cKeys[j]:sub(ind, ind):lower()]
								local chr2 = alphaOrder[i:sub(ind, ind):lower()]
								while chr2 == chr1 do
									ind = ind+1
									chr1 = alphaOrder[cKeys[j]:sub(ind, ind):lower()]
									chr2 = alphaOrder[i:sub(ind, ind):lower()]
								end
								if not chr1 then
									table.insert(cKeys, j+1, i)
									found = true
								elseif not chr2 then
									table.insert(cKeys, j, i)
									found = true
								elseif chr2 < chr1 then
									table.insert(cKeys, j, i)
									found = true
								end
							end end
							if not found then table.insert(cKeys, i) end
						else table.insert(cKeys, i) end
					end

					self.alpha = cKeys
				end
			end,

			getRulerString = function(self, data)
				local rString = ""
				if data then
					rString = data.title
					
					if data.royalName and data.royalName ~= "" then rString = rString.." "..data.royalName else rString = rString.." "..data.name end

					if tonumber(data.number) and tonumber(data.number) ~= 0 then
						rString = rString.." "..self:roman(data.number)
						if data.surname then rString = rString.." ("..data.surname..")" end
					elseif data.surname then rString = rString.." "..data.surname end
					
					if data.Country then rString = rString.." of "..data.Country.." ("..tostring(data.From).." - "..tostring(data.To)..")"
					else rString = rString.." of "..data.nationality end
				else rString = "None" end

				return rString
			end,

			loop = function(self)
				local _running = true
				local msg = ""

				printf(self.stdscr, "\nBegin Simulation!")

				while _running do
					self.thisWorld:update(self)

					for i, cp in pairs(self.thisWorld.countries) do
						for j, k in pairs(self.final) do if k.name == cp.name then self.final[j] = nil end end
						table.insert(self.final, cp)
					end

					msg = string.format("Year %d: %d countries\n\n", self.years, self.numCountries)

					if self.showinfo == 1 then
						local currentEvents = {}
						local cCount = 0
						local cLimit = 14
						local eCount = 0
						local eLimit = 4
						if cursesstatus then
							cLimit = math.floor(curses:lines()/2)
							eLimit = (curses:lines()-cLimit)-9
						end

						for i=1,#self.alpha do
							local cp = self.thisWorld.countries[self.alpha[i]]
							if cp then
								for j=1,#cp.ongoing do table.insert(currentEvents, cp.ongoing[j].eString) end
							
								if cCount <= cLimit then
									if cp.snt[self.systems[cp.system].name] > 1 then msg = msg..string.format("%s ", self:ordinal(cp.snt[self.systems[cp.system].name])) end
									local sysName = self.systems[cp.system].name
									if cp.dfif[sysName] then msg = msg..string.format("%s %s", cp.demonym, cp.formalities[self.systems[cp.system].name]) else msg = msg..string.format("%s of %s", cp.formalities[self.systems[cp.system].name], cp.name) end
									msg = msg..string.format(" - Population %d - %s\n", cp.population, self:getRulerString(cp.rulers[#cp.rulers]))
									cCount = cCount+1
								end
							end
						end

						if cCount < self.numCountries then msg = msg..string.format("[+%d more]\n", self.numCountries-cCount) end
						
						msg = msg..string.format("\nOngoing events:")

						for i=1,#currentEvents do
							if eCount <= eLimit then
								msg = msg..string.format("\n%s", currentEvents[i])
								eCount = eCount+1
							end
						end
						
						if eCount < #currentEvents then msg = msg..string.format("\n[+%d more]", #currentEvents-eCount)
						elseif eCount == 0 then msg = msg..string.format("\nNone") end
						
						msg = msg.."\n"
					end

					self.years = self.years+1
					if self.years > self.maxyears then
						_running = false
					end
					
					self:clearTerm()
					for sx in msg:gsub("\n\n", "\n \n"):gmatch("%C+\n") do printc(self.stdscr, sx) end
					if cursesstatus then self.stdscr:refresh() end
				end

				self:finish()

				printf(self.stdscr, "\nEnd Simulation!")
			end,

			name = function(self, personal, l)
				local nom = ""
				local length = 0
				if not l then length = math.random(2, 3) else length = math.random(1, l) end

				local taken = {}

				nom = self:randomChoice(self.initialgroups)
				table.insert(taken, nom:lower())

				local groups = 1

				while groups < length do
					local mid = ""
					local istaken = true
					
					while istaken do
						istaken = false
						mid = self:randomChoice(self.middlegroups)
						for i=1,#taken do if taken[i] == mid:lower() then istaken = true end end
					end

					nom = nom..mid:lower()
					groups = groups+1
					table.insert(taken, mid:lower())
				end

				if not personal then
					local ending = self:randomChoice(self.endgroups)
					nom = nom..ending:lower()
				end

				nom = self:namecheck(nom)

				if nom:len() == 1 then nom = nom..string.lower(self:randomChoice(self.vowels)) end

				return nom
			end,

			namecheck = function(self, nom)
				local nomin = nom
				local check = true
				while check do
					check = false
					local nomlower = nomin:lower()

					for i=1,nomlower:len()-1 do
						if string.lower(nomlower:sub(i, i)) == string.lower(nomlower:sub(i+1, i+1)) then
							local newnom = ""

							for j=1,i do newnom = newnom..nomlower:sub(j, j) end
							for j=i+2,nomlower:len() do newnom = newnom..nomlower:sub(j, j) end

							nomlower = newnom
						end
					end

					for i=1,nomlower:len()-2 do
						if string.lower(nomlower:sub(i, i)) == string.lower(nomlower:sub(i+2, i+2)) then
							local newnom = ""

							for j=1,i+1 do newnom = newnom..nomlower:sub(j, j) end

							newnom = newnom..self:randomChoice(self.consonants)

							for j=i+3,nomlower:len() do newnom = newnom..nomlower:sub(j, j) end

							nomlower = newnom
						end
					end

					for i=1,nomlower:len()-3 do
						if string.lower(nomlower:sub(i, i+1)) == string.lower(nomlower:sub(i+2, i+3)) then
							local newnom = ""

							for j=1,i+1 do newnom = newnom..nomlower:sub(j, j) end
							for j=i+4,nomlower:len() do newnom = newnom..nomlower:sub(j, j) end

							nomlower = newnom
						end
					end

					for i=1,nomlower:len()-5 do
						if string.lower(nomlower:sub(i, i+2)) == string.lower(nomlower:sub(i+3, i+5)) then
							local newnom = ""

							for j=1,i+2 do newnom = newnom..nomlower:sub(j, j) end

							for j=i+6,nomlower:len() do newnom = newnom..nomlower:sub(j, j) end

							nomlower = newnom
						end
					end

					for i=1,nomlower:len()-2 do
						local hasvowel = false

						for j=i,i+2 do
							for k=1,#self.vowels do if string.lower(nomlower:sub(j, j)) == self.vowels[k] then hasvowel = true end end

							if j > 1 then -- Make an exception for the 'th' group, but only if there's a vowel close by.
								if string.lower(nomlower:sub(j-1, j-1)) == 't' and string.lower(nomlower:sub(j, j)) == 'h' then
									if j > 2 then
										local prev = nomlower:sub(j-2, j-2)
										for k=1,#self.vowels do if prev:lower() == self.vowels[k] then hasvowel = true end end
									end
								end
							end
						end

						if not hasvowel then
							local newnom = ""
							for j=1,i+1 do newnom = newnom..nomlower:sub(j, j) end
							newnom = newnom..self:randomChoice(self.vowels)
							for j=i+3,nomlower:len() do newnom = newnom..nomlower:sub(j, j) end
							nomlower = newnom
						end
					end

					nomlower = nomlower:gsub("aa", "a")
					nomlower = nomlower:gsub("ee", "i")
					nomlower = nomlower:gsub("ii", "i")
					nomlower = nomlower:gsub("oo", "u")
					nomlower = nomlower:gsub("uu", "u")
					nomlower = nomlower:gsub("ou", "o")
					nomlower = nomlower:gsub("kg", "g")
					nomlower = nomlower:gsub("gk", "g")
					nomlower = nomlower:gsub("sz", "s")
					nomlower = nomlower:gsub("ue", "e")
					nomlower = nomlower:gsub("zs", "z")
					nomlower = nomlower:gsub("rz", "z")
					nomlower = nomlower:gsub("dl", "l")
					nomlower = nomlower:gsub("tl", "l")
					nomlower = nomlower:gsub("cg", "c")
					nomlower = nomlower:gsub("gc", "g")
					nomlower = nomlower:gsub("tp", "t")
					nomlower = nomlower:gsub("dt", "t")
					nomlower = nomlower:gsub("td", "t")
					nomlower = nomlower:gsub("tc", "t")
					nomlower = nomlower:gsub("hc", "c")
					nomlower = nomlower:gsub("fd", "d")
					nomlower = nomlower:gsub("df", "d")
					nomlower = nomlower:gsub("ae", "a")
					nomlower = nomlower:gsub("gl", "l")
					nomlower = nomlower:gsub("bt", "b")
					nomlower = nomlower:gsub("tb", "t")
					nomlower = nomlower:gsub("ua", "a")
					nomlower = nomlower:gsub("oe", "e")
					nomlower = nomlower:gsub("pg", "g")
					nomlower = nomlower:gsub("db", "b")
					nomlower = nomlower:gsub("bd", "d")
					nomlower = nomlower:gsub("ui", "i")
					nomlower = nomlower:gsub("mt", "m")
					nomlower = nomlower:gsub("lt", "l")
					nomlower = nomlower:gsub("gj", "g")
					nomlower = nomlower:gsub("tn", "t")
					nomlower = nomlower:gsub("jz", "j")
					nomlower = nomlower:gsub("js", "j")
					nomlower = nomlower:gsub("zt", "t")
					nomlower = nomlower:gsub("gd", "d")
					nomlower = nomlower:gsub("dg", "g")
					nomlower = nomlower:gsub("jg", "j")
					nomlower = nomlower:gsub("gt", "t")
					nomlower = nomlower:gsub("jc", "j")
					nomlower = nomlower:gsub("hg", "g")
					nomlower = nomlower:gsub("tm", "t")
					nomlower = nomlower:gsub("oa", "a")
					nomlower = nomlower:gsub("cp", "c")
					nomlower = nomlower:gsub("pb", "b")
					nomlower = nomlower:gsub("tg", "t")
					nomlower = nomlower:gsub("bp", "b")
					nomlower = nomlower:gsub("iy", "y")
					nomlower = nomlower:gsub("yi", "y")
					nomlower = nomlower:gsub("fh", "f")
					nomlower = nomlower:gsub("uo", "o")
					nomlower = nomlower:gsub("vh", "v")
					nomlower = nomlower:gsub("vd", "v")
					nomlower = nomlower:gsub("ki", "ci")
					nomlower = nomlower:gsub("fv", "v")
					nomlower = nomlower:gsub("vf", "f")
					nomlower = nomlower:gsub("vt", "t")
					nomlower = nomlower:gsub("tv", "t")
					nomlower = nomlower:gsub("dk", "d")
					nomlower = nomlower:gsub("cd", "d")
					nomlower = nomlower:gsub("kd", "d")
					nomlower = nomlower:gsub("jd", "j")
					nomlower = nomlower:gsub("dj", "j")
					nomlower = nomlower:gsub("sj", "s")
					nomlower = nomlower:gsub("tj", "t")
					nomlower = nomlower:gsub("cj", "c")
					nomlower = nomlower:gsub("mj", "m")
					nomlower = nomlower:gsub("nj", "nch")
					nomlower = nomlower:gsub("hj", "h")
					nomlower = nomlower:gsub("fj", "f")
					nomlower = nomlower:gsub("kj", "k")
					nomlower = nomlower:gsub("vj", "v")
					nomlower = nomlower:gsub("wj", "w")
					nomlower = nomlower:gsub("pj", "p")
					nomlower = nomlower:gsub("jt", "t")
					nomlower = nomlower:gsub("jr", "dr")
					nomlower = nomlower:gsub("eu", "e")
					nomlower = nomlower:gsub("iu", "i")
					nomlower = nomlower:gsub("ia", "a")
					nomlower = nomlower:gsub("ea", "a")
					nomlower = nomlower:gsub("ai", "i")
					nomlower = nomlower:gsub("ei", "i")
					nomlower = nomlower:gsub("ie", "i")
					nomlower = nomlower:gsub("ao", "o")
					nomlower = nomlower:gsub("oi", "i")
					nomlower = nomlower:gsub("aia", "ia")
					nomlower = nomlower:gsub("eia", "ia")
					nomlower = nomlower:gsub("oia", "ia")
					nomlower = nomlower:gsub("uia", "ia")
					nomlower = nomlower:gsub("aie", "a")
					nomlower = nomlower:gsub("eie", "e")
					nomlower = nomlower:gsub("oie", "o")
					nomlower = nomlower:gsub("uie", "u")
					nomlower = nomlower:gsub("aio", "io")
					nomlower = nomlower:gsub("eio", "io")
					nomlower = nomlower:gsub("oio", "io")
					nomlower = nomlower:gsub("uio", "io")
					nomlower = nomlower:gsub("aiu", "a")
					nomlower = nomlower:gsub("eiu", "e")
					nomlower = nomlower:gsub("oiu", "o")
					nomlower = nomlower:gsub("uiu", "u")

					for j=1,#self.consonants do
						if nomlower:sub(1, 1) == self.consonants[j] then
							if nomlower:sub(2, 2) == "b" then nomlower = nomlower:sub(2, nomlower:len()) end
							if nomlower:sub(2, 2) == "c" then nomlower = nomlower:sub(2, nomlower:len()) end
							if nomlower:sub(2, 2) == "d" then nomlower = nomlower:sub(2, nomlower:len()) end
							if nomlower:sub(2, 2) == "f" then nomlower = nomlower:sub(2, nomlower:len()) end
							if nomlower:sub(2, 2) == "g" then nomlower = nomlower:sub(2, nomlower:len()) end
							if nomlower:sub(2, 2) == "j" then nomlower = nomlower:sub(2, nomlower:len()) end
							if nomlower:sub(2, 2) == "k" then nomlower = nomlower:sub(2, nomlower:len()) end
							if nomlower:sub(2, 2) == "m" then nomlower = nomlower:sub(2, nomlower:len()) end
							if nomlower:sub(2, 2) == "n" then nomlower = nomlower:sub(2, nomlower:len()) end
							if nomlower:sub(2, 2) == "p" then nomlower = nomlower:sub(2, nomlower:len()) end
							if nomlower:sub(2, 2) == "r" then nomlower = nomlower:sub(2, nomlower:len()) end
							if nomlower:sub(2, 2) == "s" then nomlower = nomlower:sub(2, nomlower:len()) end
							if nomlower:sub(2, 2) == "t" then nomlower = nomlower:sub(2, nomlower:len()) end
							if nomlower:sub(2, 2) == "v" then nomlower = nomlower:sub(2, nomlower:len()) end
							if nomlower:sub(2, 2) == "z" then nomlower = nomlower:sub(2, nomlower:len()) end
						end

						if nomlower:sub(nomlower:len(), nomlower:len()) == self.consonants[j] then
							if nomlower:sub(nomlower:len()-1, nomlower:len()-1) == "b" then nomlower = nomlower:sub(1, nomlower:len()-1) end
							if nomlower:sub(nomlower:len()-1, nomlower:len()-1) == "c" then nomlower = nomlower:sub(1, nomlower:len()-1) end
							if nomlower:sub(nomlower:len()-1, nomlower:len()-1) == "d" then nomlower = nomlower:sub(1, nomlower:len()-1) end
							if nomlower:sub(nomlower:len()-1, nomlower:len()-1) == "f" then nomlower = nomlower:sub(1, nomlower:len()-1) end
							if nomlower:sub(nomlower:len()-1, nomlower:len()-1) == "g" then nomlower = nomlower:sub(1, nomlower:len()-1) end
							if nomlower:sub(nomlower:len()-1, nomlower:len()-1) == "h" then nomlower = nomlower:sub(1, nomlower:len()-1) end
							if nomlower:sub(nomlower:len()-1, nomlower:len()-1) == "j" then nomlower = nomlower:sub(1, nomlower:len()-1) end
							if nomlower:sub(nomlower:len()-1, nomlower:len()-1) == "k" then nomlower = nomlower:sub(1, nomlower:len()-1) end
							if nomlower:sub(nomlower:len()-1, nomlower:len()-1) == "m" then nomlower = nomlower:sub(1, nomlower:len()-1) end
							if nomlower:sub(nomlower:len()-1, nomlower:len()-1) == "n" then nomlower = nomlower:sub(1, nomlower:len()-1) end
							if nomlower:sub(nomlower:len()-1, nomlower:len()-1) == "p" then nomlower = nomlower:sub(1, nomlower:len()-1) end
							if nomlower:sub(nomlower:len()-1, nomlower:len()-1) == "r" then nomlower = nomlower:sub(1, nomlower:len()-1) end
							if nomlower:sub(nomlower:len()-1, nomlower:len()-1) == "s" then nomlower = nomlower:sub(1, nomlower:len()-1) end
							if nomlower:sub(nomlower:len()-1, nomlower:len()-1) == "t" then nomlower = nomlower:sub(1, nomlower:len()-1) end
							if nomlower:sub(nomlower:len()-1, nomlower:len()-1) == "v" then nomlower = nomlower:sub(1, nomlower:len()-1) end
							if nomlower:sub(nomlower:len()-1, nomlower:len()-1) == "w" then nomlower = nomlower:sub(1, nomlower:len()-1) end
							if nomlower:sub(nomlower:len()-1, nomlower:len()-1) == "z" then nomlower = nomlower:sub(1, nomlower:len()-1) end
						end
					end

					if nomlower ~= string.lower(nomin) then check = true end

					nomin = string.upper(nomlower:sub(1, 1))
					nomin = nomin..nomlower:sub(2, nomlower:len())
					nomin = nomin:gsub("%-(%w)", string.upper)
				end

				return nomin
			end,

			ordinal = function(self, n)
				local tmp = tonumber(n)
				if not tmp then return n end
				local fin = ""

				local ts = tostring(n)
				if ts:sub(ts:len(), ts:len()) == "1" then
					if ts:sub(ts:len()-1, ts:len()-1) == "1" then fin = ts.."th"
					else fin = ts.."st" end
				elseif ts:sub(ts:len(), ts:len()) == "2" then
					if ts:sub(ts:len()-1, ts:len()-1) == "1" then fin = ts.."th"
					else fin = ts.."nd" end
				elseif ts:sub(ts:len(), ts:len()) == "3" then
					if ts:sub(ts:len()-1, ts:len()-1) == "1" then fin = ts.."th"
					else fin = ts.."rd" end
				else fin = ts.."th" end

				return fin
			end,

			randomChoice = function(self, t, doKeys)
				local keys = {}
				for key, value in pairs(t) do table.insert(keys, key) end
				if #keys == 0 then return nil end
				if #keys == 1 then if doKeys then return keys[1] else return t[keys[1]] end end
				local index = keys[math.random(1, #keys)]
				if doKeys then return index else return t[index] end
			end,

			RegionTransfer = function(self, c1, c2, r, conq)
				if c1 and c2 then
					local rCount = 0
					for i, j in pairs(c2.regions) do rCount = rCount+1 end

					local lim = 1
					if conq then lim = 0 end

					if rCount > lim then
						if c2.regions[r] then
							local rn = c2.regions[r]

							for i=#c2.people,1,-1 do if c2.people[i] and c2.people[i].region == rn.name and not c2.people[i].isruler then c1:add(self, c2.people[i]) end end

							c1.regions[rn.name] = rn
							c2.regions[rn.name] = nil

							if not conq then
								if c2.capitalregion == rn.name then
									local msg = "Capital moved from "..c2.capitalcity.." to "

									c2.capitalregion = self:randomChoice(c2.regions).name
									c2.capitalcity = self:randomChoice(c2.regions[c2.capitalregion].cities, true)

									msg = msg..c2.capitalcity
									c2:event(self, msg)
								end
							end

							local gainMsg = "Gained the "..rn.name.." region "
							local lossMsg = "Loss of the "..rn.name.." region "

							local cCount = 0
							for i, j in pairs(rn.cities) do cCount = cCount+1 end
							if cCount > 0 then
								gainMsg = gainMsg.."(including the "
								lossMsg = lossMsg.."(including the "

								if cCount > 1 then
									if cCount == 2 then
										gainMsg = gainMsg.."cities of "
										lossMsg = lossMsg.."cities of "
										local index = 1
										for i, j in pairs(rn.cities) do
											if index ~= cCount then
												gainMsg = gainMsg..j.name.." "
												lossMsg = lossMsg..j.name.." "
											end
											index = index+1
										end
										index = 1
										for i, j in pairs(rn.cities) do
											if index == cCount then
												gainMsg = gainMsg.."and "..j.name
												lossMsg = lossMsg.."and "..j.name
											end
											index = index+1
										end
									else
										gainMsg = gainMsg.."cities of "
										lossMsg = lossMsg.."cities of "
										local index = 1
										for i, j in pairs(rn.cities) do
											if index < cCount-1 then
												gainMsg = gainMsg..j.name..", "
												lossMsg = lossMsg..j.name..", "
											end
											index = index+1
										end
										index = 1
										for i, j in pairs(rn.cities) do
											if index == cCount-1 then
												gainMsg = gainMsg..j.name.." "
												lossMsg = lossMsg..j.name.." "
											end
											index = index+1
										end
										index = 1
										for i, j in pairs(rn.cities) do
											if index == cCount then
												gainMsg = gainMsg.."and "..j.name
												lossMsg = lossMsg.."and "..j.name
											end
											index = index+1
										end
									end
								else
									for i, j in pairs(rn.cities) do
										gainMsg = gainMsg.."city of "..j.name
										lossMsg = lossMsg.."city of "..j.name
									end
								end

								gainMsg = gainMsg..") "
								lossMsg = lossMsg..") "
							end

							gainMsg = gainMsg.."from "..c2.name
							lossMsg = lossMsg.."to "..c1.name

							c1:event(self, gainMsg)
							c2:event(self, lossMsg)
						end
					end
				end
			end,

			removeAllyOngoing = function(self, country, target, event)
				local ac = #country.alliances
				for i=1,ac do
					local c3 = nil
					for j, cp in pairs(self.thisWorld.countries) do if cp.name == country.alliances[i] then c3 = cp end end

					if c3 then for j=#c3.allyOngoing,1,-1 do if c3.allyOngoing[j] == event.."?"..country.name..":"..target.name then table.remove(c3.allyOngoing, j) end end end
				end
			end,

			roman = function(self, n)
				local tmp = tonumber(n)
				if not tmp then return n end
				local fin = ""

				while tmp-1000 > -1 do
					fin = fin.."M"
					tmp = tmp-1000
				end

				while tmp-900 > -1 do
					fin = fin.."CM"
					tmp = tmp-900
				end

				while tmp-500 > -1 do
					fin = fin.."D"
					tmp = tmp-500
				end

				while tmp-400 > -1 do
					fin = fin.."CD"
					tmp = tmp-400
				end

				while tmp-100 > -1 do
					fin = fin.."C"
					tmp = tmp-100
				end

				while tmp-90 > -1 do
					fin = fin.."XC"
					tmp = tmp-90
				end

				while tmp-50 > -1 do
					fin = fin.."L"
					tmp = tmp-50
				end

				while tmp-40 > -1 do
					fin = fin.."XL"
					tmp = tmp-40
				end

				while tmp-10 > -1 do
					fin = fin.."X"
					tmp = tmp-10
				end

				while tmp-9 > -1 do
					fin = fin.."IX"
					tmp = tmp-9
				end

				while tmp-5 > -1 do
					fin = fin.."V"
					tmp = tmp-5
				end

				while tmp-4 > -1 do
					fin = fin.."IV"
					tmp = tmp-4
				end

				while tmp-1 > -1 do
					fin = fin.."I"
					tmp = tmp-1
				end

				return fin
			end,

			rseed = function(self)
				self:sleep(0.005)
				local tc = _time()
				local ts = tostring(tc)
				local n = tonumber(ts:reverse())
				if not n then n = _time() end
				while n < 100000 do n = n*math.floor(math.random(5, math.random(12, 177000))) end
				while n > 1000000000 do n = n/math.floor(math.random(5, math.random(12, 177000))) end
				math.randomseed(math.ceil(n))
				for i=1,3 do math.random(1, 100) end
			end,

			savetable = function(self, t, f)
				local types = {["string"]=1, ["number"]=2, ["boolean"]=3, ["table"]=4, ["function"]=5}
				local exceptions = {"__index", "stdscr"}

				if not t.mtname then f:write("5nilmt") else
					f:write(t.mtname:len())
					f:write(t.mtname)
				end

				local iCount = 0
				for i, j in pairs(t) do
					found = false
					for k=1,#exceptions do if exceptions[k] == tostring(i) then found = true end end
					if not found then iCount = iCount+1 end
				end

				f:write(tostring(iCount):len())
				f:write(tostring(iCount))

				for i, j in pairs(t) do
					local found = false
					for k=1,#exceptions do if exceptions[k] == tostring(i) then found = true end end
					if not found then 
						local itype = types[type(i)]
						f:write(itype)

						f:write(tostring(i:len()):len())
						f:write(tostring(i):len())
						f:write(tostring(i))

						local jtype = type(j)
						f:write(types[jtype])

						if jtype == "table" then
							self:savetable(j, f)
						elseif jtype == "function" then
							fndata = string.dump(j)
							f:write(tostring(fndata:len()):len())
							f:write(fndata:len())
							f:write(fndata)
						elseif jtype == "boolean" then
							if not j then f:write("0") else f:write("1") end
						else
							f:write(tostring(tostring(j):len()):len())
							f:write(tostring(j):len())
							f:write(tostring(j))
						end
					end
				end
			end,

			setGens = function(self, i, v, g)
				if i then
					local set = i.gensSet
					i.gensSet = true
					if g ~= 1 and v < 0 then i.royalDescendant = true end
					if not set then
						if v > -1 and v < i.royalGenerations then i.royalGenerations = v end
						if i.royalDescendant and v < 0 then i.royalGenerations = -2 end
						if g ~= 1 then for j, k in pairs(i.children) do self:setGens(k, v+1, 1) end end
						if i.royalGenerations == -2 then self:setGens(i.father, -2, 0) elseif not d then self:setGens(i.father, v-1, 1) end
						if i.royalGenerations == -2 then self:setGens(i.mother, -2, 0) elseif not d then self:setGens(i.mother, v-1, 1) end
					end
					i.gensSet = false
				end
			end,

			setGensChildren = function(self, t, v, a)
				if t.royalGenerations > v then
					t.royalGenerations = v
					t.LastRoyalAncestor = a
				end
				if t.children then for i, j in pairs(t.children) do self:setGensChildren(j, v+1, a) end end
			end,

			sleep = function(self, t)
				local n = _time()
				while _time() < n+t do end
			end,

			sortAscendants = function(self)
				local fams = {}
				local count = 0
				local done = 0
				local removed = 0

				for i, j in pairs(self.royals) do count = count+1 end
				
				printf(self.stdscr, "Assigning relevancy...")
				for i, j in pairs(self.royals) do
					if j.number ~= 0 then j.royalGenerations = 0 end
					if j.royalGenerations == 0 then self:setGens(j, 0, 0) end
					done = done+1
					printl(self.stdscr, "%.2f%% done.", ((done/count*10000)/100))
				end

				printf(self.stdscr, "Filtering irrelevant individuals...")
				done = 0

				for i, j in pairs(self.royals) do
					if j.royalGenerations > self.genLimit or j.royalGenerations == -1 then
						j.removed = true
						removed = removed+1
					end

					done = done+1
					printl(self.stdscr, "%.2f%% done.", ((done/count*10000)/100))
				end

				local oldCount = count
				count = count-removed
				printf(self.stdscr, "\nTrimmed %d irrelevant individuals, out of %d.", removed, oldCount)

				done = 0
				printf(self.stdscr, "Linking %d individuals...", count)

				for i, j in pairs(self.royals) do
					if not j.removed then
						j.title = j.RulerTitle

						if j.father and j.mother then if not j.father.removed and not j.mother.removed then
							local parentString = j.father.gString.."-"..j.mother.gString

							if not fams[parentString] then
								fams[parentString] = {fIndex=0, husb=j.father, wife=j.mother, chil={j}}
								table.insert(j.father.fams, fams[parentString])
								table.insert(j.mother.fams, fams[parentString])
								table.insert(j.famc, fams[parentString])
							else
								local ind = 1
								for k=1,#fams[parentString].chil do if tonumber(fams[parentString].chil[k].birth) <= tonumber(j.birth) then ind = k+1 end end
								table.insert(fams[parentString].chil, ind, j)
								table.insert(j.famc, fams[parentString])
							end
						end end
						
						done = done+1
						printl(self.stdscr, "%.2f%% done.", ((done/count*10000)/100))
					end
				end

				printf(self.stdscr, "\nRemoving unlinked individuals...")
				done = 0

				for i, j in pairs(self.royals) do if not j.removed then
					if #j.fams == 0 and #j.famc == 0 then j.removed = true end
					
					done = done+1
					printl(self.stdscr, "%.2f%% done.", ((done/count*10000)/100))
				end end

				return fams
			end,

			strengthFactor = function(self, c)
				local pop = 0
				if c.rulerParty ~= "" and c.parties[c.rulerParty] then pop = c.parties[c.rulerParty].popularity-50 end
				return (pop+(c.stability-50)+((c.military/#c.people)*100))
			end
		}

		return CCSCommon
	end
