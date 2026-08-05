import Foundation

struct SearchRankingWeights: Equatable {
    let exact: Double
    let prefix: Double
    let wholeWord: Double
    let substring: Double
    let fuzzyMaximum: Double
    let captureRecencyMaximum: Double
    let pasteRecencyMaximum: Double
    let pasteCountMaximum: Double
    let reuseCopyCountMaximum: Double
    let favorite: Double
    let sourceMaximum: Double
    let allTermsBonus: Double

    init(
        exact: Double = 1_000.0,
        prefix: Double = 700.0,
        wholeWord: Double = 500.0,
        substring: Double = 300.0,
        fuzzyMaximum: Double = 250.0,
        captureRecencyMaximum: Double = 200.0,
        pasteRecencyMaximum: Double = 120.0,
        pasteCountMaximum: Double = 80.0,
        reuseCopyCountMaximum: Double = 40.0,
        favorite: Double = 30.0,
        sourceMaximum: Double = 80.0,
        allTermsBonus: Double = 40.0
    ) {
        self.exact = exact
        self.prefix = prefix
        self.wholeWord = wholeWord
        self.substring = substring
        self.fuzzyMaximum = fuzzyMaximum
        self.captureRecencyMaximum = captureRecencyMaximum
        self.pasteRecencyMaximum = pasteRecencyMaximum
        self.pasteCountMaximum = pasteCountMaximum
        self.reuseCopyCountMaximum = reuseCopyCountMaximum
        self.favorite = favorite
        self.sourceMaximum = sourceMaximum
        self.allTermsBonus = allTermsBonus
    }
}
