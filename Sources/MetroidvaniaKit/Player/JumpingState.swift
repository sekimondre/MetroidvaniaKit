import SwiftGodot

class JumpingState: PlayerState {
    
    var jumpTimestamp: UInt = 0
    
    func enter(_ player: PlayerNode) {
        jumpTimestamp = Time.getTicksMsec()
        player.sprite?.play(name: "jump-begin")
    }
    
    func update(_ player: PlayerNode, dt: Double) -> PlayerState? {
        
        // Horizontal Movement
        let direction = Input.getHorizontalAxis()
        var targetSpeed = player.speed * direction
        
        if player.isSpeedBoosting {
            targetSpeed *= 2
        }
        
        if Time.getTicksMsec() - player.wallJumpTimestamp > player.wallJumpThresholdMsec {
            if !direction.isZero {
                if (player.velocity.x >= 0 && direction > 0) || (player.velocity.x <= 0 && direction < 0) {
                    player.velocity.x = Float(GD.moveToward(from: Double(player.velocity.x), to: targetSpeed, delta: player.acceleration))
                } else {
                    player.velocity.x = Float(GD.moveToward(from: Double(player.velocity.x), to: targetSpeed, delta: player.deceleration))
                }
            } else {
                player.velocity.x = Float(GD.moveToward(from: Double(player.velocity.x), to: 0, delta: player.deceleration * 0.2))
            }
        }
        
        // Vertical Movement
        let airInterval = Time.getTicksMsec() - jumpTimestamp
        let airHeight = player.getJumpspeed() * Double(airInterval) / 1000
        
        if Input.isActionJustReleased(action: "ui_accept") && player.velocity.y < 0 { // stop jump mid-air
            player.velocity.y = 0
        }
        if Input.isActionPressed(action: "ui_accept") && airHeight < player.linearHeight && player.allowJumpSensitivity {
            // do nothing
        } else {
            player.velocity.y += Float(player.getGravity() * dt)
            
            var terminalVelocity = Float(player.getJumpspeed()) * player.terminalVelocityFactor
//            if isInWater {
//                terminalVelocity *= 0.2
//            }
            if player.velocity.y > terminalVelocity {
                player.velocity.y = terminalVelocity
            }
        }
        
        // Mid-air jump
        if Input.isActionJustPressed(.accept) && player.canDoubleJump && player.upgrades.hasDoubleJump {
            player.velocity.y = Float(-player.getJumpspeed())
            jumpTimestamp = Time.getTicksMsec()
            player.canDoubleJump = false
        }
        
        if abs(player.velocity.x) < Float(player.speed) {
            player.isSpeedBoosting = false
        }
        
        player.moveAndSlide()
        
        if player.raycastForWall() && Int(player.getWallNormal().sign().x) == -Int(direction) && player.upgrades.hasWallGrab {
            return WallGrabState()
        }
        
        if player.isOnFloor() {
            player.sprite?.play(name: "fall-land")
            return RunningState()
        }
        
        if abs(player.getRealVelocity().x) > Float(player.speed * 0.8) {
            player.sprite?.play(name: "jump-spin")
        } else {
            if Time.getTicksMsec() - player.lastShotTimestamp < 3000 {
                player.sprite?.play(name: "jump-aim")
            } else {
                player.sprite?.play(name: "jump-still")
            }
        }
        
        return nil
    }
}
