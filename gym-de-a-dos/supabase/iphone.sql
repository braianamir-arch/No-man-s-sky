-- Gym de a Dos: el atajo del iPhone manda pasos, calorías activas y minutos de ejercicio del día.
-- Correlo una vez en Supabase → SQL Editor → New query → Run (después de pasos.sql).
-- POST <Project URL>/rest/v1/rpc/registrar_dia  con el encabezado apikey y un JSON:
--   { "clave": "...", "persona": "rocio", "pasos": 8421, "kcal": 380, "ejercicio": 42 }

create or replace function public.registrar_dia(
  clave text, persona text,
  pasos integer default null, kcal numeric default null, ejercicio numeric default null, fecha date default null)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  dia date := coalesce(fecha, (now() at time zone 'America/Argentina/Buenos_Aires')::date);
  ruta text;
  correcta text;
  cambios jsonb := '{}'::jsonb;
  ahora bigint := (extract(epoch from now()) * 1000)::bigint;
begin
  select data->>'token' into correcta from public.docs where path = 'settings/steps';
  if correcta is null or clave is distinct from correcta then
    raise exception 'clave incorrecta';
  end if;
  if persona not in ('braian', 'rocio') then
    raise exception 'persona desconocida';
  end if;
  if pasos is not null then
    if pasos < 0 or pasos > 200000 then raise exception 'pasos fuera de rango'; end if;
    cambios := cambios || jsonb_build_object('steps', pasos, 'stepsSrc', 'iphone');
  end if;
  if kcal is not null and kcal >= 0 and kcal < 20000 then
    cambios := cambios || jsonb_build_object('activeKcal', round(kcal)::int);
  end if;
  if ejercicio is not null and ejercicio >= 0 and ejercicio < 1440 then
    cambios := cambios || jsonb_build_object('exerciseMin', round(ejercicio)::int);
  end if;
  if cambios = '{}'::jsonb then
    return 'sin datos';
  end if;
  ruta := 'daily/' || persona || '_' || to_char(dia, 'YYYY-MM-DD');
  insert into public.docs (path, data, updated_at)
  values (ruta, jsonb_build_object('person', persona, 'date', to_char(dia, 'YYYY-MM-DD'), 'updated', ahora) || cambios, now())
  on conflict (path) do update
    set data = public.docs.data || cambios || jsonb_build_object('updated', ahora),
        updated_at = now();
  return 'ok';
end;
$$;

revoke all on function public.registrar_dia(text, text, integer, numeric, numeric, date) from public;
grant execute on function public.registrar_dia(text, text, integer, numeric, numeric, date) to anon, authenticated;
