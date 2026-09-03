import Foundation

public enum NotebookPageCreationPolicy {
    /// Returns a new trailing page only when the page that just received content
    /// was the empty last page before the edit.
    public static func trailingPage(
        afterDrawingOn pageID: UUID,
        pagesBeforeEdit: [NotebookPageMetadata],
        now: Date = Date()
    ) -> NotebookPageMetadata? {
        guard let lastPage = pagesBeforeEdit.last,
              lastPage.id == pageID,
              lastPage.isEmpty else {
            return nil
        }

        return NotebookPageMetadata(
            createdAt: now,
            modifiedAt: now,
            paperStyle: lastPage.paperStyle,
            paperFormat: lastPage.paperFormat,
            paperOrientation: lastPage.paperOrientation
        )
    }
}
