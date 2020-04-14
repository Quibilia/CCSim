return
	function()
		local Country = {
			new = function(self)
				local o = {}
				setmetatable(o, self)

				o.age = 0
				o.agPrim = false -- Agnatic primogeniture; if true, only a male person may rule this country while under a dynastic system.
				o.alliances = {}
				o.allyOngoing = {}
				o.averageAge = 0
				o.birthrate = 3
				o.capitalcity = ""
				o.capitalregion = ""
				o.civilWars = 0
				o.demonym = ""
				o.dfif = {} -- Demonym First In Formality; i.e. instead of "Republic of China", use "Chinese Republic"
				o.ethnicities = {}
				o.events = {}
				o.formalities = {}
				o.founded = 0
				o.frulernames = {}
				o.hasRuler = -1
				o.language = nil
				o.lineOfSuccession = {}
				o.majority = ""
				o.military = 0
				o.milThreshold = 5
				o.name = ""
				o.nodes = {}
				o.ongoing = {}
				o.parties = {}
				o.people = {}
				o.population = 0
				o.regions = {}
				o.relations = {}
				o.ruler = nil
				o.rulernames = {}
				o.rulerParty = nil
				o.rulerPopularity = 0
				o.rulers = {}
				o.snt = {} -- System, number of Times; i.e. 'snt["Monarchy"] = 1' indicates the country has been a monarchy once, or is presently in its first monarchy.
				o.stability = 50
				o.strength = 0
				o.system = 0

				return o
			end,

			add = function(self, parent, n)
				if not n then return end

				if parent.thisWorld.countries[n.nationality] and parent.thisWorld.countries[n.nationality] and parent.thisWorld.countries[n.nationality].people then
					for i=1,#parent.thisWorld.countries[n.nationality].people do parent.thisWorld.countries[n.nationality].people[i].pIndex = i end
					if n.pIndex > 0 then
						table.remove(parent.thisWorld.countries[n.nationality].people, n.pIndex)
						for i=n.pIndex,#parent.thisWorld.countries[n.nationality].people do parent.thisWorld.countries[n.nationality].people[i].pIndex = i end
					end
				end
				n.nationality = self.name
				n.region = nil
				n.city = nil
				n.level = 2
				n.title = "Citizen"
				n.military = false
				n.isRuler = false
				n.parentRuler = false
				if n.spouse then
					if parent.thisWorld.countries[n.spouse.nationality] and parent.thisWorld.countries[n.spouse.nationality].people and parent.thisWorld.countries[n.spouse.nationality].people[n.spouse.pIndex] and parent.thisWorld.countries[n.spouse.nationality].people[n.spouse.pIndex].gString == n.spouse.gString then
						if n.spouse.pIndex > 0 then
							table.remove(parent.thisWorld.countries[n.spouse.nationality].people, n.spouse.pIndex)
							for i=n.spouse.pIndex,#parent.thisWorld.countries[n.spouse.nationality].people do parent.thisWorld.countries[n.spouse.nationality].people[i].pIndex = i end
						end
					end
					n.spouse.nationality = self.name
					n.spouse.region = nil
					n.spouse.city = nil
					n.spouse.level = 2
					n.spouse.title = "Citizen"
					n.spouse.military = false
					n.spouse.isRuler = false
					n.spouse.parentRuler = false
					table.insert(self.people, n.spouse)
					n.spouse.pIndex = #self.people
				end
				table.insert(self.people, n)
				n.pIndex = #self.people
				self.population = #self.people
			end,

			borders = function(self, parent, other)
				if not other or not other.nodes or type(other.nodes) ~= "table" then return 0 end
				local selfWater = false
				local otherWater = false

				for i=1,#self.nodes do
					local x, y, z = table.unpack(self.nodes[i])
					if parent.thisWorld.planet[x][y][z].country == self.name then
						if parent.thisWorld.planet[x][y][z].waterNeighbors then selfWater = true end
						for j=1,#parent.thisWorld.planet[x][y][z].neighbors do
							local nx, ny, nz = table.unpack(parent.thisWorld.planet[x][y][z].neighbors[j])
							if parent.thisWorld.planet[nx][ny][nz].country == other.name or parent.thisWorld.planet[nx][ny][nz].region == other.name then return 1 end
						end
					end
				end

				for i=1,#other.nodes do
					local x, y, z = table.unpack(other.nodes[i])
					if parent.thisWorld.planet[x][y][z].country == other.name or parent.thisWorld.planet[x][y][z].region == other.name then
						if parent.thisWorld.planet[x][y][z].waterNeighbors then otherWater = true end
						for j=1,#parent.thisWorld.planet[x][y][z].neighbors do
							local nx, ny, nz = table.unpack(parent.thisWorld.planet[x][y][z].neighbors[j])
							if parent.thisWorld.planet[nx][ny][nz].country == self.name then return 1 end
						end
					end
				end

				if selfWater and otherWater then return 1 end
				return 0
			end,

			checkCapital = function(self, parent)
				local oldcap = self.capitalcity
				local oldreg = self.capitalregion

				if not self.capitalregion or not self.regions[self.capitalregion] or not self.capitalcity or not self.regions[self.capitalregion].cities[self.capitalcity] then
					self.capitalregion = parent:randomChoice(self.regions, true)
					self.capitalcity = nil
				end

				if not self.capitalcity then
					self.capitalcity = parent:randomChoice(self.regions[self.capitalregion].cities, true)
					if oldcap and self.regions[oldreg] and self.regions[oldreg].cities[oldcap] then self:event(parent, "Capital moved from "..oldcap.." to "..self.capitalcity) end
				end
			end,

			checkRuler = function(self, parent, enthrone)
				if self.hasRuler == -1 then
					self.ruler = nil
					if #self.rulers > 0 and tostring(self.rulers[#self.rulers].To) == "Current" and self.rulers[#self.rulers].Country == self.name then self.rulers[#self.rulers].To = parent.years end

					if #self.people > 1 then
						for i=1,#self.people do if self.people[i] and self.people[i].def then
							self.people[i].pIndex = i
							self.people[i].isRuler = false
						end end

						while self.hasRuler == -1 do
							if parent.systems[self.system].dynastic then
								if #self.lineOfSuccession == 0 then
									local p = math.random(1, #self.people)
									self:setRuler(parent, p, enthrone)
								else
									local p = table.remove(self.lineOfSuccession, 1)
									if p.nationality ~= self.name then self:add(parent, p) end
									self:setRuler(parent, p.pIndex, enthrone)
								end
							else
								local p = math.random(1, #self.people)
								self:setRuler(parent, p, enthrone)
							end
						end
					end
				end
			end,

			delete = function(self, parent, y)
				if self.people and #self.people > 0 and self.people[y] then
					local z = table.remove(self.people, y)
					z:destroy(parent, self)
					z = nil
					self.population = self.population-1
				end
			end,

			destroy = function(self, parent)
				if self.people then for i, j in pairs(self.people) do self:delete(parent, i) end end
				self.people = nil

				if self.parties then for i, j in pairs(self.parties) do j = nil end end
				self.parties = nil

				if self.ongoing then for i=#self.ongoing,1,-1 do self.ongoing[i] = nil end end
				self.ongoing = nil

				parent:deepnil(self.alliances)
				parent:deepnil(self.allyOngoing)
				parent:deepnil(self.ethnicities)
				parent:deepnil(self.relations)
				self.alliances = nil
				self.allyOngoing = nil
				self.ethnicities = nil
				self.relations = nil

				for i, j in pairs(parent.final) do if j.name == self.name then parent.final[i] = nil end end
				parent.final[self.name] = self
			end,

			event = function(self, parent, e)
				table.insert(self.events, {Event=e:gsub(" of ,", ","):gsub(" of the ,", ","):gsub("  ", " "), Year=parent.years})
			end,

			eventloop = function(self, parent)
				local t0 = _time()

				if #self.people == 0 then
					for i=#self.ongoing,1,-1 do table.remove(self.ongoing, i) end
					return
				end

				local v = math.ceil(math.random(30, 90)*self.stability)
				local vi = math.ceil(math.random(30, 90)*(101-self.stability))
				if v < 1 then v = 1 end
				if vi < 1 then vi = 1 end

				if not self.ongoing then self.ongoing = {} end
				if not self.relations then
					self.relations = {}
					for i, j in pairs(parent.thisWorld.countries) do if j.name ~= self.name then self.relations[j.name] = 50 end end
				end

				for i=#self.ongoing,1,-1 do if not self.ongoing[i] or not self.ongoing[i].doStep or self.ongoing[i]:doStep(parent, self) == -1 then table.remove(self.ongoing, i) end end

				for i=1,#parent.c_events do
					if not parent.disabled[parent.c_events[i].name:lower()] and not parent.disabled["!"..parent.c_events[i].name:lower()] then
						local chance = 0
						if parent.c_events[i].inverse then chance = math.floor(math.random(1, vi)) else chance = math.floor(math.random(1, v)) end
						if chance <= parent.c_events[i].chance then self:triggerEvent(parent, i) end
					end
				end

				if _DEBUG then
					if not debugTimes["Country.eventloop"] then debugTimes["Country.eventloop"] = 0 end
					debugTimes["Country.eventloop"] = debugTimes["Country.eventloop"]+_time()-t0
				end
			end,

			makename = function(self, parent)
				if not self.name or self.name == "" then
					local found = true
					while found do
						self.name = parent:name(false, 2)
						found = false
						for i, j in pairs(parent.final) do if j.name == self.name or j.name:gsub("h", "") == self.name or j.name == self.name:gsub("h", "") then found = true end end
					end
				end

				if #self.rulernames < 1 then
					local rn = math.random(5, 9)
					for k=1,rn do table.insert(self.rulernames, parent:name(true)) end
				end

				if #self.frulernames < 1 then
					local rn = math.random(5, 9)
					for k=1,rn do table.insert(self.frulernames, parent:name(true)) end
				end

				for i=1,#parent.systems do
					self.formalities[parent.systems[i].name] = parent:randomChoice(parent.systems[i].formalities)
					self.dfif[parent.systems[i].name] = parent:randomChoice({true, false})
				end

				self.demonym = parent:demonym(self.name)
			end,

			recurseRoyalChildren = function(self, t, n)
				if not t.children or #t.children == 0 then return nil end
				
				local ind = n+1
				if ind > #self.lineOfSuccession+1 then ind = #self.lineOfSuccession end
				if ind == 0 then ind = 1 end

				local childrenByAge = {}
				local hasMale = false

				for i=1,#t.children do
					local found = false
					for j=1,#childrenByAge do if not found and t.children[i].birth <= childrenByAge[j].birth then
						table.insert(childrenByAge, j, t.children[i])
						found = true
					end end
					if not found then table.insert(childrenByAge, t.children[i]) end
					if t.children[i].gender == "M" then hasMale = true end
				end
				
				if not hasMale and not self.agPrim then for i=#childrenByAge,1,-1 do if not childrenByAge[i].isRuler and childrenByAge[i].rulerName == "" and childrenByAge[i].nationality == self.name and not childrenByAge[i].inSuccession and childrenByAge[i].def then
					childrenByAge[i].inSuccession = true
					self:recurseRoyalChildren(childrenByAge[i], n)
					table.insert(self.lineOfSuccession, ind, childrenByAge[i])
				end end
				else
					if not self.agPrim then
						for i=#childrenByAge,1,-1 do if childrenByAge[i].gender == "F" and not childrenByAge[i].isRuler and childrenByAge[i].rulerName == "" and childrenByAge[i].nationality == self.name and not childrenByAge[i].inSuccession and childrenByAge[i].def then
							childrenByAge[i].inSuccession = true
							self:recurseRoyalChildren(childrenByAge[i], n)
							table.insert(self.lineOfSuccession, ind, childrenByAge[i])
						end end
					end
					for i=#childrenByAge,1,-1 do if childrenByAge[i].gender == "M" and not childrenByAge[i].isRuler and childrenByAge[i].rulerName == "" and childrenByAge[i].nationality == self.name and not childrenByAge[i].inSuccession and childrenByAge[i].def then
						childrenByAge[i].inSuccession = true
						self:recurseRoyalChildren(childrenByAge[i], n)
						table.insert(self.lineOfSuccession, ind, childrenByAge[i])
					end end
				end
			end,

			set = function(self, parent)
				parent:rseed()

				self.system = math.random(1, #parent.systems)
				self:makename(parent)
				self.agPrim = parent:randomChoice({true, false})

				if self.population <= 1 then if _DEBUG then self:setPop(parent, 150) else self:setPop(parent, math.random(750, 1500)) end end

				local rcount = 0
				for i, j in pairs(self.regions) do rcount = rcount+1 end
				if rcount == 0 then
					rcount = math.random(3, 6)
					for i=1,rcount do
						local r = Region:new()
						r:makename(self, parent)
						self.regions[r.name] = r
					end
				end

				self.capitalregion = parent:randomChoice(self.regions, true)
				self.capitalcity = parent:randomChoice(self.regions[self.capitalregion].cities, true)

				if self.founded == 0 then self.founded = parent.years end

				if not self.snt[parent.systems[self.system].name] or self.snt[parent.systems[self.system].name] == -1 then self.snt[parent.systems[self.system].name] = 0 end
				self.snt[parent.systems[self.system].name] = self.snt[parent.systems[self.system].name]+1
				self:event(parent, "Establishment of the "..parent:ordinal(self.snt[parent.systems[self.system].name]).." "..self.demonym.." "..self.formalities[parent.systems[self.system].name])
			end,

			setPop = function(self, parent, u)
				if u < 100 then return end

				while #self.people > u do
					local r = math.random(1, #self.people)
					if #self.people > 1 then while self.people[r].isRuler do r = math.random(1, #self.people) end end
					self:delete(parent, r)
				end
				
				if not parent.gedFile then parent.gedFile = io.open(parent:directory({parent.stamp, "ged.dat"}), "a+") end

				for i=1,u-#self.people do
					local n = Person:new()
					n:makename(parent, self)
					n.age = math.random(16, 80)
					n.birth = parent.years-n.age
					if n.birth < 1 then n.birth = n.birth-1 end
					n.level = 2
					n.title = "Citizen"
					n.ethnicity = {[self.demonym]=100}
					n.birthplace = self.name
					n.gString = n.gender.." "..n.name.." "..n.surname.." "..n.birth.." "..n.birthplace
					n.gIndex = parent:nextGIndex()
					parent.gedFile:write(tostring(n.gIndex).." b "..tostring(n.birth).."\n")
					parent.gedFile:write(tostring(n.gIndex).." c "..tostring(n.birthplace).."\n")
					parent.gedFile:write(tostring(n.gIndex).." g "..tostring(n.gender).."\n")
					parent.gedFile:write(tostring(n.gIndex).." n "..tostring(n.name).."\n")
					parent.gedFile:write(tostring(n.gIndex).." s "..tostring(n.surname).."\n")
					parent.gedFile:flush()
					self:add(parent, n)
				end
			end,

			setRuler = function(self, parent, newRuler, enthrone)
				self.people[newRuler].prevtitle = self.people[newRuler].title
				self.people[newRuler].level = #parent.systems[self.system].ranks
				self.people[newRuler].title = parent.systems[self.system].ranks[self.people[newRuler].level]
				self.rulerParty = self.parties[self.people[newRuler].party]

				parent:rseed()

				if self.people[newRuler].gender == "F" then
					if parent.systems[self.system].dynastic then self.people[newRuler].rulerName = parent:randomChoice(self.frulernames) end
					if parent.systems[self.system].franks then
						self.people[newRuler].level = #parent.systems[self.system].franks
						self.people[newRuler].title = parent.systems[self.system].franks[self.people[newRuler].level]
					end
				else if parent.systems[self.system].dynastic then self.people[newRuler].rulerName = parent:randomChoice(self.rulernames) end end

				self.hasRuler = 0
				self.ruler = self.people[newRuler]
				self.people[newRuler].isRuler = true
				self.people[newRuler].ruledCountry = self.name
				self.people[newRuler].rulerTitle = self.people[newRuler].title
				self.people[newRuler].inSuccession = false

				if parent.systems[self.system].dynastic then
					local namenum = 1
					for i=1,#self.rulers do if self.rulers[i].dynastic and self.rulers[i].Country == self.name and self.rulers[i].name == self.people[newRuler].rulerName then namenum = namenum+1 end end

					if enthrone and self.people[newRuler].royalGenerations < math.huge and self.people[newRuler].royalGenerations > 0 then self:event(parent, "Enthronement of "..self.people[newRuler].rulerTitle.." "..self.people[newRuler].rulerName.." "..parent:roman(namenum).." of "..self.name..", "..parent:generationString(self.people[newRuler].royalGenerations, self.people[newRuler].gender).." of "..self.people[newRuler].LastRoyalAncestor) end

					self.people[newRuler].number = namenum
					self.people[newRuler].maternalLineTimes = 0
					self.people[newRuler].royalSystem = parent.systems[self.system].name
					self.people[newRuler].royalGenerations = 0
					self.people[newRuler].LastRoyalAncestor = ""
					self.people[newRuler].gString = self.people[newRuler].gender.." "..self.people[newRuler].name.." "..self.people[newRuler].surname.." "..self.people[newRuler].birth.." "..self.people[newRuler].birthplace

					self:recurseRoyalChildren(self.people[newRuler], 0)

					table.insert(self.rulers, {dynastic=true, name=self.people[newRuler].rulerName, title=self.people[newRuler].rulerTitle, surname=self.people[newRuler].surname, number=tostring(self.people[newRuler].number), children=self.people[newRuler].children, From=parent.years, To="Current", Country=self.name, Party=self.people[newRuler].party})
				else
					table.insert(self.rulers, {dynastic=false, name=self.people[newRuler].name, title=self.people[newRuler].rulerTitle, surname=self.people[newRuler].surname, number=self.people[newRuler].surname, children=self.people[newRuler].children, From=parent.years, To="Current", Country=self.name, Party=self.people[newRuler].party})
				end

				parent.writeMap = true
			end,

			setTerritory = function(self, parent, patron, patronRegion)
				parent:deepnil(self.nodes)
				self.nodes = {}

				for i=1,#parent.thisWorld.planetdefined do
					local x, y, z = table.unpack(parent.thisWorld.planetdefined[i])
					if parent.thisWorld.planet[x][y][z].country == self.name then
						table.insert(self.nodes, {x, y, z})
						parent.thisWorld.planet[x][y][z].region = ""
						parent.thisWorld.planet[x][y][z].regionSet = false
						parent.thisWorld.planet[x][y][z].regionDone = false
					end
				end

				local rCount = 0
				local maxR = math.ceil(#self.nodes/35)
				for i, j in pairs(self.regions) do rCount = rCount+1 end

				while rCount > maxR or rCount > #self.nodes do
					local r = parent:randomChoice(self.regions, true)
					self.regions[r] = nil
					rCount = rCount-1
				end

				local defined = 0

				for i, j in pairs(self.regions) do
					local found = false
					for k=1,#self.nodes do
						local x, y, z = table.unpack(self.nodes[k])
						if parent.thisWorld.planet[x][y][z].region == j.name then
							found = true
							defined = defined+1
						end
						if found then k = #self.nodes+1 end
					end

					if not found then
						local sFound = nil
						while not sFound do
							local pd = parent:randomChoice(self.nodes)
							local x, y, z = table.unpack(pd)
							if parent.thisWorld.planet[x][y][z].region == "" or parent.thisWorld.planet[x][y][z].region == j.name then sFound = parent.thisWorld.planet[x][y][z] end
						end

						sFound.region = j.name
						defined = defined+1
					end
				end

				local allDefined = false
				local prevDefined = defined

				while not allDefined do
					for i=1,#self.nodes do
						local x, y, z = table.unpack(self.nodes[i])

						if parent.thisWorld.planet[x][y][z].region ~= "" and not parent.thisWorld.planet[x][y][z].regionSet and not parent.thisWorld.planet[x][y][z].regionDone then
							for j=1,#parent.thisWorld.planet[x][y][z].neighbors do
								local neighbor = parent.thisWorld.planet[x][y][z].neighbors[j]
								local nx, ny, nz = table.unpack(neighbor)
								if parent.thisWorld.planet[nx][ny][nz].country == self.name and parent.thisWorld.planet[nx][ny][nz].region == "" then
									parent.thisWorld.planet[nx][ny][nz].region = parent.thisWorld.planet[x][y][z].region
									parent.thisWorld.planet[nx][ny][nz].regionSet = true
									defined = defined+1
								end
							end
							parent.thisWorld.planet[x][y][z].regionDone = true
						end
					end

					for i=1,#self.nodes do
						local x, y, z = table.unpack(self.nodes[i])
						parent.thisWorld.planet[x][y][z].regionSet = false
					end

					if defined == prevDefined then allDefined = true end
					prevDefined = defined
				end

				for i=#self.nodes,1,-1 do
					local x, y, z = table.unpack(self.nodes[i])

					if parent.thisWorld.planet[x][y][z].region == "" or not self.regions[parent.thisWorld.planet[x][y][z].region] then
						if not patron then
							parent.thisWorld.planet[x][y][z].country = ""
							parent.thisWorld.planet[x][y][z].land = false
						else
							parent.thisWorld.planet[x][y][z].country = patron.name
							parent.thisWorld.planet[x][y][z].region = patronRegion.name
							table.insert(patron.nodes, {x, y, z})
							table.insert(patronRegion.nodes, {x, y, z})
						end
						local rn = table.remove(self.nodes, i)
						parent:deepnil(rn)
					else table.insert(self.regions[parent.thisWorld.planet[x][y][z].region].nodes, {x, y, z}) end
				end

				if not patron then for i, j in pairs(self.regions) do
					local cCount = 0
					local maxC = math.ceil(#j.nodes/25)
					for k, l in pairs(j.cities) do cCount = cCount+1 end

					while cCount > maxC or cCount > #j.nodes do
						local c = parent:randomChoice(j.cities, true)
						local r = j.cities[c]
						local x = r.x
						local y = r.y
						local z = r.z
						if r.x and r.y and r.z then parent.thisWorld.planet[x][y][z].city = "" end
						j.cities[c] = nil
						cCount = cCount-1
					end
				end end

				for i, j in pairs(self.regions) do
					for k, l in pairs(j.cities) do
						if not patron then
							for m=1,#self.nodes do
								local x, y, z = table.unpack(self.nodes[m])
								if parent.thisWorld.planet[x][y][z].city == l.name then
									l.x = x
									l.y = y
									l.z = z
									m = #self.nodes+1
								end
							end

							if not l.x or not l.y or not l.z then
								local pd = parent:randomChoice(j.nodes)
								local x, y, z = table.unpack(pd)
								local cFound = false
								while not cFound do
									pd = parent:randomChoice(j.nodes)
									x, y, z = table.unpack(pd)
									if parent.thisWorld.planet[x][y][z].city == "" or parent.thisWorld.planet[x][y][z].city == l.name then cFound = true end
								end

								l.x = x
								l.y = y
								l.z = z
							end

							parent.thisWorld.planet[l.x][l.y][l.z].city = l.name
						else j.cities[k] = nil end
					end
				end
			end,

			triggerEvent = function(self, parent, i, r, o)
				local newE = parent:deepcopy(parent.c_events[i])
				table.insert(self.ongoing, newE)

				if parent.c_events[i].args == 1 then
					if not newE.performEvent or newE:performEvent(parent, self) == -1 then table.remove(self.ongoing, #self.ongoing)
					else newE:beginEvent(parent, self) end
				elseif parent.c_events[i].args == 2 and parent.thisWorld.numCountries > 1 then
					local other = nil
					if r then other = o else
						other = parent:randomChoice(parent.thisWorld.countries)
						while other.name == self.name do other = parent:randomChoice(parent.thisWorld.countries) end
					end

					if self.ongoing then
						local res = -1
						if newE.performEvent then res = newE:performEvent(parent, self, other, r) end
						if not self.ongoing then return end
						if res == -1 then table.remove(self.ongoing, #self.ongoing)
						else newE:beginEvent(parent, self, other) end
					end
				end
			end,

			update = function(self, parent)
				local t0 = _time()
				parent:rseed()

				for i=1,#parent.systems do if not self.snt[parent.systems[i].name] or self.snt[parent.systems[i].name] == -1 then self.snt[parent.systems[i].name] = 0 end end
				self.stability = self.stability+(math.random()-0.2)+math.random(-2, 2)
				if self.stability > 100 then self.stability = 100 end
				if self.stability < 1 then self.stability = 1 end

				while math.floor(#self.people) > math.floor(parent.popLimit*3) do self:delete(parent, parent:randomChoice(self.people, true)) end

				self.averageAge = 0
				self.population = #self.people
				self.strength = 0
				self.military = 0
				self.hasRuler = -1
				self.rulerPopularity = 0
				self.age = parent.years-self.founded
				if self.founded < 1 then self.age = self.age-1 end
				if self.population < parent.popLimit then self.birthrate = 3
				else self.birthrate = 40 end
				for i, j in pairs(self.ethnicities) do self.ethnicities[i] = 0 end

				for i=#self.alliances,1,-1 do
					local found = false
					local ar = self.alliances[i]

					for j, cp in pairs(parent.thisWorld.countries) do if not found then
						local nr = cp.name
						if ar:len() >= nr:len() and ar:sub(1, #nr) == nr then found = true end
					end end

					if not found then table.remove(self.alliances, i) end
				end

				for i, cp in pairs(parent.thisWorld.countries) do if cp.name ~= self.name then
					if not self.relations then self.relations = {} end
					if not self.relations[cp.name] then self.relations[cp.name] = 50 end
					self.relations[cp.name] = self.relations[cp.name]+math.random(-3, 3)
					if self.relations[cp.name] < 1 then self.relations[cp.name] = 1
					elseif self.relations[cp.name] > 100 then self.relations[cp.name] = 100 end
				end end

				self:checkCapital(parent)

				if not self.language then self.language = parent:getLanguage(self.demonym, self) end

				for i, j in pairs(self.regions) do
					j.population = 0
					for k, l in pairs(j.cities) do l.population = 0 end
				end

				self.milThreshold = 5
				for i, j in pairs(parent.thisWorld.countries) do for k=1,#j.ongoing do if j.ongoing[k].name == "War" then
					if table.contains(j.ongoing[k], self) then self.milThreshold = 25 else
						local ao = parent:getAllyOngoing(j, j.ongoing[k].target, j.ongoing[k].name)
						if table.contains(ao, self) then self.milThreshold = 25 end
					end
				end end end

				for i=#self.people,1,-1 do
					local chn = false
					if self.people[i] and self.people[i].def then self.people[i]:update(parent, self) else chn = true end

					if not chn then
						local age = self.people[i].age
						if 70000-math.pow(age, 2) < 1 or math.random(1, 70000-math.pow(age, 2)) < math.pow(age, 2) then chn = true end
					end

					if not chn and not self.people[i].isRuler and math.random(1, 8000) == 3799 then
						local cp = parent:randomChoice(parent.thisWorld.countries)
						if parent.thisWorld.numCountries > 1 then while cp.name == self.name do cp = parent:randomChoice(parent.thisWorld.countries) end end
						cp:add(parent, self.people[i])
						chn = true
					end

					if not chn then
						self.people[i].pIndex = i
						self.averageAge = self.averageAge+self.people[i].age
						if self.people[i].military then self.military = self.military+1 end
						if self.people[i].isRuler then
							self.hasRuler = 0
							self.ruler = self.people[i]
							self.rulerParty = self.parties[self.people[i].party]
						end
					end

					if chn then self:delete(parent, i) end
				end

				self.averageAge = self.averageAge/#self.people
				self.rulerPopularity = self.rulerPopularity/(3*#self.people)

				if #self.people == 0 then
					self.averageAge = 100
					self.rulerPopularity = 100
				end

				self:checkRuler(parent, false)
				local largest = ""
				local largestN = 0
				for i, j in pairs(self.ethnicities) do
					self.ethnicities[i] = (self.ethnicities[i]/#self.people)*100
					if #self.people == 0 then self.ethnicities[i] = 1 end
					if j >= largestN then
						largest = i
						largestN = j
					end
				end
				self.majority = largest

				if math.fmod(parent.years, 100) == 0 then for i, j in pairs(self.regions) do parent:setLanguage(self, j, j.language:deviate(parent, 0.06)) end end

				if _DEBUG then
					if not debugTimes["Country.update"] then debugTimes["Country.update"] = 0 end
					debugTimes["Country.update"] = debugTimes["Country.update"]+_time()-t0
				end
			end
		}

		Country.__index = Country
		Country.__call = function() return Country:new() end

		return Country
	end
