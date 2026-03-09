-- =====================================================
-- PROJECT 5: HOSPITAL MANAGEMENT SYSTEM
-- =====================================================

-- 1. CREATE DATABASE
DROP DATABASE IF EXISTS hospital_management;
CREATE DATABASE hospital_management;
USE hospital_management;

-- =====================================================
-- 2. TABLES
-- =====================================================

-- Departments
CREATE TABLE departments (
    department_id INT AUTO_INCREMENT PRIMARY KEY,
    department_name VARCHAR(100) UNIQUE NOT NULL
);

-- Doctors (Self Referencing Supervisor)
CREATE TABLE doctors (
    doctor_id INT AUTO_INCREMENT PRIMARY KEY,
    full_name VARCHAR(150) NOT NULL,
    specialization VARCHAR(100),
    salary DECIMAL(12,2) CHECK (salary > 0),
    department_id INT,
    supervisor_id INT,
    FOREIGN KEY (department_id) REFERENCES departments(department_id)
        ON DELETE SET NULL,
    FOREIGN KEY (supervisor_id) REFERENCES doctors(doctor_id)
        ON DELETE SET NULL
);

-- Patients
CREATE TABLE patients (
    patient_id INT AUTO_INCREMENT PRIMARY KEY,
    full_name VARCHAR(150) NOT NULL,
    gender ENUM('Male','Female','Other'),
    dob DATE,
    phone VARCHAR(15),
    address TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Appointments
CREATE TABLE appointments (
    appointment_id INT AUTO_INCREMENT PRIMARY KEY,
    patient_id INT,
    doctor_id INT,
    appointment_date DATETIME,
    status ENUM('Scheduled','Completed','Cancelled') DEFAULT 'Scheduled',
    FOREIGN KEY (patient_id) REFERENCES patients(patient_id) ON DELETE CASCADE,
    FOREIGN KEY (doctor_id) REFERENCES doctors(doctor_id) ON DELETE CASCADE
);

-- Treatments
CREATE TABLE treatments (
    treatment_id INT AUTO_INCREMENT PRIMARY KEY,
    treatment_name VARCHAR(150) NOT NULL,
    cost DECIMAL(10,2) CHECK (cost >= 0)
);

-- Patient Treatments (Many-to-Many)
CREATE TABLE patient_treatments (
    pt_id INT AUTO_INCREMENT PRIMARY KEY,
    appointment_id INT,
    treatment_id INT,
    quantity INT DEFAULT 1,
    FOREIGN KEY (appointment_id) REFERENCES appointments(appointment_id) ON DELETE CASCADE,
    FOREIGN KEY (treatment_id) REFERENCES treatments(treatment_id),
    UNIQUE(appointment_id, treatment_id)
);

-- Billing
CREATE TABLE billing (
    bill_id INT AUTO_INCREMENT PRIMARY KEY,
    appointment_id INT UNIQUE,
    total_amount DECIMAL(12,2),
    payment_status ENUM('Pending','Paid') DEFAULT 'Pending',
    FOREIGN KEY (appointment_id) REFERENCES appointments(appointment_id) ON DELETE CASCADE
);

-- Audit Log
CREATE TABLE audit_log (
    log_id INT AUTO_INCREMENT PRIMARY KEY,
    action_type VARCHAR(50),
    table_name VARCHAR(50),
    action_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =====================================================
-- 3. INDEXES
-- =====================================================

CREATE INDEX idx_patient_phone ON patients(phone);
CREATE INDEX idx_doctor_department ON doctors(department_id);
CREATE INDEX idx_appointment_date ON appointments(appointment_date);
CREATE INDEX idx_bill_status_amount ON billing(payment_status, total_amount);

-- =====================================================
-- 4. TRIGGERS
-- =====================================================

-- Auto create billing after appointment completion
DELIMITER //
CREATE TRIGGER create_bill_after_appointment
AFTER UPDATE ON appointments
FOR EACH ROW
BEGIN
    IF NEW.status = 'Completed' THEN
        INSERT IGNORE INTO billing(appointment_id,total_amount)
        VALUES (NEW.appointment_id,0);
    END IF;
END;
//
DELIMITER ;

-- Update bill amount after adding treatment
DELIMITER //
CREATE TRIGGER update_bill_total
AFTER INSERT ON patient_treatments
FOR EACH ROW
BEGIN
    UPDATE billing b
    SET total_amount = (
        SELECT SUM(t.cost * pt.quantity)
        FROM patient_treatments pt
        JOIN treatments t ON pt.treatment_id = t.treatment_id
        WHERE pt.appointment_id = NEW.appointment_id
    )
    WHERE b.appointment_id = NEW.appointment_id;
END;
//
DELIMITER ;

-- Audit doctor insert
DELIMITER //
CREATE TRIGGER audit_doctor_insert
AFTER INSERT ON doctors
FOR EACH ROW
BEGIN
    INSERT INTO audit_log(action_type, table_name)
    VALUES('INSERT','doctors');
END;
//
DELIMITER ;

-- =====================================================
-- 5. SAMPLE DATA
-- =====================================================

INSERT INTO departments (department_name) VALUES
('Cardiology'),('Neurology'),('Orthopedics');

INSERT INTO doctors (full_name,specialization,salary,department_id,supervisor_id) VALUES
('Dr. Smith','Cardiologist',150000,1,NULL),
('Dr. John','Cardiologist',120000,1,1),
('Dr. Alice','Neurologist',140000,2,NULL);

INSERT INTO patients (full_name,gender,dob,phone,address) VALUES
('Michael Lee','Male','1990-05-10','1111111111','NY'),
('Sara Khan','Female','1995-08-15','2222222222','Chicago');

INSERT INTO treatments (treatment_name,cost) VALUES
('ECG',200),
('MRI Scan',800),
('X-Ray',150);

-- Transaction Example
START TRANSACTION;

INSERT INTO appointments (patient_id,doctor_id,appointment_date)
VALUES (1,1,'2025-03-01 10:00:00');

UPDATE appointments 
SET status='Completed'
WHERE appointment_id=1;

INSERT INTO patient_treatments (appointment_id,treatment_id,quantity)
VALUES (1,1,1);

COMMIT;

-- =====================================================
-- 6. VIEWS
-- =====================================================

CREATE OR REPLACE VIEW appointment_summary AS
SELECT 
    a.appointment_id,
    p.full_name AS patient_name,
    d.full_name AS doctor_name,
    a.status,
    b.total_amount
FROM appointments a
JOIN patients p ON a.patient_id=p.patient_id
JOIN doctors d ON a.doctor_id=d.doctor_id
LEFT JOIN billing b ON a.appointment_id=b.appointment_id;

CREATE OR REPLACE VIEW department_salary_report AS
SELECT 
    d.department_name,
    COUNT(doc.doctor_id) total_doctors,
    ROUND(AVG(doc.salary),2) avg_salary
FROM departments d
LEFT JOIN doctors doc ON d.department_id=doc.department_id
GROUP BY d.department_name;

-- =====================================================
-- 7. STORED PROCEDURE
-- =====================================================

DELIMITER //
CREATE PROCEDURE GetPatientHistory(IN pid INT)
BEGIN
    SELECT 
        a.appointment_date,
        d.full_name AS doctor,
        a.status,
        b.total_amount
    FROM appointments a
    JOIN doctors d ON a.doctor_id=d.doctor_id
    LEFT JOIN billing b ON a.appointment_id=b.appointment_id
    WHERE a.patient_id=pid;
END;
//
DELIMITER ;

-- =====================================================
-- 8. STORED FUNCTION
-- =====================================================

DELIMITER //
CREATE FUNCTION GetDoctorRevenue(doc_id INT)
RETURNS DECIMAL(12,2)
DETERMINISTIC
BEGIN
    DECLARE total DECIMAL(12,2);
    SELECT SUM(b.total_amount)
    INTO total
    FROM appointments a
    JOIN billing b ON a.appointment_id=b.appointment_id
    WHERE a.doctor_id=doc_id;
    RETURN IFNULL(total,0);
END;
//
DELIMITER ;

-- =====================================================
-- 9. WINDOW FUNCTIONS
-- =====================================================

-- Rank doctors by salary within department
SELECT 
    department_id,
    full_name,
    salary,
    RANK() OVER (PARTITION BY department_id ORDER BY salary DESC) salary_rank
FROM doctors;

-- Running total hospital revenue
SELECT 
    appointment_id,
    total_amount,
    SUM(total_amount) OVER (ORDER BY appointment_id) running_revenue
FROM billing;

-- =====================================================
-- 10. CTE
-- =====================================================

WITH high_value_bills AS (
    SELECT bill_id,total_amount
    FROM billing
    WHERE total_amount > 500
)
SELECT * FROM high_value_bills;

-- =====================================================
-- 11. BUSINESS QUERIES
-- =====================================================

-- Top earning doctor
SELECT full_name
FROM doctors
ORDER BY salary DESC
LIMIT 1;

-- Patients without appointments
SELECT full_name
FROM patients
WHERE patient_id NOT IN (SELECT DISTINCT patient_id FROM appointments);

-- Monthly revenue
SELECT 
    DATE_FORMAT(a.appointment_date,'%Y-%m') month,
    SUM(b.total_amount) revenue
FROM appointments a
JOIN billing b ON a.appointment_id=b.appointment_id
GROUP BY month
ORDER BY month;

-- =====================================================
-- 12. CALL EXAMPLES
-- =====================================================

CALL GetPatientHistory(1);
SELECT GetDoctorRevenue(1);

-- =====================================================
-- 13. FINAL CHECK
-- =====================================================

SELECT * FROM appointment_summary;
SELECT * FROM department_salary_report;
SELECT * FROM audit_log;