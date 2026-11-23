-- Gym de a Dos: deja que el atajo del iPhone guarde los pasos sin iniciar sesión.
-- Correlo una vez en Supabase → SQL Editor → New query → Run (después de schema.sql).
-- El atajo tiene que mandar la clave que se crea en la app (Ajustes → Pasos → Crear clave del atajo).

create or replace function public.registrar_pasos(clave text, persona text, pasos integer, fecha date default null)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  dia date := coalesce(fecha, (now() at time zone 'America/Argentina/Buenos_Aires')::date);
  ruta text;
  correcta text;
  ahora bigint := (extract(epoch from now()) * 1000)::bigint;
begin
  select data->>'token' into correcta from public.docs where path = 'settings/steps';
  if correcta is null or clave is distinct from correcta then
    raise exception 'clave incorrecta';
  end if;
  if persona not in ('braian', 'rocio') then
    raise exception 'persona desconocida';
  end if;
  if pasos is null or pasos < 0 or pasos > 200000 then
    raise exception 'pasos fuera de rango';
  end if;
  ruta := 'daily/' || persona || '_' || to_char(dia, 'YYYY-MM-DD');
  insert into public.docs (path, data, updated_at)
  values (ruta, jsonb_build_object('person', persona, 'date', to_char(dia, 'YYYY-MM-DD'), 'steps', pasos, 'stepsSrc', 'iphone', 'updated', ahora), now())
  on conflict (path) do update
    set data = public.docs.data || jsonb_build_object('steps', pasos, 'stepsSrc', 'iphone', 'updated', ahora),
        updated_at = now();
  return 'ok';
end;
$$;

revoke all on function public.registrar_pasos(text, text, integer, date) from public;
grant execute on function public.registrar_pasos(text, text, integer, date) to anon, authenticated;
