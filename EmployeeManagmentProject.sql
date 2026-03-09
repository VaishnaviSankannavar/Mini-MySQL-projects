-- ============================================
-- PROJECT 3: EMPLOYEE MANAGEMENT SYSTEM
-- ============================================

-- 1. CREATE DATABASE
DROP DATABASE IF EXISTS employee_management;
CREATE DATABASE employee_management;
USE employee_management;

-- ============================================
-- 2. TABLE CREATION
-- ============================================

-- Departments
CREATE TABLE departments (
    department_id INT AUTO_INCREMENT PRIMARY KEY,
    department_name VARCHAR(100) NOT NULL UNIQUE,
    location VARCHAR(100)
);

-- Employees
CREATE TABLE employees (
    employee_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    phone VARCHAR(15),
    dob DATE,
    hire_date DATE,
    salary DECIMAL(10,2) NOT NULL,
    department_id INT,
    manager_id INT,
    FOREIGN KEY (department_id) REFERENCES departments(department_id) ON DELETE SET NULL,
    FOREIGN KEY (manager_id) REFERENCES employees(employee_id) ON DELETE SET NULL
);

-- Projects
CREATE TABLE projects (
    project_id INT AUTO_INCREMENT PRIMARY KEY,
    project_name VARCHAR(150) NOT NULL,
    start_date DATE,
    end_date DATE,
    budget DECIMAL(12,2)
);

-- Employee-Project Mapping
CREATE TABLE employee_projects (
    emp_proj_id INT AUTO_INCREMENT PRIMARY KEY,
    employee_id INT,
    project_id INT,
    role VARCHAR(100),
    assigned_date DATE ,
    FOREIGN KEY (employee_id) REFERENCES employees(employee_id) ON DELETE CASCADE,
    FOREIGN KEY (project_id) REFERENCES projects(project_id) ON DELETE CASCADE,
    UNIQUE(employee_id, project_id)
);

-- ============================================
-- 3. INDEXES
-- ============================================

CREATE INDEX idx_emp_email ON employees(email);
CREATE INDEX idx_emp_dept ON employees(department_id);
CREATE INDEX idx_project_name ON projects(project_name);

-- ============================================
-- 4. TRIGGERS
-- ============================================

-- Prevent negative salary
DELIMITER //
CREATE TRIGGER check_salary
BEFORE INSERT ON employees
FOR EACH ROW
BEGIN
    IF NEW.salary < 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Salary cannot be negative';
    END IF;
END;
//
DELIMITER ;

-- Auto update salary increase log (example logic)
DELIMITER //
CREATE TRIGGER prevent_salary_drop
BEFORE UPDATE ON employees
FOR EACH ROW
BEGIN
    IF NEW.salary < OLD.salary THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Salary decrease not allowed';
    END IF;
END;
//
DELIMITER ;

-- ============================================
-- 5. INSERT SAMPLE DATA
-- ============================================

-- Departments
INSERT INTO departments (department_name, location) VALUES
('Engineering', 'New York'),
('Human Resources', 'Chicago'),
('Finance', 'Boston'),
('Marketing', 'San Francisco');

-- Employees
INSERT INTO employees (name, email, phone, dob, hire_date, salary, department_id, manager_id) VALUES
('Alice Johnson', 'alice@company.com', '1111111111', '1990-04-10', '2020-01-15', 90000, 1, NULL),
('Bob Smith', 'bob@company.com', '2222222222', '1985-07-20', '2018-03-10', 80000, 1, 1),
('Charlie Brown', 'charlie@company.com', '3333333333', '1992-10-05', '2019-06-01', 75000, 2, NULL),
('Diana Prince', 'diana@company.com', '4444444444', '1988-12-12', '2021-05-23', 70000, 3, NULL),
('Ethan Hunt', 'ethan@company.com', '5555555555', '1991-11-01', '2022-02-10', 65000, 4, NULL);

-- Projects
INSERT INTO projects (project_name, start_date, end_date, budget) VALUES
('AI Platform', '2023-01-01', NULL, 500000),
('HR Automation', '2023-02-01', '2023-08-01', 150000),
('Financial Dashboard', '2023-03-01', NULL, 250000);

-- Employee Project Assignment
INSERT INTO employee_projects (employee_id, project_id, role) VALUES
(1,1,'Project Lead'),
(2,1,'Backend Developer'),
(3,2,'HR Analyst'),
(4,3,'Finance Analyst');

-- ============================================
-- 6. VIEWS
-- ============================================

-- Employee full details view
CREATE OR REPLACE VIEW employee_details AS
SELECT 
    e.employee_id,
    e.name,
    e.salary,
    d.department_name,
    m.name AS manager_name
FROM employees e
LEFT JOIN departments d ON e.department_id = d.department_id
LEFT JOIN employees m ON e.manager_id = m.employee_id;

-- Department salary summary
CREATE OR REPLACE VIEW department_salary_summary AS
SELECT 
    d.department_name,
    COUNT(e.employee_id) AS total_employees,
    ROUND(AVG(e.salary),2) AS avg_salary,
    MAX(e.salary) AS highest_salary
FROM departments d
LEFT JOIN employees e ON d.department_id = e.department_id
GROUP BY d.department_name;

-- ============================================
-- 7. STORED PROCEDURES
-- ============================================

-- Get employee projects
DELIMITER //
CREATE PROCEDURE GetEmployeeProjects(IN emp_id INT)
BEGIN
    SELECT p.project_name, ep.role, ep.assigned_date
    FROM employee_projects ep
    JOIN projects p ON ep.project_id = p.project_id
    WHERE ep.employee_id = emp_id;
END;
//
DELIMITER ;

-- Increase salary by percentage
DELIMITER //
CREATE PROCEDURE IncreaseSalary(IN emp_id INT, IN percent DECIMAL(5,2))
BEGIN
    UPDATE employees
    SET salary = salary + (salary * percent / 100)
    WHERE employee_id = emp_id;
END;
//
DELIMITER ;

-- ============================================
-- 8. WINDOW FUNCTIONS
-- ============================================

-- Rank employees by salary within department
SELECT 
    department_id,
    name,
    salary,
    RANK() OVER (PARTITION BY department_id ORDER BY salary DESC) AS salary_rank
FROM employees;

-- Running total of salary per department
SELECT 
    department_id,
    name,
    salary,
    SUM(salary) OVER (PARTITION BY department_id ORDER BY salary DESC) AS cumulative_salary
FROM employees;

-- ============================================
-- 9. BUSINESS QUERIES
-- ============================================

-- Employees without projects
SELECT e.name
FROM employees e
LEFT JOIN employee_projects ep ON e.employee_id = ep.employee_id
WHERE ep.project_id IS NULL;

-- Ongoing projects
SELECT project_name, budget
FROM projects
WHERE end_date IS NULL;

-- Department with highest average salary
SELECT department_name, avg_salary
FROM department_salary_summary
ORDER BY avg_salary DESC
LIMIT 1;

-- ============================================
-- 10. CALL PROCEDURES
-- ============================================

CALL GetEmployeeProjects(1);
CALL IncreaseSalary(2, 10);

-- ============================================
-- 11. FINAL DATA CHECK
-- ============================================

SELECT * FROM employees;
SELECT * FROM employee_details;
SELECT * FROM department_salary_summary;