import SwiftGodot

//#initSwiftExtension(cdecl: "swift_entry_point")
//#initSwiftExtension(cdecl: "swift_entry_point", types: [
//    CharacterController2D.self,
//    TriggerArea2D.self,
//    PlayerHitbox.self,
//    HookHitbox.self,
//    WaveShot.self,
//    NormalShot.self,
//    TiledImporter.self,
//    TestButton.self,
//])

func setupScene (level: GDExtension.InitializationLevel) {
    switch level {
    case .editor:
        register(type: TiledImporter.self)
        register(type: MapImportPlugin.self)
        register(type: TileSetImporter.self)
        register(type: TileMapImporter.self)
        register(type: WorldImporter.self)
//        register(type: TilemapBuilder.self)
//        register(type: DictionaryBuilder.self)
    case .scene:
        [
            CharacterController2D.self,
            TriggerArea2D.self,
            PlayerHitbox.self,
            HookHitbox.self,
            WaveShot.self,
            NormalShot.self,
        ].forEach { register(type: $0) }
    default:
        break
    }
}

@_cdecl ("swift_entry_point")
public func swift_entry_point(
    interfacePtr: OpaquePointer?,
    libraryPtr: OpaquePointer?,
    extensionPtr: OpaquePointer?) -> UInt8
{
    print ("SwiftGodot Extension loaded")
    guard let interfacePtr, let libraryPtr, let extensionPtr else {
        print ("Error: some parameters were not provided")
        return 0
    }
    initializeSwiftModule(interfacePtr, libraryPtr, extensionPtr, initHook: setupScene, deInitHook: { x in })
    return 1
}
