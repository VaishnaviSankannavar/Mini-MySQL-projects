-- 1. CREATE DATABASE
DROP DATABASE IF EXISTS student_management;
CREATE DATABASE student_management;
USE student_management;

-- 2. CREATE TABLES

CREATE TABLE students (
    student_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    dob DATE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE courses (
    course_id INT AUTO_INCREMENT PRIMARY KEY,
    course_name VARCHAR(100) NOT NULL,
    credits INT NOT NULL
);

CREATE TABLE enrollments (
    enrollment_id INT AUTO_INCREMENT PRIMARY KEY,
    student_id INT NOT NULL,
    course_id INT NOT NULL,
    marks INT CHECK (marks BETWEEN 0 AND 100),
    grade VARCHAR(3),
    enrolled_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (student_id) REFERENCES students(student_id) ON DELETE CASCADE,
    FOREIGN KEY (course_id) REFERENCES courses(course_id) ON DELETE CASCADE,
    UNIQUE(student_id, course_id)
);

-- 3. TRIGGER: Auto-assign grade based on marks

DELIMITER //
CREATE TRIGGER assign_grade BEFORE INSERT ON enrollments
FOR EACH ROW
BEGIN
    IF NEW.marks >= 90 THEN
        SET NEW.grade = 'A+';
    ELSEIF NEW.marks >= 80 THEN
        SET NEW.grade = 'A';
    ELSEIF NEW.marks >= 70 THEN
        SET NEW.grade = 'B';
    ELSEIF NEW.marks >= 60 THEN
        SET NEW.grade = 'C';
    ELSE
        SET NEW.grade = 'F';
    END IF;
END;
//
DELIMITER ;

-- 4. INSERT SAMPLE DATA

-- Students
INSERT INTO students (name, email, dob) VALUES 
('John Doe', 'john@email.com', '2002-05-10'),
('Sara Khan', 'sara@email.com', '2001-08-15'),
('Michael Lee', 'michael@email.com', '2003-02-20'),
('Emma Watson', 'emma@email.com', '2002-12-01');

-- Courses
INSERT INTO courses (course_name, credits) VALUES 
('Mathematics', 3),
('Computer Science', 4),
('Physics', 3);

-- Enrollments (grade auto-assigned)
INSERT INTO enrollments (student_id, course_id, marks) VALUES 
(1, 1, 85), -- A
(1, 2, 92), -- A+
(2, 1, 78), -- B
(3, 3, 88); -- A

-- 5. STORED PROCEDURES

-- a. Get average marks for a student
DELIMITER //
CREATE PROCEDURE GetStudentAverage(IN sid INT)
BEGIN
    SELECT 
        s.name,
        ROUND(AVG(e.marks), 2) AS average_marks
    FROM enrollments e
    JOIN students s ON e.student_id = s.student_id
    WHERE s.student_id = sid
    GROUP BY s.name;
END;
//
DELIMITER ;

-- b. Enroll a student (marks provided, grade auto-assigned)
DELIMITER //
CREATE PROCEDURE EnrollStudent(
    IN sid INT,
    IN cid INT,
    IN marks INT
)
BEGIN
    INSERT INTO enrollments(student_id, course_id, marks)
    VALUES(sid, cid, marks);
END;
//
DELIMITER ;

-- 6. CREATE VIEW

-- Student results view
CREATE OR REPLACE VIEW student_results AS
SELECT 
    s.student_id,
    s.name AS student_name,
    c.course_name,
    c.credits,
    e.marks,
    e.grade,
    e.enrolled_at
FROM enrollments e
JOIN students s ON s.student_id = e.student_id
JOIN courses c ON c.course_id = e.course_id;

-- 7. DATA MANIPULATION EXAMPLES

-- a. Update marks (grade will not auto-update unless deleted and re-inserted)
UPDATE enrollments
SET marks = 95, grade = 'A+'
WHERE student_id = 1 AND course_id = 1;

-- b. Delete enrollment
DELETE FROM enrollments
WHERE student_id = 2 AND course_id = 1;

-- c. Enroll new student via procedure
CALL EnrollStudent(4, 1, 73); -- Emma to Math

-- 8. BUSINESS QUERIES

-- a. Top 3 students by average marks
SELECT s.name, ROUND(AVG(e.marks), 2) AS avg_marks
FROM students s
JOIN enrollments e ON s.student_id = e.student_id
GROUP BY s.student_id
ORDER BY avg_marks DESC
LIMIT 3;

-- b. Count students per course
SELECT c.course_name, COUNT(e.student_id) AS total_students
FROM courses c
LEFT JOIN enrollments e ON c.course_id = e.course_id
GROUP BY c.course_name;

-- c. List students who failed (marks < 40)
SELECT s.name, c.course_name, e.marks, e.grade
FROM enrollments e
JOIN students s ON e.student_id = s.student_id
JOIN courses c ON e.course_id = c.course_id
WHERE e.marks < 40;

-- 9. CHECK DATA

SELECT * FROM students;
SELECT * FROM courses;
SELECT * FROM enrollments;
SELECT * FROM student_results;