# Gym de a Dos

App instalable (PWA) para Android y iPhone: rutinas con cargas y series, pasos, agua, peso, cintura, glucosa y suplementos de Braian y Rocío. Los datos se comparten entre los dos teléfonos con Supabase y también quedan guardados en cada teléfono, así que la app abre y deja cargar sin señal.

## Archivos

| Archivo | Qué es |
| --- | --- |
| `index.html` | La app completa (diseño, lógica y guardado). |
| `config.js` | Dirección y clave pública del proyecto de Supabase. |
| `manifest.webmanifest`, `icons/` | Nombre, ícono y colores para instalarla. |
| `sw.js` | Guarda la app en el teléfono para que funcione sin internet. |
| `vendor/supabase.js` | Librería de Supabase (v2.45.4), copiada para que funcione offline. |
| `supabase/schema.sql` | Tabla y reglas de acceso de la base de datos. |

## Puesta en marcha (una sola vez)

### 1. Base de datos en Supabase (gratis)

1. Entrá a <https://supabase.com>, creá una cuenta y un proyecto nuevo (región: São Paulo).
2. **SQL Editor → New query**: pegá el contenido de `supabase/schema.sql` y tocá **Run**.
3. **Authentication → Users → Add user → Create new user**: creá una cuenta para cada uno (tu mail y el de Rocío) con una contraseña, y tildá **Auto Confirm User**. También pueden usar una sola cuenta entre los dos.
4. **Authentication → Sign In / Providers**: desactivá **Allow new users to sign up**, así nadie más puede crearse una cuenta.
5. **Project Settings → API**: copiá **Project URL** y la clave **anon public** dentro de `config.js`.

La clave `anon` es pública por diseño. Lo que protege los datos es el login y las reglas de `schema.sql`: sin iniciar sesión no se puede leer ni escribir nada.

### 2. Publicarla con GitHub Pages (gratis)

La app vive en la carpeta `gym-de-a-dos/` del repositorio `No-man-s-sky`. En el repositorio: **Settings → Pages → Build and deployment → Source: Deploy from a branch → Branch: la rama donde está la carpeta (`main` cuando esté unida, o `claude/artifact-session-9yv1xk`) / `(root)` → Save**. A los minutos queda en `https://braianamir-arch.github.io/No-man-s-sky/gym-de-a-dos/`.

El archivo `.nojekyll` en la raíz del repositorio hace que GitHub Pages publique los archivos tal cual, sin procesarlos.

### 3. Instalarla

- **Android (Chrome)**: abrí el link, menú **⋮ → Instalar app**. La app también muestra un botón **Instalar app**.
- **iPhone (Safari)**: abrí el link en Safari, **Compartir → Agregar a inicio → Agregar**.

La primera vez pide el mail y la contraseña de Supabase. Después queda abierta la sesión.

### 4. Pasar los datos del artifact

En **Ajustes → App → Importar copia**, elegí el archivo `gym-de-a-dos-copia-AAAA-MM-DD.json`. Se suben a la base compartida. Con **Descargar copia** sacás un respaldo cuando quieras.

## Pasos desde el iPhone

El atajo de **Ajustes → Pasos desde el iPhone** abre un link como `https://braianamir-arch.github.io/No-man-s-sky/gym-de-a-dos/#pasos-rocio-8421` y la app guarda los pasos. El atajo abre Safari, que en iPhone guarda la sesión aparte de la app instalada: la primera vez hay que iniciar sesión también en Safari. En Android ninguna página web puede leer Samsung Health, así que los pasos se cargan a mano con el botón de registrar.

## Datos automáticos desde Android (Health Connect)

1. En Supabase → SQL Editor, corré `supabase/pasos.sql` y después `supabase/salud.sql`.
2. En la app: **Ajustes → Pasos y salud automáticos → Crear clave**.
3. Instalá **HC Webhook** gratis desde GitHub (con Obtainium: `https://github.com/mcnaveen/health-connect-webhook`) y seguí los pasos que muestra la app en Ajustes: dirección, tres encabezados (`apikey`, `x-clave`, `x-persona`) y sincronización cada 30 minutos.

Llegan pasos, calorías activas, peso, grasa corporal, sueño, pulso en reposo, minutos de ejercicio y glucosa. El peso cargado a mano en la app tiene prioridad sobre el de la balanza.

## Actualizar la app

Después de cambiar cualquier archivo, subí el número de `CACHE` en `sw.js` (por ejemplo `gym-de-a-dos-v2`). Los teléfonos bajan la versión nueva la próxima vez que abran la app con señal.
