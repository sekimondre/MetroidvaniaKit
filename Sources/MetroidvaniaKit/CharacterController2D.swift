import SwiftGodot

@Godot
class CharacterController2D: CharacterBody2D {
    
    @SceneTree(path: "AnimationPlayer") var animationPlayer: AnimationPlayer?
    @SceneTree(path: "Sprite2D") var sprite: Sprite2D?
    
    @Export
    var speed: Double = 180.0
    @Export
    var acceleration: Double = 10.0
    @Export
    var deceleration: Double = 80.0
    
    @Export var allowJumpSensitivity: Bool = true
    
    @Export var jumpDuration: Double = 0.5
    
    @Export var linearHeight: Double = 20
    @Export var parabolicHeight: Double = 48
    
//    @Export var terminalVelocity: Float = 400
    @Export var terminalVelocityFactor: Float = 1.3
    
//    var gravity: Double = Double(ProjectSettings.getSetting(name: "physics/2d/default_gravity", defaultValue: Variant(0.0))) ?? 0.0
//    var animation: StringName = ""
    
    @Export var airTime: Double = 0
    
    @Export var wallJumpThresholdMsec: Int = 500
    
    var jumpTimestamp: UInt = 0
    var wallJumpTimestamp: UInt = 0
    
    var isGrabbingWall = false
    
    var startRunningTimestamp: UInt = 0
    var speedBoostThreshold = 3000
    
    var canDoubleJump = true
    
    let playerHeight: Float = 28.0
    
    var facingDirection: Int = 1
    
    var hook: HookHitbox?
    
    var shotOrigin: Vector2 {
        Vector2(x: Float((7 + 3) * facingDirection), y: -playerHeight * 0.75)
    }
    
    override func _ready() {
        motionMode = .grounded
        floorBlockOnWall = false
        slideOnCeiling = false // doesnt work on this movement model
        GD.print("Floor block on wall: \(floorBlockOnWall)")
        GD.print("Slide on ceiling: \(slideOnCeiling)")
//        floorSnapLength = 4.0
        collisionMask = 0b1011
    }
    
    override func _physicsProcess(delta: Double) {
        //        if isInEvent { return }
        
        let lastDirX = Int(getLastMotion().sign().x)
        if lastDirX != 0 && lastDirX != facingDirection {
            facingDirection = lastDirX
        }
        
        if isHooking {
            velocity.y = 0
            guard let hook else { return }
            if abs(hook.position.x - position.x) <= 4 + 14 + 1 {
                isHooking = false
                hook.destroy()
                self.hook = nil
            } else {
                velocity.x = (hook.position - position).normalized().x * 900
                moveAndSlide()
                return
            }
        }
        
        if Input.isActionJustPressed(action: "action_1") {
            let hook = HookHitbox()
            hook.position.x = 7 - 4
            hook.position.y = -playerHeight * 0.5
            hook.zIndex = -1
            hook.direction = facingDirection
            addChild(node: hook)
            hook.player = self
            self.hook = hook
        }
        
        if Input.isActionJustPressed(action: "action_2") {
            normalShot()
        }
        
        let gravity = 8 * parabolicHeight / (jumpDuration * jumpDuration)
        let jumpSpeed = isInWater ? (2 * parabolicHeight * gravity).squareRoot() * 0.7 : (2 * parabolicHeight * gravity).squareRoot()
        
        let direction = Input.getAxis(negativeAction: "ui_left", positiveAction: "ui_right")
        
        
        if isOnWallOnly() && Int(getWallNormal().sign().x) == -Int(direction) {
            isGrabbingWall = true
        } else {
            isGrabbingWall = false
        }
        
        var targetSpeed = isInWater ? speed * direction * 0.5 : speed * direction
        if Time.getTicksMsec() - startRunningTimestamp > speedBoostThreshold {
            targetSpeed *= 2
        }
        
        if !isOnFloor() {
            if Time.getTicksMsec() - wallJumpTimestamp > wallJumpThresholdMsec {
                if !direction.isZero {
                    if (velocity.x >= 0 && direction > 0) || (velocity.x <= 0 && direction < 0) {
                        velocity.x = Float(GD.moveToward(from: Double(velocity.x), to: targetSpeed, delta: acceleration))
                    } else {
                        velocity.x = Float(GD.moveToward(from: Double(velocity.x), to: targetSpeed, delta: deceleration))
                    }
                } else {
                    if Time.getTicksMsec() - startRunningTimestamp > speedBoostThreshold {
                    } else {
                        velocity.x = Float(GD.moveToward(from: Double(velocity.x), to: 0, delta: deceleration))
                    }
                }
            }
        } else { // is on floor
//            if velocity.isZeroApprox() {
//                startRunningTimestamp = Time.getTicksMsec()
//            }
            if !direction.isZero {
                if (velocity.x >= 0 && direction > 0) || (velocity.x <= 0 && direction < 0) {
                    velocity.x = Float(GD.moveToward(from: Double(velocity.x), to: targetSpeed, delta: acceleration))
                } else {
                    velocity.x = Float(GD.moveToward(from: Double(velocity.x), to: targetSpeed, delta: deceleration))
                }
            } else {
                startRunningTimestamp = Time.getTicksMsec()
                velocity.x = Float(GD.moveToward(from: Double(velocity.x), to: 0, delta: deceleration))
            }
        }
        
        
        if isOnFloor() {
            canDoubleJump = true
            if Input.isActionJustPressed(action: "ui_accept") {
                velocity.y = Float(-jumpSpeed)
                airTime = 0
                jumpTimestamp = Time.getTicksMsec()
            }
        } else if isGrabbingWall {
            velocity.y = 0
            if Input.isActionJustPressed(action: "ui_accept") {
                velocity.y = Float(-jumpSpeed)
                velocity.x = getWallNormal().sign().x * Float(speed) //* 0.25
                airTime = 0
                jumpTimestamp = Time.getTicksMsec()
                wallJumpTimestamp = Time.getTicksMsec()
            }
        } else {
            let airInterval = Time.getTicksMsec() - jumpTimestamp
            let airHeight = jumpSpeed * Double(airInterval) / 1000
            if Input.isActionJustReleased(action: "ui_accept") && velocity.y < 0 {
                velocity.y = 0
            }
            if Input.isActionPressed(action: "ui_accept") && airHeight < linearHeight && allowJumpSensitivity {
                
            } else {
                velocity.y += Float(gravity * delta)
                
                var terminalVelocity = Float(jumpSpeed) * terminalVelocityFactor
                if isInWater {
                    terminalVelocity *= 0.2
                }
                if velocity.y > terminalVelocity {
                    velocity.y = terminalVelocity
                }
            }
            
            if Input.isActionJustPressed(action: "ui_accept") && canDoubleJump {
                velocity.y = Float(-jumpSpeed)
                jumpTimestamp = Time.getTicksMsec()
                canDoubleJump = false
            }
            
            airTime += delta
        }
        
        moveAndSlide()
    }
    
    var isInWater = false
    
    func enterWater() {
        isInWater = true
        GD.print("ENTER WATER")
    }
    
    func exitWater() {
        isInWater = false
        GD.print("EXIT WATER")
    }
    
    var isHooking = false
    
    func hookshot() {
        isHooking = true
//        removeChild(node: hook)
//        getParent()?.addChild(node: hook)
        hook?.reparent(newParent: getParent())
    }
    
    func normalShot() {
//        let shot = NormalShot()
//        shot.direction = Vector2(x: facingDirection, y: 0)
//        shot.position = shotOrigin
//        addChild(node: shot)
    }
    
    func waveShot() {
//        let shot = WaveShot()
//        shot.direction = facingDirection
//        shot.position = shotOrigin
//        addChild(node: shot)
//        shot.position.y = position.y - playerHeight * 0.75
//        shot.position.x = position.x + Float((7 + 3) * facingDirection)
//        getParent()?.addChild(node: shot)
    }
    
    func testShotRaycast() {
        guard let space = getWorld2d()?.directSpaceState else { return }
        let origin = position + Vector2(x: 0, y: -20)
        let dest = position + Vector2(x: Float(facingDirection * 200), y: -20)
        let ray = PhysicsRayQueryParameters2D.create(from: origin, to: dest, collisionMask: 0b0011)
        let result = space.intersectRay(parameters: ray)
        
        if let fPoint = result["position"] {
            let p = Vector2(fPoint)!
            var array = PackedVector2Array()
            array.append(value: Vector2(x: origin.x, y: origin.y))
            array.append(value: Vector2(x: p.x, y: p.y))
            let line = Line2D()
            line.width = 1
            line.points = array
            getParent()?.addChild(node: line)
        }
    }
    
    // DEBUG
    override func _process(delta: Double) {
        queueRedraw()
    }
    
    override func _draw() {
        let origin = Vector2(x: 0, y: -14)
        let v = velocity * 0.1
        drawLine(from: origin, to: origin + v, color: .blue)
        drawLine(from: origin, to: origin + Vector2(x: v.x, y: 0), color: .red)
        drawLine(from: origin, to: origin + Vector2(x: 0, y: v.y), color: .green)
    }
}
