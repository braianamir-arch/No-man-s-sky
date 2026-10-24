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

Una automatización de **Atajos** lee los pasos de Salud y los manda directo a Supabase con la función `registrar_pasos` (de `supabase/pasos.sql`), sin abrir Safari ni iniciar sesión. Los pasos para armarla están en la app, en **Ajustes → Pasos y salud automáticos**, con botones para copiar cada dato.

## Datos automáticos desde Android (Health Connect)

1. En Supabase → SQL Editor, corré `supabase/pasos.sql` y después `supabase/salud.sql`.
2. En la app: **Ajustes → Pasos y salud automáticos → Crear clave**.
3. Instalá **HC Webhook** gratis desde GitHub (con Obtainium: `https://github.com/mcnaveen/health-connect-webhook`) y seguí los pasos que muestra la app en Ajustes: dirección, tres encabezados (`apikey`, `x-clave`, `x-persona`) y sincronización cada 30 minutos.

Llegan pasos, calorías activas, peso, grasa corporal, sueño, pulso en reposo, minutos de ejercicio y glucosa. El peso cargado a mano en la app tiene prioridad sobre el de la balanza.

## iPhone: pasos, calorías y ejercicio automáticos

Corré `supabase/iphone.sql` en Supabase. La app muestra en **Ajustes → Pasos y salud automáticos → iPhone** cómo armar el atajo que llama a `registrar_dia` todas las noches.

## Comidas

En **Comidas** se elige a qué comida va (desayuno, almuerzo, merienda o cena; se elige sola según la hora) y se carga de cinco maneras:

- **Lista de alimentos**: ~125 alimentos por grupo con proteína, calorías, carbohidratos y grasas. Tocando el nombre se elige la cantidad (½, 1, 2… o en gramos).
- **Código**: escanea el código de barras del paquete y trae la tabla nutricional de [Open Food Facts](https://world.openfoodfacts.org). En Android usa el lector del navegador; en iPhone, `vendor/zxing.min.js` (ZXing, licencia Apache 2.0).
- **Foto** y **Escribir**: la IA calcula los macros (ver abajo).
- **Frecuentes y recientes**, y **Repetir la comida de ayer**.
- **Cargar a mano**.

La meta de calorías sube un poco los días con más de 8.000 pasos. **¿Qué como ahora?** sugiere qué comer según lo que falta del día. En **Comida y agua** están el resumen de la semana y **Comida y resultados** (alcohol y proteína contra el rendimiento en el gym, calorías contra el peso y carbohidratos contra la glucosa).

### Comidas con IA (foto y texto)

Usa la API de Claude desde una Edge Function de Supabase, así la clave nunca queda en la app:

1. En console.anthropic.com → **API Keys** creá una clave (sirve la misma cuenta que usás para otras cosas; conviene una clave aparte y un límite de gasto en **Billing → Limits**).
2. Supabase → **Edge Functions → Secrets**: agregá `ANTHROPIC_API_KEY`.
3. Supabase → **Edge Functions → Deploy a new function → Via Editor**, nombre `comida-ia`, pegá `supabase/functions/comida-ia/index.ts` y **Deploy**.

Solo la pueden usar las cuentas con sesión iniciada en la app.

## Spotify

Registrá la app en developer.spotify.com/dashboard (los pasos están en **Ajustes → Spotify**) y poné el **Client ID** en `config.js` (`spotifyClientId`). Los controles necesitan Spotify Premium.

## Actualizar la app

Después de cambiar cualquier archivo, subí el número de `CACHE` en `sw.js` (por ejemplo `gym-de-a-dos-v2`). Los teléfonos bajan la versión nueva la próxima vez que abran la app con señal.
