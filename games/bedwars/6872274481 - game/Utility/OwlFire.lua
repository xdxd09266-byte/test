local OwlFire = vape.Categories.Utility:CreateModule({
	Name = 'OwlFire',
	Function = function(callback)
		if callback then
			local remote = bedwars.Client:Get('OwlFireProjectile')
			local t = {
				fromPosition = entitylib.character.RootPart.Position
			}
			t.direction = Vector3.new(0, 9e9, 0)
			t.offset = nil
			t.ProjectileRefId = game:GetService('HttpService'):GenerateGUID(false)
			t.initialVelocity = Vector3.new(0, 9e9, 0)
			remote:SendToServer(t)
			vape:CreateNotification('OwlFire', 'Fired projectile', 3)
		end
	end,
	Tooltip = 'Fires a projectile at 9e9 velocity'
})
