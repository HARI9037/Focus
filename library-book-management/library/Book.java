package library;

public class Book {
    private final String bookId;
    private final String bookTitle;
    private final String authorName;

    public Book(String bookId, String bookTitle, String authorName) {
        this.bookId = bookId;
        this.bookTitle = bookTitle;
        this.authorName = authorName;
    }

    public String getBookId() {
        return bookId;
    }

    public String getBookTitle() {
        return bookTitle;
    }

    public String getAuthorName() {
        return authorName;
    }
}
