-- Удаляем таблицу, если она осталась от прошлых экспериментов
DROP TABLE IF EXISTS devtestops_status;

-- Создаем простую таблицу для проверки структуры
CREATE TABLE devtestops_status (
    id INT PRIMARY KEY,
    step_name VARCHAR(100) NOT NULL,
    status VARCHAR(50) NOT NULL,
    verified_at VARCHAR(50)
);

-- Наполняем базу тестовыми данными
INSERT INTO devtestops_status (id, step_name, status, verified_at) VALUES
(1, 'Database Provisioning', 'SUCCESS', '2026-05-21'),
(2, 'Auto Import Mechanism', 'WORKING', '2026-05-21'),
(3, 'DevTestOps Infrastructure', 'FULLY_OPERATIONAL', '2026-05-21');
