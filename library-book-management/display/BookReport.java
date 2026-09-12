package display;

import java.util.Scanner;
import library.Book;

public class BookReport {
    public static void displayReport(Book book) {
        System.out.println("\n========================================");
        System.out.println("          LIBRARY BOOK REPORT");
        System.out.println("========================================");
        System.out.printf("%-14s : %s%n", "Book ID", book.getBookId());
        System.out.printf("%-14s : %s%n", "Book Title", book.getBookTitle());
        System.out.printf("%-14s : %s%n", "Author Name", book.getAuthorName());
        System.out.println("========================================");
    }

    public static void main(String[] args) {
        try (Scanner scanner = new Scanner(System.in)) {
            System.out.print("Enter Book ID: ");
            String bookId = scanner.nextLine();

            System.out.print("Enter Book Title: ");
            String bookTitle = scanner.nextLine();

            System.out.print("Enter Author Name: ");
            String authorName = scanner.nextLine();

            Book book = new Book(bookId, bookTitle, authorName);
            displayReport(book);
        }
    }
}
