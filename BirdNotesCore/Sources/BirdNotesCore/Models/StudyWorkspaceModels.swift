import Foundation

/// A small, dependency-free blueprint used to create a complete study library.
/// Curriculum metadata stays in the technical core; the document core only
/// receives validated folder and notebook names.
public struct StudyProgramModuleDefinition: Equatable, Sendable {
    public let code: String
    public let title: String

    public init(code: String, title: String) {
        self.code = code
        self.title = title
    }
}

public struct StudyProgramPhaseDefinition: Equatable, Sendable {
    public let title: String
    public let modules: [StudyProgramModuleDefinition]

    public init(title: String, modules: [StudyProgramModuleDefinition]) {
        self.title = title
        self.modules = modules
    }
}
