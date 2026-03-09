-- PROJECT 2: LIBRARY MANAGEMENT SYSTEM

-- 1. CREATE DATABASE
DROP DATABASE IF EXISTS library_system;
CREATE DATABASE library_system;
USE library_system;

-- 2. CREATE TABLES

-- Members table
CREATE TABLE members (
    member_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    join_date DATE 
);

-- Books table
CREATE TABLE books (
    book_id INT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(150) NOT NULL,
    author VARCHAR(100),
    genre VARCHAR(50),
    available_copies INT DEFAULT 1,
    total_copies INT DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Issued Books table
CREATE TABLE issued_books (
    issue_id INT AUTO_INCREMENT PRIMARY KEY,
    member_id INT,
    book_id INT,
    issue_date DATE ,
    return_date DATE,
    due_date DATE,
    status ENUM('Issued', 'Returned', 'Late') ,
    FOREIGN KEY (member_id) REFERENCES members(member_id) ON DELETE CASCADE,
    FOREIGN KEY (book_id) REFERENCES books(book_id) ON DELETE CASCADE
);

-- 3. TRIGGERS

-- Decrease stock on issue
DELIMITER //
CREATE TRIGGER decrease_stock AFTER INSERT ON issued_books
FOR EACH ROW
BEGIN
    UPDATE books
    SET available_copies = available_copies - 1
    WHERE book_id = NEW.book_id;
END;
//
DELIMITER ;

-- Increase stock on return
DELIMITER //
CREATE TRIGGER increase_stock AFTER UPDATE ON issued_books
FOR EACH ROW
BEGIN
    IF NEW.status = 'Returned' AND OLD.status = 'Issued' THEN
        UPDATE books
        SET available_copies = available_copies + 1
        WHERE book_id = NEW.book_id;
    END IF;
END;
//
DELIMITER ;

-- 4. INDEXES

CREATE INDEX idx_member_email ON members(email);
CREATE INDEX idx_book_genre ON books(genre);
CREATE INDEX idx_issue_status ON issued_books(status);

-- 5. INSERT SAMPLE DATA

-- Members
INSERT INTO members (name, email) VALUES
('Alice Johnson', 'alice@example.com'),
('Bob Smith', 'bob@example.com'),
('Charlie Ray', 'charlie@example.com'),
('Diana Prince', 'diana@example.com'),
('Edward Green', 'edward@example.com'),
('Fiona Brooks', 'fiona@example.com');

-- Books
INSERT INTO books (title, author, genre, available_copies, total_copies) VALUES
('The Great Gatsby', 'F. Scott Fitzgerald', 'Fiction', 3, 3),
('1984', 'George Orwell', 'Dystopian', 2, 2),
('Clean Code', 'Robert C. Martin', 'Programming', 1, 1),
('The Pragmatic Programmer', 'Andrew Hunt', 'Programming', 1, 1),
('To Kill a Mockingbird', 'Harper Lee', 'Classic', 2, 2),
('Sapiens', 'Yuval Noah Harari', 'Non-fiction', 3, 3),
('Atomic Habits', 'James Clear', 'Self-help', 2, 2),
('The Alchemist', 'Paulo Coelho', 'Fiction', 1, 1),
('The Mythical Man-Month', 'Frederick Brooks', 'Programming', 1, 1),
('Brave New World', 'Aldous Huxley', 'Dystopian', 2, 2);

-- Issued Books
INSERT INTO issued_books (member_id, book_id, issue_date, due_date, return_date, status) VALUES
(1, 1, '2024-01-05', '2024-01-15', '2024-01-14', 'Returned'),
(2, 2, '2024-01-10', '2024-01-20', '2024-01-19', 'Returned'),
(3, 3, '2024-01-12', '2024-01-22', '2024-01-28', 'Returned'),
(4, 4, '2024-01-15', '2024-01-25', '2024-01-30', 'Returned'),
(5, 5, '2024-02-01', '2024-02-10', NULL, 'Issued'),
(6, 6, '2024-02-03', '2024-02-13', NULL, 'Issued'),
(1, 7, '2024-01-18', '2024-01-25', '2024-02-01', 'Returned'),
(2, 8, '2024-01-20', '2024-01-30', '2024-02-02', 'Returned'),
(3, 9, '2024-02-10', '2024-02-20', NULL, 'Issued'),
(4, 10, '2024-02-12', '2024-02-22', NULL, 'Issued');

-- 6. VIEWS

-- Active borrowed books
CREATE OR REPLACE VIEW active_borrowed_books AS
SELECT 
    ib.issue_id,
    m.name AS member_name,
    b.title,
    ib.issue_date,
    ib.due_date,
    ib.status
FROM issued_books ib
JOIN members m ON ib.member_id = m.member_id
JOIN books b ON ib.book_id = b.book_id
WHERE ib.status = 'Issued';

-- Late returns
CREATE OR REPLACE VIEW late_returns AS
SELECT 
    m.name AS member_name,
    b.title,
    ib.due_date,
    ib.return_date,
    DATEDIFF(ib.return_date, ib.due_date) AS days_late
FROM issued_books ib
JOIN members m ON ib.member_id = m.member_id
JOIN books b ON ib.book_id = b.book_id
WHERE ib.status = 'Returned' AND ib.return_date > ib.due_date;

-- 7. STORED PROCEDURES

-- Issue a book
DELIMITER //
CREATE PROCEDURE IssueBook(
    IN member INT,
    IN book INT,
    IN due DATE
)
BEGIN
    DECLARE stock INT;
    SELECT available_copies INTO stock FROM books WHERE book_id = book;
    IF stock > 0 THEN
        INSERT INTO issued_books(member_id, book_id, due_date)
        VALUES(member, book, due);
    ELSE
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Book not available';
    END IF;
END;
//
DELIMITER ;

-- Member borrow history
DELIMITER //
CREATE PROCEDURE GetMemberHistory(IN member_id INT)
BEGIN
    SELECT 
        b.title,
        ib.issue_date,
        ib.return_date,
        ib.status
    FROM issued_books ib
    JOIN books b ON ib.book_id = b.book_id
    WHERE ib.member_id = member_id;
END;
//
DELIMITER ;

-- 8. WINDOW FUNCTIONS

-- Rank members by total borrowed
SELECT 
    member_id,
    COUNT(*) AS total_books,
    RANK() OVER (ORDER BY COUNT(*) DESC) AS borrow_rank
FROM issued_books
GROUP BY member_id;

-- Latest book per member
SELECT *
FROM (
    SELECT 
        ib.*,
        ROW_NUMBER() OVER (PARTITION BY member_id ORDER BY issue_date DESC) AS rn
    FROM issued_books ib
) t
WHERE rn = 1;

-- 9. BUSINESS QUERIES

-- Most borrowed books
SELECT b.title, COUNT(*) AS times_issued
FROM issued_books ib
JOIN books b ON ib.book_id = b.book_id
GROUP BY b.title
ORDER BY times_issued DESC;

-- Members with more than 1 book issued
SELECT m.name, COUNT(ib.issue_id) AS books_issued
FROM issued_books ib
JOIN members m ON ib.member_id = m.member_id
GROUP BY m.member_id
HAVING COUNT(ib.issue_id) > 1;

-- Out-of-stock books
SELECT title, available_copies
FROM books
WHERE available_copies = 0;

-- 10. CHECK DATA

SELECT * FROM members;
SELECT * FROM books;
SELECT * FROM issued_books;
SELECT * FROM active_borrowed_books;
SELECT * FROM late_returns;

-- 11. CALL PROCEDURES

CALL IssueBook(2, 1, '2024-03-10');
CALL GetMemberHistory(1);