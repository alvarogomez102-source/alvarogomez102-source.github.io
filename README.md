<div align="center">

# 🏨 Radisson · Página web demo

**Sitio web de un hotel con HTML, CSS y PHP + MySQL**
*Incluye formulario de contacto con base de datos y panel de administración local.*

<br>

<a href="http://alvarogomez102-source.github.io">
  <img src="https://img.shields.io/badge/🌐%20%20P%C3%A1gina%20Web-Ver%20online-1a4373?style=for-the-badge" alt="Página Web">
</a>
&nbsp;&nbsp;
<a href="https://docs.google.com/document/d/1M3b4cBOtNvs1t_Iz6RLAJhgOda8sweUBQUK7Vz_qz3Y/edit?usp=sharing">
  <img src="https://img.shields.io/badge/📄%20%20Documento-Abrir%20memoria-c9a227?style=for-the-badge" alt="Documento">
</a>

<br><br>

![HTML5](https://img.shields.io/badge/HTML5-E34F26?style=flat-square&logo=html5&logoColor=white)
![CSS3](https://img.shields.io/badge/CSS3-1572B6?style=flat-square&logo=css3&logoColor=white)
![PHP](https://img.shields.io/badge/PHP-777BB4?style=flat-square&logo=php&logoColor=white)
![MariaDB](https://img.shields.io/badge/MySQL%20%2F%20MariaDB-003545?style=flat-square&logo=mariadb&logoColor=white)
![Windows](https://img.shields.io/badge/Windows%2010%2F11-0078D4?style=flat-square&logo=windows&logoColor=white)

</div>

---

## 📚 Índice

[Qué es](#-qué-es-este-proyecto) · [Ejecutar en local](#-ejecutar-en-local-un-solo-comando) · [Panel admin](#-panel-de-administración) · [Estructura](#-estructura-del-proyecto) · [Problemas](#-solución-de-problemas) · [Desinstalar](#-desinstalar)

---

## ✨ Qué es este proyecto

Una web de demostración para un hotel, con las siguientes páginas:

| Página | Archivo |
|---|---|
| Inicio | `index.html` |
| Habitaciones | `habitaciones.html` |
| Servicios | `servicios.html` |
| Disponibilidad | `disponibilidad.html` |
| Contacto | `contacto.html` → envía los datos a `procesar.php` |

El formulario de **contacto** guarda cada mensaje en una base de datos MySQL (`radisson_db`, tabla `contacto`) mediante `procesar.php`.

> ⚠️ **Importante:** en la versión online ([Página Web](http://alvarogomez102-source.github.io)) solo funciona la parte estática. GitHub Pages **no ejecuta PHP**, así que el formulario de contacto únicamente funciona ejecutando el proyecto en local (ver abajo).

---

## 🚀 Ejecutar en local (un solo comando)

No necesitas instalar nada antes: ni XAMPP, ni PHP, ni MySQL, ni permisos de administrador. El instalador descarga versiones portables y lo deja todo listo.

**Requisitos:** Windows 10/11 de 64 bits, conexión a internet y ~1,5 GB libres.

### Opción A · Desde este repositorio (descargado o clonado)

```
.\install.cmd
```

*(o haz doble clic sobre `install.cmd`)*

### Opción B · Directamente desde GitHub, sin descargar nada

Abre **PowerShell** y pega:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -c "irm https://raw.githubusercontent.com/alvarogomez102-source/alvarogomez102-source.github.io/main/install.ps1 | iex"
```

### Qué hace el instalador

1. ✅ **Comprueba los requisitos** antes de descargar nada (Windows 64 bits, espacio en disco, runtime de Visual C++).
2. 📦 Instala **PHP** y **MariaDB** portables en `%LOCALAPPDATA%\RadissonDemo` (sin admin, sin tocar el registro ni el PATH).
3. 🗄️ Crea la base de datos `radisson_db` y la tabla `contacto`.
4. ▶️ Arranca el servidor y **abre el navegador** automáticamente.

La primera vez tarda unos minutos (descargas). Las siguientes veces arranca en segundos.

### Direcciones

| Qué | URL |
|---|---|
| Web | `http://127.0.0.1:8080/` |
| Panel admin | `http://127.0.0.1:8080/admin` |

> Si el puerto 8080 está ocupado, se usa el siguiente libre (8081, 8082…). La dirección exacta aparece en la consola.

### Detener

Pulsa **`Ctrl + C`** en la ventana. La base de datos se apaga sola de forma limpia.

---

## 🔐 Panel de administración

Para consultar los mensajes recibidos desde el formulario de contacto:

1. Abre `http://127.0.0.1:8080/admin`
2. Inicia sesión:

| Usuario | Contraseña |
|---|---|
| `admin` | `admin` |

Podrás ver todos los mensajes (los más recientes primero) y **buscar** por nombre, email, asunto o texto del mensaje.

> 🔒 El servidor solo escucha en `127.0.0.1`, por lo que únicamente es accesible desde tu propio equipo. Estas credenciales son solo para la demo local: **no las uses en un servidor público**.

---

## 🗂️ Estructura del proyecto

```
.
├── index.html            Página de inicio
├── habitaciones.html
├── servicios.html
├── disponibilidad.html
├── contacto.html         Formulario de contacto
├── procesar.php          Guarda el formulario en MySQL
├── Estilo/               Hojas de estilo CSS
├── Icono/                Iconos
├── Imagenes/             Imágenes
├── install.cmd           Lanzador de un solo comando (Windows)
└── install.ps1           Instalador + servidor local
```

Todo lo que instala el script vive **fuera** del proyecto, en `%LOCALAPPDATA%\RadissonDemo`:

```
RadissonDemo/
├── tools/php/       PHP portable
├── tools/mariadb/   MariaDB portable
├── data/            Datos de la base de datos (tus mensajes)
└── server/          Router y panel /admin
```

---

## 🛠️ Solución de problemas

| Mensaje / síntoma | Causa | Solución |
|---|---|---|
| `Visual C++ runtime is missing…` | Falta el runtime de Microsoft y sin admin no se puede instalar | Instálalo una vez ([descarga](https://aka.ms/vs/17/release/vc_redist.x64.exe)) o ejecuta el comando desde un PowerShell como administrador |
| `cannot run on this machine` | Antivirus o AppLocker bloquean `%LOCALAPPDATA%` | Permite la carpeta `RadissonDemo` en el antivirus |
| Error al descargar | Sin internet, proxy o firewall | Revisa la conexión y vuelve a ejecutar; el instalador reanuda donde lo dejó |
| El formulario da error de conexión | La base de datos no arrancó | Cierra la ventana, vuelve a ejecutar el comando y revisa `%LOCALAPPDATA%\RadissonDemo\mariadb.log.err` |
| Sale `Sin datos.` en `/admin` | Todavía no se ha enviado ningún mensaje | Rellena el formulario en `/contacto.html` |

Si algo falla, el instalador **se detiene con un mensaje claro** y no modifica nada fuera de `%LOCALAPPDATA%\RadissonDemo`.

---

## 🧹 Desinstalar

Borra la carpeta:

```
%LOCALAPPDATA%\RadissonDemo
```

Eso elimina PHP, MariaDB y los mensajes guardados. No queda nada más en el sistema.

---

<div align="center">

Hecho con ❤️ por Todas las Inteligencias Artificiales que existen.

</div>
