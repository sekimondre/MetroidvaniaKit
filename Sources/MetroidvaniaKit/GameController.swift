import SwiftGodot
import Foundation

let TILE_SIZE: Int32 = 16
let ROOM_WIDTH: Int32 = 25
let ROOM_HEIGHT: Int32 = 15

@Godot
class GameController: Node {
    
    @SceneTree(path: "../PlayerNode") var player: PlayerNode?
    @SceneTree(path: "../SidescrollerCamera") var camera: SidescrollerCamera?
    @SceneTree(path: "../SidescrollerCamera/Overlay") var bgOverlay: Polygon2D?
    
    @SceneTree(path: "../CanvasLayer/HUD") var hud: HUD?
    @SceneTree(path: "../CanvasLayer/PauseMenu") var pauseMenu: Control?
    @SceneTree(path: "../CanvasLayer/PauseMenu/Overlay") var canvasOverlay: ColorRect?
    
    @SceneTree(path: "../Parallax2D") var parallaxLayer: Parallax2D?
    
    @Export var roomToLoad: String = ""
    
    private(set) var world: World?
    
    var lastCellPosition: Vector2i = .zero
    
    var currentRoom: Node2D?
    
    var isPaused = false
    
    override func _ready() {
        self.processMode = .always
        
        log("Player: \(player)")
        
        let worldFile = "res://tiled/world-test.world"
        do {
            self.world = try World.load(from: worldFile)
        } catch {
            logError("Failed to decode world data from '\(worldFile)' with error: \(error).")
        }
        
        guard let player, let world else { return }
        
        camera?.target = player
        hud?.setPlayerStats(player.stats)
        
        if roomToLoad != "" {
            for map in world.maps {
                if let name = try? getFileName(from: map.fileName), name == roomToLoad {
                    player.position.x = Float(map.x)
                    player.position.y = Float(map.y)
                }
            }
        }
    }
    
    override func _process(delta: Double) {
        if Input.isActionJustPressed(.start) {
            if isPaused {
                unpause()
            } else {
                pause()
            }
        }
        
        guard let player else {
            logError("Player instance not found!")
            return
        }
        
        let cellX = Int32(player.position.x / Float(TILE_SIZE * ROOM_WIDTH))
        let cellY = Int32(player.position.y / Float(TILE_SIZE * ROOM_HEIGHT))
        let playerCellPosition: Vector2i = .init(x: cellX, y: cellY)
        
        if playerCellPosition != lastCellPosition {
            onCellChanged(playerCellPosition, playerPosition: player.position)
        }
    }
    
    func pause() {
        isPaused = true
        pauseMenu?.visible = true
        getTree()?.paused = true
        
        let tween = getTree()?.createTween()
        tween?.setPauseMode(.process)
        tween?.tweenProperty(object: canvasOverlay, property: "modulate", finalVal: Variant(Color.white), duration: 0.4)
    }
    
    func unpause() {
//        isPaused = false
//        getTree()?.paused = false
//        pauseMenu?.visible = false
        
        let tween = getTree()?.createTween()
        tween?.setPauseMode(.process)
        tween?.tweenProperty(object: canvasOverlay, property: "modulate", finalVal: Variant(Color.transparent), duration: 0.4)
        tween?.finished.connect { [weak self] in
            self?.isPaused = false
            self?.getTree()?.paused = false
            self?.pauseMenu?.visible = false
        }
    }
    
    func instantiateRoom(_ map: World.Map) -> Node2D? {
        let mapPath = "res://tiled/\(map.fileName)"
        let roomScene = ResourceLoader.load(path: mapPath) as? PackedScene
        let room = roomScene?.instantiate() as? Node2D
        room?.position = Vector2(x: Float(map.x), y: Float(map.y))
        
        if let parallaxLayer {
            for child in parallaxLayer.getChildren() {
                child?.queueFree()
            }
            if let parallax = room?.findChild(pattern: "parallax") as? Node2D {
                parallax.owner = nil
                parallax.reparent(newParent: parallaxLayer, keepGlobalTransform: false)

                if let xParallax = parallax.getMeta(name: "parallax_x", default: Variant(0.2)) {
                    parallaxLayer.scrollScale.x = Float(xParallax) ?? 0.0
                }
                if let yParallax = parallax.getMeta(name: "parallax_y", default: Variant(0.2)) {
                    parallaxLayer.scrollScale.y = Float(yParallax) ?? 0.0
                }
            }
        }
        
        return room
    }
    
    func onCellChanged(_ nextCell: Vector2i, playerPosition: Vector2) {
        guard let world else {
            logError("World instance not found!")
            return
        }
        
        let moveDelta = nextCell - lastCellPosition
        lastCellPosition = nextCell
        hud?.minimap?.onCellChanged(newOffset: nextCell)
        
        for map in world.maps {
            if // find which room the player is in
                Int32(playerPosition.x) >= map.x && Int32(playerPosition.x) < map.x + map.width &&
                Int32(playerPosition.y) >= map.y && Int32(playerPosition.y) < map.y + map.height
            {
                if let roomName = try? getFileName(from: map.fileName), StringName(roomName) != currentRoom?.name {
                    onRoomTransition(to: map, moveDelta: moveDelta)
                }
            }
        }
    }
    
    func onRoomTransition(to map: World.Map, moveDelta: Vector2i) {
        if currentRoom == nil { // is the first room, just set the limits
            let newRoom = instantiateRoom(map)
            getParent()?.addChild(node: newRoom)
            camera?.limitLeft = map.x
            camera?.limitRight = map.x + map.width
            camera?.limitTop = map.y
            camera?.limitBottom = map.y + map.height
            currentRoom = newRoom
            
            if let spawn = newRoom?.findChild(pattern: "spawn-point", recursive: true) as? Node2D {
                player?.globalPosition.x = spawn.globalPosition.x
                player?.globalPosition.y = spawn.globalPosition.y
            }
        } else { // perform room transition
            guard let camera else { return }
            let sceneTree = getTree()
            sceneTree?.paused = true
            
            let overlayTween = getTree()?.createTween()
            overlayTween?.setPauseMode(.process)
            overlayTween?.tweenProperty(object: bgOverlay, property: "self_modulate", finalVal: Variant(Color.black), duration: 0.15)
            overlayTween?.finished.connect { [weak self] in
                let newRoom = self?.instantiateRoom(map)
                self?.getParent()?.addChild(node: newRoom)
                
                let tween = self?.getTree()?.createTween()
                tween?.setPauseMode(.process)
                
                let offset = Vector2(x: TILE_SIZE * ROOM_WIDTH * moveDelta.x, y: TILE_SIZE * ROOM_HEIGHT * moveDelta.y)
                tween?.tweenProperty(object: camera, property: "offset", finalVal: Variant(offset), duration: 0.7)
                tween?.tweenProperty(object: self?.bgOverlay, property: "self_modulate", finalVal: Variant(Color.transparent), duration: 0.15)
                
                tween?.finished.connect { [weak self] in
                    camera.offset = .zero
                    camera.limitLeft = map.x
                    camera.limitRight = map.x + map.width
                    camera.limitTop = map.y
                    camera.limitBottom = map.y + map.height
                    
                    self?.currentRoom?.queueFree()
                    self?.currentRoom = newRoom
                    
                    sceneTree?.paused = false
                }
            }
        }
        log("Current room: \(currentRoom?.name ?? "")")
    }
}
