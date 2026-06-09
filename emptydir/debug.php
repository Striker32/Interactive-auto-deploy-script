<?php
// Принудительно включаем отображение всех ошибок
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

echo "Проверка окружения...<br>\n";

// Проверяем наличие самого драйвера PostgreSQL в PHP
if (!extension_loaded('pdo_pgsql')) {
    die("<b>ФАТАЛЬНАЯ ОШИБКА:</b> Расширение 'pdo_pgsql' НЕ установлено в этом PHP-контейнере!");
}
echo "Расширение pdo_pgsql найдено.<br>\n";

$dbUrl = getenv('DATABASE_URL');
echo "DATABASE_URL: " . ($dbUrl ? "Найдена" : "Пусто") . "<br>\n";

try {
    // Парсим DATABASE_URL (postgres://user:pass@host:port/db)
    $dbOpts = parse_url($dbUrl);
    
    $dsn = sprintf(
        "pgsql:host=%s;port=%d;dbname=%s",
        $dbOpts['host'],
        $dbOpts['port'] ?? 5432,
        ltrim($dbOpts['path'], '/')
    );
    
    // Пытаемся подключиться
    $pdo = new PDO($dsn, $dbOpts['user'], $dbOpts['pass']);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    
    echo "<b>Database connection test: SUCCESS!</b>";
} catch (PDOException $e) {
    echo "<b>Database connection test: FAILED!</b><br>\n";
    echo "Ошибка: " . $e->getMessage();
} catch (Exception $e) {
    echo "Неизвестная ошибка: " . $e->getMessage();
}
