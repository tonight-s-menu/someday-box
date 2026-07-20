import Testing
@testable import SomedayBox

@Suite("Core Box runtime motion recipes")
struct CoreBoxMotionRecipeTests {
    @Test func proofRecipesPreserveThePublicMotionContract() {
        let recipes = CoreBoxMotionRecipe.proofMotions
        #expect(recipes.map(\.name) == ["idle.listen", "capture.deposit", "draw.reveal"])
        #expect(recipes.map(\.durationMilliseconds) == [1_000, 560, 750])
        #expect(recipes.map(\.controlledEntityName) == ["BoxRoot", "LidPivot", "PaperReveal"])
    }

    @Test func fallbackRetainsTheThirteenMotionVocabularyForProductionExpansion() {
        #expect(CoreBoxMotionRecipe.allPublicMotions.map(\.name) == [
            "idle.blink", "idle.listen", "idle.paperRustle", "idle.currentGlance",
            "react.touch", "react.notice.single", "react.notice.aggregate",
            "capture.receive", "capture.deposit", "draw.reveal", "current.attach",
            "paper.return", "memory.stamp"
        ])
    }
}
