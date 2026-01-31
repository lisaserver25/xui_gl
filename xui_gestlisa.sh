# 1. Crear la carpeta
mkdir -p /home/xui/api

# 2. Crear el archivo PHP
nano /home/xui/api/sync-user-to-redis.php
# (pegar el contenido del script PHP)
<?php
// sync-user-to-redis.php
// Endpoint para sincronizar usuario creado por Gestlisa a Redis

require_once __DIR__ . '/../assets/bootloader.php';

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

// Handle preflight
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

$input = json_decode(file_get_contents('php://input'), true);

if (!isset($input['user_id']) || !isset($input['username'])) {
    echo json_encode(['error' => 'Faltan parámetros: user_id, username']);
    exit;
}

$user_id = intval($input['user_id']);
$username = $input['username'];
$password = $input['password'] ?? '';
$exp_date = $input['exp_date'] ?? null;
$bouquets = $input['bouquets'] ?? [];
$allowed_outputs = $input['allowed_outputs'] ?? [1, 2, 3];

try {
    // Inicializar XUI
    XUI::init(true);
    
    // Leer usuario de MySQL
    self::$db->query("SELECT * FROM `lines` WHERE id = ?", $user_id);
    $line = self::$db->get_row();
    
    if (!$line) {
        echo json_encode(['error' => 'Usuario no encontrado en MySQL', 'user_id' => $user_id]);
        exit;
    }
    
    // Generar UUID para el usuario
    $uuid = md5($username . $password . time());
    
    // Preparar datos para Redis
    $redisData = [
        'user_id' => $user_id,
        'username' => $username,
        'password' => $password,
        'identity' => $user_id,
        'uuid' => $uuid,
        'stream_id' => 0,
        'server_id' => defined('SERVER_ID') ? SERVER_ID : 1,
        'date_start' => time(),
        'date_end' => $exp_date ? strtotime($exp_date) : time() + 3650 * 86400,
        'bouquet' => json_encode($bouquets),
        'allowed_outputs' => json_encode($allowed_outputs),
        'is_active' => 1,
        'max_connections' => $line['max_connections'] ?? 1,
        'hls_end' => 0,
    ];
    
    // Insertar en Redis usando la función interna de XUI
    if (method_exists('XUI', 'f0F969dfd05c0d20')) {
        $result = XUI::f0F969dfd05c0d20($redisData);
    } elseif (method_exists('XUI', 'syncUserToRedis')) {
        $result = XUI::syncUserToRedis($redisData);
    } else {
        // Fallback: escribir directamente a Redis
        $redis = new Redis();
        $redis->connect('127.0.0.1', 6379);
        $redis->set("user:{$user_id}", json_encode($redisData));
        $redis->set("username:{$username}", $user_id);
        $result = true;
    }
    
    echo json_encode([
        'success' => true,
        'uuid' => $uuid,
        'user_id' => $user_id,
        'message' => 'Usuario sincronizado a Redis correctamente'
    ]);
    
} catch (Exception $e) {
    echo json_encode([
        'error' => $e->getMessage(),
        'user_id' => $user_id
    ]);
}
?>

# 3. Establecer permisos correctos
chmod 644 /home/xui/api/sync-user-to-redis.php
chown www-data:www-data /home/xui/api/sync-user-to-redis.php
chown www-data:www-data /home/xui/api