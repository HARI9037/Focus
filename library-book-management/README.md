# Library Book Management

`library.Book` stores a book's ID, title, and author, initialized through a
constructor and accessed using getters. `display.BookReport` reads these values
using Scanner and prints a formatted report. IDs are strings to support values
such as `B001` and preserve leading zeros. Full-line input supports spaces in
titles and author names.

From this directory, compile and run with a JDK installed:

```shell
javac -d out library/Book.java display/BookReport.java
java -cp out display.BookReport
```

Example interaction:

```text
Enter Book ID: B001
Enter Book Title: The Hobbit
Enter Author Name: J. R. R. Tolkien

========================================
          LIBRARY BOOK REPORT
========================================
Book ID        : B001
Book Title     : The Hobbit
Author Name    : J. R. R. Tolkien
========================================
```
