<?php
// Conexión con XAMPP / MySQL
$servidor = "localhost";
$usuario  = "root";
$clave    = "";
$base_datos = "radisson_db";

$conexion = new mysqli($servidor, $usuario, $clave, $base_datos);

// Verificar la conexión
if ($conexion->connect_error) {
    die("Error de conexión: " . $conexion->connect_error);
}

if ($_SERVER["REQUEST_METHOD"] == "POST") {
    // 1. Recibimos TODOS los campos que envía contacto.html
    $nombre    = $_POST['nombre'];
    $apellidos = $_POST['apellidos'];
    $email     = $_POST['email'];
    $telefono  = $_POST['telefono'];
    $asunto    = $_POST['asunto'];
    $mensaje   = $_POST['mensaje'];

    // 2. Guardamos todos los campos en la tabla 'contacto'
    // Nota: El 'id' se genera automáticamente por ser Auto Increment
    $sql = "INSERT INTO contacto (nombre, apellidos, email, telefono, asunto, mensaje) 
            VALUES ('$nombre', '$apellidos', '$email', '$telefono', '$asunto', '$mensaje')";

    if ($conexion->query($sql) === TRUE) {
        echo "<h2 style='color: #1a4373; text-align: center; margin-top: 50px;'>¡Mensaje enviado con éxito!</h2>";
        echo "<p style='text-align: center;'>Gracias $nombre, hemos recibido tu consulta sobre '$asunto'.</p>";
        echo "<p style='text-align: center;'><a href='contacto.html'>Volver a la página de contacto</a></p>";
    } else {
        echo "Error al guardar el mensaje: " . $conexion->error;
    }
}

$conexion->close();
?>