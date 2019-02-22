return
	function()
		local Country = {
			new = function(self)
				local nl = {}
				setmetatable(nl, self)

				nl.name = ""
				nl.founded = 0
				nl.age = 0
				nl.hasruler = -1
				nl.people = {}
				nl.averageAge = 0
				nl.events = {}
				nl.rulerage = 0
				nl.relations = {}
				nl.rulers = {}
				nl.rulernames = {}
				nl.frulernames = {}
				nl.ongoing = {}
				nl.allyOngoing = {}
				nl.alliances = {}
				nl.system = 0
				nl.snt = {} -- System, number of Times; i.e. 'snt["Monarchy"] = 1' indicates the country has been a monarchy once.
				nl.formalities = {}
				nl.demonym = ""
				nl.dfif = {} -- Demonym First In Formality; i.e. instead of "Republic of China", use "Chinese Republic"
				nl.stability = 50
				nl.strength = 0
				nl.military = 0
				nl.population = 0
				nl.ethnicities = {}
				nl.majority = ""
				nl.birthrate = 3
				nl.regions = {}
				nl.parties = {}
				nl.rulerParty = ""
				nl.nodes = {}
				nl.civilWars = 0
				nl.capitalregion = ""
				nl.capitalcity = ""
				nl.mtname = "Country"

				return nl
			end,

			add = function(self, n)
				table.insert(self.people, n)
			end,

			checkRuler = function(self, parent)
				if self.hasruler == -1 then
					if #self.rulers > 0 then self.rulers[#self.rulers].To = parent.years end

					if #self.people > 1 then
						while self.hasruler == -1 do
							local possibles = {}
							local closest = -1
							local closestGens = 10000000
							local closestMats = 10000000
							local closestAge = -1
							local children = {}
							local hasMale = false
							local rString = ""
							local prl = self.rulers[#self.rulers]
							if #self.rulers > 0 then rString = prl.name.." "..prl.surname.." "..tostring(prl.number) end
							local sys = parent.systems[self.system]
							if sys.dynastic == true then
								for i=1,#self.people do
									if self.people[i].royalGenerations > 0 then
										local poss = false
										if self.people[i].royalGenerations == 1 then table.insert(possibles, i) poss = true end
										if poss == false then if self.people[i].age <= self.averageAge + 25 then table.insert(possibles, i) end end
									end
								end

								if #self.rulers > 0 then for i=1,#possibles do
									local c = possibles[i]
									local psp = self.people[c]
									local fString = psp.father.name.." "..psp.father.surname.." "..tostring(psp.father.number)
									local mString = psp.mother.name.." "..psp.mother.surname.." "..tostring(psp.mother.number)
									if fString == rString then 
										table.insert(children, c)
										if psp.gender == "Male" then hasMale = true end
									end
									if mString == rString then
										table.insert(children, c)
										if psp.gender == "Male" then hasMale = true end
									end
								end end

								if #children > 0 then
									for i=1,#children do
										local c = children[i]
										local psp = self.people[c]
										if psp.age >= closestAge then
											if psp.gender == "Female" then if hasMale == false then
												closest = c
												closestAge = psp.age
											end else
												closest = c
												closestAge = psp.age
											end
										end
									end
								else
									for i=1,#possibles do
										local c = possibles[i]
										local psp = self.people[c]
										if psp ~= nil then if psp.royalGenerations <= closestGens then
											if psp.maternalLineTimes <= closestMats then
												if psp.age >= closestAge then
													closest = c
													closestGens = psp.royalGenerations
													closestMats = psp.maternalLineTimes
													closestAge = psp.age
												end
											end
										end end
									end
								end

								if self.people[closest] == nil then
									local p = math.random(1, #self.people)
									if self.people[p].age <= self.averageAge + 25 then self:setRuler(parent, p) end
								else
									self:setRuler(parent, closest)
								end
							else
								local p = math.random(1, #self.people)
								if self.people[p].age <= self.averageAge + 25 then self:setRuler(parent, p) end
							end
						end
					end
				end
			end,

			delete = function(self, parent, y)
				if self.people ~= nil and #self.people > 0 then
					if self.people[y] ~= nil then
						self.people[y].death = parent.years
						self.people[y].deathplace = self.name
						self.people[y].chn = true
						parent:getAscendants(parent.royals, parent:makeAscendant(self.people[y]))
						w = table.remove(self.people, y)
						if w ~= nil then
							w:destroy()
							w = nil
						end
					end
				end
			end,

			destroy = function(self, parent)
				if self.people ~= nil then
					for i=1,#self.people do
						self:delete(parent, i)
					end
					self.people = nil
				end

				for i=#self.ongoing,1,-1 do table.remove(self.ongoing, i) end

				for i, j in pairs(parent.final) do if j.name == self.name then parent.final[i] = nil end end
				table.insert(parent.final, self)
			end,

			event = function(self, parent, e)
				table.insert(self.events, {Event=e:gsub(" of ,", ","):gsub(" of the ,", ","):gsub("  ", " "), Year=parent.years})
			end,

			eventloop = function(self, parent)
				local v = math.floor(math.random(300, 800) * math.floor(self.stability))
				local vi = math.floor(math.random(300, 800) * (100 - math.floor(self.stability)))
				if v < 1 then v = 1 end
				if vi < 1 then vi = 1 end

				if self.ongoing == nil then self.ongoing = {} end
				if self.relations == nil then self.relations = {} end

				for i=#self.ongoing,1,-1 do
					if self.ongoing[i] ~= nil then
						if self.ongoing[i].args > 1 then
							local found = false
							if self.ongoing[i].target ~= nil then if self.ongoing[i].target.name ~= nil then for j, k in pairs(parent.thisWorld.countries) do if k.name == self.ongoing[i].target.name then found = true end end end end
							if found == false then table.remove(self.ongoing, i) end
						end
					end
				end

				for i=#self.ongoing,1,-1 do
					if self.ongoing[i] ~= nil then
						if self.ongoing[i].doStep ~= nil then
							local r = self.ongoing[i]:doStep(parent, self)
							if r == -1 then
								local ro = table.remove(self.ongoing, i)
								ro = nil
							end
						else
							local ro = table.remove(self.ongoing, i)
							ro = nil
						end
					end
				end

				for i=1,#parent.c_events do
					local isDisabled = false
					for j=1,#parent.disabled do if parent.disabled[j] == parent.c_events[i].name then isDisabled = true end end
					if isDisabled == false then
						local chance = math.floor(math.random(1, v))
						if parent.c_events[i].inverse == true then chance = math.floor(math.random(1, vi)) end
						if chance <= parent.c_events[i].chance then
							self:triggerEvent(parent, i)
						end
					end
				end

				local revCount = 0

				for i=1,#self.events do
					if self.events[i].Year > parent.years - 50 then
						if self.events[i].Event:sub(1, 10) == "Revolution" then revCount = revCount + 1 end
					end
				end

				if revCount > 8 then
					self:event(parent, "Collapsed")
					for i, cp in pairs(parent.thisWorld.countries) do
						if cp.name == self.name then
							parent.thisWorld:delete(parent, cp)
						end
					end
				end
			end,

			makename = function(self, parent)
				if self.name == "" or self.name == nil then
					self.name = parent:name(false)
				end

				if #self.rulernames < 1 then
					for k=1,math.random(5, 9) do
						table.insert(self.rulernames, parent:name(true))
					end

					for k=1,math.random(5, 9) do
						table.insert(self.frulernames, parent:name(true))
					end
				end

				if #self.frulernames < 1 then
					for k=1,math.random(5, 9) do
						table.insert(self.frulernames, parent:name(true))
					end
				end

				for i=1,#parent.systems do
					self.formalities[parent.systems[i].name] = parent:randomChoice(parent.systems[i].formalities)
					tf = math.random(1, 100)
					if tf < 51 then self.dfif[parent.systems[i].name] = true else self.dfif[parent.systems[i].name] = false end
				end

				if self.name:sub(#self.name, #self.name) == "a" then self.demonym = self.name:sub(1, #self.name-1).."ian"
				elseif self.name:sub(#self.name, #self.name) == "y" then
					local split = self.name:sub(1, #self.name-1)
					if split:sub(#split, #split) == "y" then self.demonym = split:sub(1, #split-1)
					elseif split:sub(#split, #split) == "s" then self.demonym = split:sub(1, #split-1).."ian"
					elseif split:sub(#split, #split) == "b" then self.demonym = split.."ian"
					elseif split:sub(#split, #split) == "d" then self.demonym = split.."ish"
					elseif split:sub(#split, #split) == "f" then self.demonym = split.."ish"
					elseif split:sub(#split, #split) == "g" then self.demonym = split.."ian"
					elseif split:sub(#split, #split) == "h" then self.demonym = split.."ian"
					elseif split:sub(#split, #split) == "a" then self.demonym = split.."n"
					elseif split:sub(#split, #split) == "e" then self.demonym = split.."n"
					elseif split:sub(#split, #split) == "i" then self.demonym = split.."n"
					elseif split:sub(#split, #split) == "o" then self.demonym = split.."n"
					elseif split:sub(#split, #split) == "u" then self.demonym = split.."n"
					elseif split:sub(#split, #split) == "l" then self.demonym = split.."ish"
					elseif split:sub(#split, #split) == "k" then self.demonym = split:sub(1, #split-1).."cian"
					else self.demonym = split end
				elseif self.name:sub(#self.name, #self.name) == "e" then self.demonym = self.name:sub(1, #self.name-1).."ish"
				elseif self.name:sub(#self.name, #self.name) == "c" then self.demonym = self.name:sub(1, #self.name-2).."ian"
				elseif self.name:sub(#self.name, #self.name) == "s" then
					if self.name:sub(#self.name-2, #self.name) == "ius" then self.demonym = self.name:sub(1, #self.name-2).."an"
					else self.demonym = self.name:sub(1, #self.name-2).."ian" end
				elseif self.name:sub(#self.name, #self.name) == "i" then self.demonym = self.name.."an"
				elseif self.name:sub(#self.name, #self.name) == "o" then self.demonym = self.name:sub(1, #self.name-1).."ian"
				elseif self.name:sub(#self.name, #self.name) == "k" then self.demonym = self.name:sub(1, #self.name-1).."cian"
				elseif self.name:sub(#self.name-3, #self.name) == "land" then
					local split = self.name:sub(1, #self.name-4)
					if split:sub(#split, #split) == "a" then self.demonym = split.."n"
					elseif split:sub(#split, #split) == "y" then self.demonym = split:sub(1, #split-1)
					elseif split:sub(#split, #split) == "c" then self.demonym = split:sub(1, #split-1).."ian"
					elseif split:sub(#split, #split) == "s" then self.demonym = split:sub(1, #split-1).."ian"
					elseif split:sub(#split, #split) == "i" then self.demonym = split.."an"
					elseif split:sub(#split, #split) == "o" then self.demonym = split:sub(1, #split-1).."ian"
					elseif split:sub(#split, #split) == "g" then self.demonym = split.."lish"
					elseif split:sub(#split, #split) == "k" then self.demonym = split:sub(1, #split-1).."cian"
					else self.demonym = split.."ish" end
				else
					if self.name:sub(#self.name-1, #self.name) == "ia" then self.demonym = self.name.."n"
					elseif self.name:sub(#self.name-1, #self.name) == "an" then self.demonym = self.name.."ese"
					elseif self.name:sub(#self.name-1, #self.name) == "en" then self.demonym = self.name:sub(1, #self.name-2).."ian"
					elseif self.name:sub(#self.name-1, #self.name) == "un" then self.demonym = self.name:sub(1, #self.name-2).."ian"
					elseif self.name:sub(#self.name-2, #self.name) == "iar" then self.demonym = self.name:sub(1, #self.name-1).."n"
					elseif self.name:sub(#self.name-1, #self.name) == "ar" then self.demonym = self.name:sub(1, #self.name-2).."ian"
					elseif self.name:sub(#self.name-2, #self.name) == "ium" then self.demonym = self.name:sub(1, #self.name-2).."an"
					elseif self.name:sub(#self.name-1, #self.name) == "um" then self.demonym = self.name:sub(1, #self.name-2).."ian"
					elseif self.name:sub(#self.name-2, #self.name) == "ian" then self.demonym = self.name
					else self.demonym = self.name.."ian" end
				end

				for i=1,3 do
					self.demonym = self.demonym:gsub("ii", "i")
					self.demonym = self.demonym:gsub("aa", "a")
					self.demonym = self.demonym:gsub("uu", "u")
					self.demonym = self.demonym:gsub("yi", "i")
					self.demonym = self.demonym:gsub("iy", "i")
					self.demonym = self.demonym:gsub("ais", "is")
					self.demonym = self.demonym:gsub("eis", "is")
					self.demonym = self.demonym:gsub("iis", "is")
					self.demonym = self.demonym:gsub("ois", "is")
					self.demonym = self.demonym:gsub("uis", "is")
					self.demonym = self.demonym:gsub("aia", "ia")
					self.demonym = self.demonym:gsub("eia", "ia")
					self.demonym = self.demonym:gsub("iia", "ia")
					self.demonym = self.demonym:gsub("oia", "ia")
					self.demonym = self.demonym:gsub("uia", "ia")
				end

				local ends = {"ch", "rt", "gh", "ct", "rl", "rn", "rm", "rd", "rs", "lc", "ld", "ln", "lm", "ls", "sc", "nd", "nc", "st", "sh", "ds", "ck", "lg", "lk", "ng"}
				local hasend = false

				while hasend == false do
					local cEnd = self.demonym:sub(#self.demonym-1, #self.demonym)
					local cBegin = self.demonym:sub(1, #self.demonym-2)
					for i, j in pairs(ends) do if cEnd == j then hasend = true end end
					local c1 = cEnd:sub(1, 1)
					local c2 = cEnd:sub(2, 2)
					for i, j in pairs(parent.vowels) do if c1 == j then hasend = true elseif c2 == j then hasend = true end end
					if hasend == false then
						if c1 == "h" then self.demonym = cBegin..c2
						elseif c2 == "h" then self.demonym = cBegin..c1
						else self.demonym = cBegin..c1 end
					end
				end
			end,

			set = function(self, parent)
				parent:rseed()

				self.system = math.random(1, #parent.systems)
				self.population = math.random(1000, 2000)
				self:makename(parent, 3)

				for i=1,self.population do
					local n = Person:new()
					n:makename(parent, self)
					n.age = math.random(1, 20)
					n.birth = parent.years - n.age
					if n.birth < 1 then n.birth = n.birth - 1 end
					n.level = 2
					n.title = "Citizen"
					n.ethnicity = {[self.demonym]=100}
					n.nationality = self.name
					self:add(n)
				end

				local rcount = math.random(3, 8)
				for i=1,rcount do
					local r = Region:new()
					r:makename(self, parent)
					self.regions[r.name] = r
				end

				while self.capitalregion == "" do
					for i, j in pairs(self.regions) do
						local chance = math.random(1, 30)
						if chance == 15 then self.capitalregion = j.name end
					end
				end

				while self.capitalcity == "" do
					for i, j in pairs(self.regions[self.capitalregion].cities) do
						local chance = math.random(1, 30)
						if chance == 15 then self.capitalcity = j.name end
					end
				end

				self.founded = parent.years

				if self.snt[parent.systems[self.system].name] == nil or self.snt[parent.systems[self.system].name] == 0 then self.snt[parent.systems[self.system].name] = 1 end
				self:event(parent, "Establishment of the "..parent:ordinal(self.snt[parent.systems[self.system].name]).." "..self.demonym.." "..self.formalities[parent.systems[self.system].name])
			end,

			setPop = function(self, parent, u)
				self.population = u

				if #self.people > 1 then
					local r = math.random(1, #self.people)
					while self.people[r].isruler == true do r = math.random(1, #self.people) end
					self:delete(parent, r)
				end

				for i=1,self.population do
					local n = Person:new()
					n:makename(parent, self)
					n.level = 2
					n.title = "Citizen"
					n.ethnicity = {[self.demonym]=100}
					n.nationality = self.name
					self:add(n)
				end
			end,

			setRuler = function(self, parent, newRuler)
				for i=1,#self.people do self.people[i].isruler = false end

				self.people[newRuler].prevtitle = self.people[newRuler].title

				self.people[newRuler].level = #parent.systems[self.system].ranks
				self.people[newRuler].title = parent.systems[self.system].ranks[self.people[newRuler].level]

				parent:rseed()

				if self.people[newRuler].gender == "Female" then
					self.people[newRuler].royalName = parent:randomChoice(self.frulernames)

					if parent.systems[self.system].franks ~= nil then
						self.people[newRuler].level = #parent.systems[self.system].franks
						self.people[newRuler].title = parent.systems[self.system].franks[self.people[newRuler].level]
					end
				else
					self.people[newRuler].royalName = parent:randomChoice(self.rulernames)
				end

				local namenum = 1

				for i=1,#self.rulers do
					if tonumber(self.rulers[i].From) >= self.founded then
						if self.rulers[i].name == self.people[newRuler].royalName then
							if self.rulers[i].title == self.people[newRuler].title then
								namenum = namenum + 1
							end
						end
					end
				end

				if parent.systems[self.system].dynastic == true then
					self.people[newRuler].royalInfo.Gens=self.people[newRuler].royalGenerations
					self.people[newRuler].royalInfo.LastAncestor=self.people[newRuler].lastRoyalAncestor
					self.people[newRuler].royalGenerations = 0
					self.people[newRuler].maternalLineTimes = 0
					self.people[newRuler].royalSystem = parent.systems[self.system].name
					self.people[newRuler].number = namenum

					table.insert(self.rulers, {name=self.people[newRuler].royalName, title=self.people[newRuler].title, surname=self.people[newRuler].surname, number=tostring(self.people[newRuler].number), From=parent.years, To="Current", Country=self.name, Party=self.people[newRuler].party})

					for i, j in pairs(self.people[newRuler].children) do parent:setGensChildren(j, 1) end
				else
					table.insert(self.rulers, {name=self.people[newRuler].royalName, title=self.people[newRuler].title, surname=self.people[newRuler].surname, number=self.people[newRuler].surname, From=parent.years, To="Current", Country=self.name, Party=self.people[newRuler].party})
				end

				self.hasruler = 0
				self.people[newRuler].isruler = true
				self.rulerage = self.people[newRuler].age
				self.rulerParty = self.people[newRuler].party
			end,

			setTerritory = function(self, parent)
				self.nodes = {}

				for i=1,#parent.thisWorld.planetdefined do
					local x = parent.thisWorld.planetdefined[i][1]
					local y = parent.thisWorld.planetdefined[i][2]
					local z = parent.thisWorld.planetdefined[i][3]

					if parent.thisWorld.planet[x][y][z].country == self.name then table.insert(self.nodes, {x, y, z}) end
				end

				for i=1,#self.nodes do
					local x = self.nodes[i][1]
					local y = self.nodes[i][2]
					local z = self.nodes[i][3]

					parent.thisWorld.planet[x][y][z].region = ""
					parent.thisWorld.planet[x][y][z].city = ""
				end

				local rCount = 0
				for i, j in pairs(self.regions) do rCount = rCount + 1 end

				local maxR = math.ceil(#self.nodes / 35)

				while rCount > maxR do
					local r = parent:randomChoice(self.regions, true)
					self.regions[r] = nil
					rCount = 0
					for l, m in pairs(self.regions) do rCount = rCount + 1 end
				end

				for i, j in pairs(self.regions) do
					local x = 0
					local y = 0
					local z = 0

					local found = false
					while found == false do
						local pd = parent:randomChoice(self.nodes)
						x = pd[1]
						y = pd[2]
						z = pd[3]
						if parent.thisWorld.planet[x][y][z].region == "" then found = true end
					end

					parent.thisWorld.planet[x][y][z].region = j.name
				end

				local allDefined = false

				while allDefined == false do
					allDefined = true
					for i=1,#self.nodes do
						local x = self.nodes[i][1]
						local y = self.nodes[i][2]
						local z = self.nodes[i][3]

						if parent.thisWorld.planet[x][y][z].region ~= "" then
							for j=1,#parent.thisWorld.planet[x][y][z].neighbors do
								local neighbor = parent.thisWorld.planet[x][y][z].neighbors[j]
								local nx = neighbor[1]
								local ny = neighbor[2]
								local nz = neighbor[3]
								if parent.thisWorld.planet[nx][ny][nz].region == "" then
									allDefined = false
									if parent.thisWorld.planet[x][y][z].regionset == false then
										parent.thisWorld.planet[nx][ny][nz].region = parent.thisWorld.planet[x][y][z].region
										parent.thisWorld.planet[nx][ny][nz].regionset = true
									end
								end
							end
						end
					end

					for i=1,#self.nodes do
						local x = self.nodes[i][1]
						local y = self.nodes[i][2]
						local z = self.nodes[i][3]

						parent.thisWorld.planet[x][y][z].regionset = false
					end
				end

				for i=1,#self.nodes do
					local x = self.nodes[i][1]
					local y = self.nodes[i][2]
					local z = self.nodes[i][3]
					for j, k in pairs(self.regions) do
						if k.name == parent.thisWorld.planet[x][y][z].region then table.insert(k.nodes, {x, y, z}) end
					end
				end

				for i, j in pairs(self.regions) do
					local cCount = 0
					for k, l in pairs(j.cities) do cCount = cCount + 1 end

					local maxC = math.ceil(#j.nodes / 25)

					while cCount > maxC do
						local c = parent:randomChoice(j.cities, true)
						local r = j.cities[c]
						local x = r.x
						local y = r.y
						local z = r.z
						if r.x ~= nil and r.y ~= nil and r.z ~= nil then parent.thisWorld.planet[x][y][z].city = "" end
						j.cities[c] = nil
						cCount = 0
						for k, l in pairs(j.cities) do cCount = cCount + 1 end
					end
				end

				for i, j in pairs(self.regions) do
					for k, l in pairs(j.cities) do
						if l.x == nil or l.y == nil or l.z == nil then
							local pd = parent:randomChoice(j.nodes)
							local x = pd[1]
							local y = pd[2]
							local z = pd[3]

							while parent.thisWorld.planet[x][y][z].city ~= "" do
								pd = parent:randomChoice(j.nodes)
								x = pd[1]
								y = pd[2]
								z = pd[3]
							end

							l.x = x
							l.y = y
							l.z = z
						end

						parent.thisWorld.planet[l.x][l.y][l.z].city = l.name
					end
				end
			end,

			triggerEvent = function(self, parent, i)
				if parent.c_events[i].args == 1 then
					table.insert(self.ongoing, parent:deepcopy(parent.c_events[i]))
					local newE = self.ongoing[#self.ongoing]

					if newE.performEvent ~= nil then
						if newE:performEvent(parent, self) == -1 then table.remove(self.ongoing, #self.ongoing)
						else newE:beginEvent(parent, self) end
					else table.remove(self.ongoing, #self.ongoing) end
				elseif parent.c_events[i].args == 2 then
					if parent.numCountries > 1 then
						local other = parent:randomChoice(parent.thisWorld.countries)
						while other.name == self.name do other = parent:randomChoice(parent.thisWorld.countries) end

						table.insert(self.ongoing, parent:deepcopy(parent.c_events[i]))
						local newE = self.ongoing[#self.ongoing]

						if newE.performEvent ~= nil then
							if newE:performEvent(parent, self, other) == -1 then table.remove(self.ongoing, #self.ongoing)
							else newE:beginEvent(parent, self, other) end
						else
							table.remove(self.ongoing, #self.ongoing)
						end
					end
				end
			end,

			update = function(self, parent)
				parent:rseed()

				for i=1,#parent.systems do
					if self.snt[parent.systems[i].name] == nil then self.snt[parent.systems[i].name] = 0 end
				end

				self.stability = self.stability + math.random(-3, 3)
				if self.stability > 100 then self.stability = 100 end
				if self.stability < 1 then self.stability = 1 end

				self.age = self.age + 1
				self.averageAge = 0

				if #self.parties > 0 then
					for i=1,#self.parties do
						self.parties[i].membership = 0
						self.parties[i].popularity = 0
						self.parties[i].leading = false
					end
				end

				for i=#self.alliances,1,-1 do
					local found = false
					local ar = self.alliances[i]

					for j, cp in pairs(parent.thisWorld.countries) do
						local nr = cp.name
						if string.len(ar) >= string.len(nr) then
							if ar:sub(1, #nr) == nr then
								found = true
							end
						end
					end

					if found == false then
						local ra = table.remove(self.alliances, i)
						ra = nil
					end
				end

				for i, l in pairs(self.relations) do
					local found = false
					for j, cp in pairs(parent.thisWorld.countries) do
						if cp.name == self.name then found = true end
					end

					if found == false then
						self.relations[i] = nil
						i = nil
					end
				end

				for i, cp in pairs(parent.thisWorld.countries) do
					if cp.name ~= self.name then
						if self.relations[cp.name] == nil then
							self.relations[cp.name] = 40
						end
						local v = math.random(-4, 4)
						self.relations[cp.name] = self.relations[cp.name] + v
						if self.relations[cp.name] < 1 then self.relations[cp.name] = 1 end
						if self.relations[cp.name] > 100 then self.relations[cp.name] = 100 end
					end
				end

				self.population = #self.people
				self.strength = 0
				self.military = 0

				if self.population < parent.popLimit then
					self.birthrate = 3
				else
					self.birthrate = 75
				end

				while math.floor(#self.people) > math.floor(math.floor(parent.popLimit) * 5) do
					self:delete(parent, parent:randomChoice(self.people, true))
				end

				local oldcap = nil
				local oldreg = nil

				if self.regions[self.capitalregion] == nil then
					oldreg = self.capitalregion
					self.capitalregion = parent:randomChoice(self.regions).name
					oldcap = self.capitalcity
					self.capitalcity = nil
				end

				if self.capitalcity == nil or self.regions[self.capitalregion].cities[self.capitalcity] == nil then
					self.capitalcity = parent:randomChoice(self.regions[self.capitalregion].cities).name
					if oldcap ~= nil then
						if self.regions[oldreg] ~= nil then
							if self.regions[oldreg].cities[oldcap] ~= nil then self:event(parent, "Capital moved from "..oldcap.." to "..self.capitalcity) end
						end
					end
				end

				for i, j in pairs(self.regions) do
					j.population = 0
					for k, l in pairs(j.cities) do
						l.population = 0
					end
				end

				for i, j in pairs(self.ethnicities) do self.ethnicities[i] = 0 end

				self:checkRuler(parent)
				self.hasruler = -1

				for i, j in pairs(self.people) do
					if j.chn == false then self.people[i]:update(parent, self) end

					if j.chn == false then
						local age = self.people[i].age
						if age > 100 then
							self:delete(parent, i)
						else
							d = math.random(1, 3000-(age*3))
							if d < age then self:delete(parent, i) end
						end
					end

					if j.chn == false and j.isruler == false then
						local mChance = math.random(1, 35000)
						if mChance == 3799 then
							local cp = parent:randomChoice(parent.thisWorld.countries)
							if #parent.thisWorld.countries > 1 then while cp.name == self.name do cp = parent:randomChoice(parent.thisWorld.countries) end end
							j.region = ""
							j.city = ""
							j.nationality = cp.name
							j.military = false
							if j.spouse ~= nil then j.spouse = nil end
							table.remove(self.people, i)
							table.insert(cp.people, j)
							for k, l in pairs(self.people) do l.chn = false end
						end
					end

					if j.chn == false then
						self.averageAge = self.averageAge + self.people[i].age
						if self.people[i].military == true then self.military = self.military + 1 end
						if self.people[i].isruler == true then
							self.hasruler = 0
							self.rulerage = self.people[i].age
							self.rulerParty = self.people[i].party
						end
					end

					j.chn = false
				end

				self:checkRuler(parent)

				if #self.parties > 0 then
					for i=#self.parties,1,-1 do
						self.parties[i].popularity = math.floor(self.parties[i].popularity)
					end

					local largest = -1

					for i=1,#self.parties do
						if largest == -1 then largest = i end
						if self.parties[i].membership > self.parties[largest].membership then largest = i end
					end

					if largest ~= -1 then self.parties[largest].leading = true end
				end

				self.averageAge = self.averageAge / #self.people

				for i, j in pairs(self.ethnicities) do self.ethnicities[i] = (self.ethnicities[i] / #self.people) * 100 end

				local largest = ""
				local largestN = 0
				for i, j in pairs(self.ethnicities) do if j >= largestN then largest = i end end
				self.majority = largest
			end
		}

		Country.__index = Country
		Country.__call = function() return Country:new() end

		return Country
	end