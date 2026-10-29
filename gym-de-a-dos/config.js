// Datos del proyecto de Supabase (Project Settings → API).
// La "anon key" es pública por diseño: lo que protege los datos es el login y las reglas de supabase/schema.sql.
// Si quedan vacíos, la app funciona igual pero guarda todo solo en el teléfono.
window.GYM_CONFIG = {
  supabaseUrl: "https://kzprocqkxmozomxzyrcu.supabase.co",
  supabaseAnonKey: "sb_publishable_AbbcoVvF5x77uGggKLZZMQ_iZhjf1qk",
  // Spotify (developer.spotify.com/dashboard → la app → Client ID). Vacío: la tarjeta de Spotify no aparece.
  spotifyClientId: "",
  // Comidas con IA (foto y texto). Antes de activarla hay que instalar la función comida-ia en Supabase (ver README).
  comidaIA: false
};
