import SwiftGodot

@Godot
class BreakableBlock: RigidBody2D {
    
    @SceneTree(path: "Area2D") weak var area: Area2D?
    @SceneTree(path: "Sprite2D") weak var coverSprite: Sprite2D?
    @SceneTree(path: "RealSprite") weak var realSprite: Sprite2D?
    @SceneTree(path: "AnimatedSprite2D") weak var destroyAnimation: AnimatedSprite2D?
    
    override func _ready() {
        guard let area else {
            logError("Collision area not found")
            return
        }
        
        freeze = true
        freezeMode = .kinematic
        
        collisionLayer |= 0b0010
        area.collisionMask = 0b1_0000
        area.collisionLayer = 0b0011
        
        destroyAnimation?.spriteFrames?.setAnimationLoop(anim: "default", loop: false)
        destroyAnimation?.animationFinished.connect { [weak self] in
            self?.queueFree()
        }
        
        area.areaEntered.connect { [weak self] otherArea in
            guard let self, let otherArea else { return }
            if otherArea.collisionLayer & 0b0001_0000 != 0 {
                self.reveal()
                self.collisionLayer = 0
                self.realSprite?.visible = false
                self.destroyAnimation?.play()
            }
        }
    }
    
    func reveal() {
        coverSprite?.visible = false
    }
    
    deinit {
        GD.print("BreakableBlock deinitialized")
    }
}
