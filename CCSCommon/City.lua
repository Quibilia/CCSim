return
	function()
		City = {
			new = function(self)
				c = {}
				setmetatable(c, self)
				
				c.name = ""
				c.population = 0
				c.x = nil
				c.y = nil
				c.z = nil
				
				return c
			end,
			
			makename = function(self, country, parent)
				self.name = parent:name(true, 7)
			end
		}
		
		City.__index = City
		City.__call = function() return City:new() end
		
		return City
	end