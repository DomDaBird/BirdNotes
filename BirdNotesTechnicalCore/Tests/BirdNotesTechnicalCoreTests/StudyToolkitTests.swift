import Foundation
import Testing
@testable import BirdNotesTechnicalCore

@Suite("Software development study toolkit")
struct StudyToolkitTests {
    @Test("The handbook catalog covers every required semester module")
    func validatesCurriculumCoverage() throws {
        let curriculum = try StudyCurriculum.softwareDevelopment2026()
        let required = StudyPhase.allCases
            .filter { $0 != .elective && $0 != .thesis }
            .flatMap { curriculum.modules(in: $0) }

        #expect(required.count == 20)
        #expect(Set(required.map(\.code)).isSuperset(of: [
            "IGIS-01", "DLBWIRITT", "IREN", "IDBS", "DLBIADPS-01", "DLBSEPDOCD_D",
            "DLBSESA", "IQSS", "DLBCSEMSE1-01_D", "ISEF"
        ]))
        #expect(curriculum.modules(in: .elective).count >= 25)
        #expect(Set(curriculum.modules.flatMap(\.tools)) == Set(StudyToolIdentifier.allCases))
    }

    @Test("Duplicate module codes and unsafe catalog data are rejected")
    func rejectsInvalidCatalogs() {
        let module = StudyModuleRecord(
            code: "SAFE-01",
            title: "Safe",
            phase: .semester1,
            area: .softwareEngineering,
            focus: ["Test"],
            tools: [.testingMatrix]
        )
        #expect(throws: StudyToolkitError.self) {
            _ = try StudyCurriculum(
                identifier: "duplicate",
                title: "Duplicate",
                handbookDate: "2026",
                modules: [module, module]
            )
        }
    }

    @Test("Credit workload uses the handbook's 30 hours per CP")
    func plansWorkload() throws {
        let plan = try StudyWorkloadPlan.calculate(credits: 5, weeks: 20)

        #expect(plan.totalHours == 150)
        #expect(plan.hoursPerWeek == 7.5)
        #expect(throws: StudyToolkitError.self) {
            _ = try StudyWorkloadPlan.calculate(credits: .infinity, weeks: 20)
        }
    }

    @Test("Descriptive statistics are deterministic for population and sample data")
    func calculatesStatistics() throws {
        let population = try DescriptiveStatistics.analyze([1, 2, 3, 4])
        let sample = try DescriptiveStatistics.analyze([1, 2, 3, 4], usesSampleVariance: true)

        #expect(population.count == 4)
        #expect(population.mean == 2.5)
        #expect(population.median == 2.5)
        #expect(population.variance == 1.25)
        #expect(abs(sample.variance - (5.0 / 3.0)) < 1e-12)
        #expect(throws: StudyToolkitError.self) {
            _ = try DescriptiveStatistics.analyze([1, .nan])
        }
    }

    @Test("Number systems convert signed values and reject code-like input")
    func convertsNumberSystems() throws {
        let result = try NumberSystemConverter.convert("-1010", from: .binary)

        #expect(result.decimalValue == -10)
        #expect(result.hexadecimal == "-A")
        #expect(throws: StudyToolkitError.self) {
            _ = try NumberSystemConverter.convert("10; print(secret)", from: .decimal)
        }
    }

    @Test("Complexity estimates remain inside an explicit resource budget")
    func estimatesComplexity() throws {
        #expect(try AlgorithmComplexity.quadratic.estimateOperations(for: 100) == 10_000)
        #expect(try AlgorithmComplexity.linearithmic.estimateOperations(for: 1) == 0)
        #expect(throws: StudyToolkitError.self) {
            _ = try AlgorithmComplexity.exponential.estimateOperations(for: 100)
        }
    }

    @Test("CIDR calculation handles regular and point-to-point networks")
    func calculatesNetworks() throws {
        let subnet = try IPv4NetworkCalculator.calculate(address: "192.168.10.42", prefixLength: 24)
        let pointToPoint = try IPv4NetworkCalculator.calculate(address: "10.0.0.1", prefixLength: 31)

        #expect(subnet.networkAddress == "192.168.10.0")
        #expect(subnet.broadcastAddress == "192.168.10.255")
        #expect(subnet.firstHost == "192.168.10.1")
        #expect(subnet.lastHost == "192.168.10.254")
        #expect(subnet.usableHostCount == 254)
        #expect(pointToPoint.usableHostCount == 2)
        #expect(throws: StudyToolkitError.self) {
            _ = try IPv4NetworkCalculator.calculate(address: "127.0.0.1<script>", prefixLength: 8)
        }
    }

    @Test("Requirements receive actionable deterministic quality findings")
    func reviewsRequirements() throws {
        let complete = try RequirementReviewer.review(
            statement: "Als Student muss ich ein Technikdokument offline speichern können.",
            acceptanceCriteria: "Gegeben kein Netzwerk, wenn ich Speichern wähle, dann bleibt das Dokument nach einem Neustart vorhanden."
        )
        let vague = try RequirementReviewer.review(
            statement: "Die App ist möglichst schnell und intuitiv.",
            acceptanceCriteria: "Soll gut funktionieren."
        )

        #expect(complete.score == 100)
        #expect(complete.isReadyForReview)
        #expect(vague.score < complete.score)
        #expect(vague.findings.contains { $0.id == "statement.vague" })
        #expect(throws: StudyToolkitError.self) {
            _ = try RequirementReviewer.review(statement: String(repeating: "x", count: 2_001), acceptanceCriteria: "x")
        }
    }

    @Test("Spaced repetition dates grow with the selected confidence")
    func plansSpacedRepetition() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let again = try SpacedRepetitionPlanner.schedule(
            from: start,
            confidence: .again,
            sessionCount: 3,
            calendar: calendar
        )
        let easy = try SpacedRepetitionPlanner.schedule(
            from: start,
            confidence: .easy,
            sessionCount: 3,
            calendar: calendar
        )

        #expect(again.reviewDates.count == 3)
        #expect(again.reviewDates[0] == calendar.date(byAdding: .day, value: 1, to: start))
        #expect(easy.reviewDates[0] == calendar.date(byAdding: .day, value: 7, to: start))
        #expect(throws: StudyToolkitError.self) {
            _ = try SpacedRepetitionPlanner.schedule(
                from: start,
                confidence: .good,
                sessionCount: 13,
                calendar: calendar
            )
        }
    }

    @Test("JSON is validated, sorted and bounded")
    func formatsJSONForStudy() throws {
        let result = try JSONStudyFormatter.format("{\"b\":2,\"a\":[true,null]}")

        #expect(result.topLevelDescription == "Objekt mit 2 Schlüsseln")
        #expect(result.minified == "{\"a\":[true,null],\"b\":2}")
        #expect(result.prettyPrinted.contains("\"a\""))
        #expect(throws: StudyToolkitError.self) {
            _ = try JSONStudyFormatter.format("{not-json}")
        }
        #expect(throws: StudyToolkitError.self) {
            _ = try JSONStudyFormatter.format(String(repeating: " ", count: JSONStudyFormatter.maximumInputBytes + 1))
        }
    }
}
