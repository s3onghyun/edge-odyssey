import Testing
@testable import EdgeMotion

// The characters a user can pick (Sources/Characters.swift), read from the shipped art in
// assets/characters: which ones have Homer's episodes, and which sail every edge.

@Suite struct CharacterChoice {
    let odysseus = try! animations("assets/characters/odysseus-vector/character.txt")
    let voyager = try! animations("assets/characters/dev-voyager/character.txt")

    @Test func odysseusIsTheDefaultAndEveryChoiceShips() throws {
        #expect(Characters.standard == "odysseus-vector")
        #expect(Characters.choices.first == Characters.standard)
        for id in Characters.choices {
            let manifest = try repoFile("assets/characters/\(id)/character.txt")
            #expect(manifest.contains("size: 32x26"), "\(id) is not on the app's 32x26 canvas")
            #expect(try animations("assets/characters/\(id)/character.txt").contains("walk"), "\(id) has no walk cycle")
            let missing = try missingFrames(id)
            #expect(missing.isEmpty, "\(id) lists missing frames \(missing)")
            for lang in Lang.allCases { #expect(!Characters.title(id, lang: lang).isEmpty) }
        }
        #expect(Set(Lang.allCases.map { Characters.title("dev-voyager", lang: $0) }).count == Lang.allCases.count)
    }

    @Test func theChoiceIsSavedAndReadBackAtLaunch() throws {
        let main = try repoFile("Sources/main.swift")
        #expect(main.contains(#""character": Characters.standard]"#), "the character default is not registered")
        #expect(main.contains(#"character = d.string(forKey: "character")"#), "the saved character is not read at launch")
        #expect(try ControlCases(main).keys["char"] == ["character"])
    }

    @Test func theVoyagerHasEveryPoseTheAppPicksForAState() {
        for pose in ["walk", "idle", "sirens", "storm", "rest", "ithaca", "doze"] { #expect(voyager.contains(pose), "missing \(pose)") }
    }

    @Test func homersEpisodesOnlyRunForOdysseus() throws {
        #expect(EpisodePlanner.runs(for: odysseus))
        #expect(EpisodePlanner.runs(for: try animations("assets/characters/odysseus-pixel.sprite")))
        #expect(!EpisodePlanner.runs(for: voyager))
        #expect(!voyager.contains("ram"), "the ram escape is an Odyssey episode too")
    }

    @Test func theVoyagerSailsEveryEdgeAndOdysseusClimbs() {
        #expect(sailsEveryEdge(voyager))
        #expect(!sailsEveryEdge(odysseus))
        #expect(!sailsEveryEdge(["walk", "climb-crag"]))
        #expect(!sailsEveryEdge(["walk", "zip"]))
        #expect(sailsEveryEdge(["walk", "idle", "slider"]))   // only exact names or `name-` variants are edge art
    }
}
