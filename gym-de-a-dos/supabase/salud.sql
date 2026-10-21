-- Gym de a Dos: recibe los datos de Health Connect que manda la app HC Webhook (Android).
-- Correlo una vez en Supabase → SQL Editor → New query → Run (después de schema.sql y pasos.sql).
--
-- HC Webhook hace POST a  <Project URL>/rest/v1/rpc/recibir_salud  con estos encabezados:
--   apikey:     la clave pública del proyecto
--   x-clave:    la clave del atajo (la app la muestra en Ajustes → Pasos)
--   x-persona:  braian o rocio
--
-- Cada registro se guarda una sola vez (por su id de Health Connect) y después se recalcula el día:
-- pasos, calorías activas, peso, grasa corporal, sueño, pulso en reposo, minutos de ejercicio y glucosa.

create table if not exists public.salud_registros (
  persona  text not null,
  tipo     text not null,
  rid      text not null,
  inicio   timestamptz not null,
  fin      timestamptz,
  valor    numeric,
  origen   text,
  extra    jsonb,
  recibido timestamptz not null default now(),
  primary key (persona, tipo, rid)
);

alter table public.salud_registros enable row level security;
drop policy if exists "salud_select" on public.salud_registros;
create policy "salud_select" on public.salud_registros for select to authenticated using (true);

create or replace function public.recibir_salud(jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  p        jsonb := $1;
  h        jsonb := coalesce(nullif(current_setting('request.headers', true), '')::jsonb, '{}'::jsonb);
  v_quien  text  := lower(trim(h->>'x-persona'));
  v_clave  text  := h->>'x-clave';
  correcta text;
  zona     text  := 'America/Argentina/Buenos_Aires';
  tipos    text[] := array['steps', 'active_calories', 'weight', 'body_fat', 'blood_glucose', 'sleep', 'resting_heart_rate', 'exercise', 'distance'];
  t        text;
  r        jsonb;
  v_ini    timestamptz;
  v_fin    timestamptz;
  v_val    numeric;
  v_rid    text;
  dias     date[] := '{}';
  d        date;
  n        int := 0;
  ruta     text;
  doc      jsonb;
  manual   jsonb;
  glu      jsonb;
  pasos    numeric;
  kcal     numeric;
  peso     numeric;
  grasa    numeric;
  sueno    numeric;
  pulso    numeric;
  ejer     numeric;
  ahora    bigint := (extract(epoch from now()) * 1000)::bigint;
begin
  select data->>'token' into correcta from public.docs where path = 'settings/steps';
  if correcta is null or v_clave is distinct from correcta then
    raise exception 'clave incorrecta';
  end if;
  if v_quien is null or v_quien not in ('braian', 'rocio') then
    raise exception 'persona desconocida';
  end if;

  -- Registros que Health Connect avisa que se borraron
  for r in select * from jsonb_array_elements(coalesce(p->'deleted', '[]'::jsonb)) loop
    for v_ini, v_fin, t in
      delete from public.salud_registros s
       where s.persona = v_quien and s.rid = r->>'id'
      returning s.inicio, s.fin, s.tipo
    loop
      dias := array_append(dias, ((case when t = 'sleep' then coalesce(v_fin, v_ini) else v_ini end) at time zone zona)::date);
    end loop;
  end loop;

  -- Registros nuevos o editados
  foreach t in array tipos loop
    for r in select * from jsonb_array_elements(coalesce(p->t, '[]'::jsonb)) loop
      if t = 'sleep' then
        v_fin := (r->>'session_end_time')::timestamptz;
        v_ini := v_fin - make_interval(secs => coalesce((r->>'duration_seconds')::numeric, 0));
      else
        v_ini := coalesce(r->>'start_time', r->>'time')::timestamptz;
        v_fin := (r->>'end_time')::timestamptz;
      end if;
      continue when v_ini is null;
      v_val := case t
        when 'steps'              then (r->>'count')::numeric
        when 'active_calories'    then (r->>'calories')::numeric
        when 'weight'             then (r->>'kilograms')::numeric
        when 'body_fat'           then (r->>'percentage')::numeric
        when 'blood_glucose'      then round((r->>'mmol_per_liter')::numeric * 18.016)
        when 'sleep'              then (r->>'duration_seconds')::numeric
        when 'resting_heart_rate' then (r->>'bpm')::numeric
        when 'exercise'           then (r->>'duration_seconds')::numeric
        when 'distance'           then (r->>'meters')::numeric
      end;
      continue when v_val is null;
      v_rid := coalesce(r->'metadata'->>'id', t || ':' || v_ini::text || ':' || coalesce(v_fin::text, ''));
      insert into public.salud_registros (persona, tipo, rid, inicio, fin, valor, origen, extra)
      values (v_quien, t, v_rid, v_ini, v_fin, v_val, r->'metadata'->>'data_origin', r)
      on conflict (persona, tipo, rid) do update
        set inicio = excluded.inicio, fin = excluded.fin, valor = excluded.valor,
            origen = excluded.origen, extra = excluded.extra, recibido = now();
      n := n + 1;
      dias := array_append(dias, ((case when t = 'sleep' then v_fin else v_ini end) at time zone zona)::date);
    end loop;
  end loop;

  -- Recalcular cada día tocado (solo los últimos 60 días)
  for d in select distinct x from unnest(dias) x where x >= (now() at time zone zona)::date - 60 loop
    -- Pasos y calorías: suma por app de origen y se queda con la mayor, para no contar dos veces teléfono y reloj
    select max(s) into pasos from (
      select sum(valor) s from public.salud_registros
       where persona = v_quien and tipo = 'steps' and (inicio at time zone zona)::date = d
       group by coalesce(origen, '')) x;
    select max(s) into kcal from (
      select sum(valor) s from public.salud_registros
       where persona = v_quien and tipo = 'active_calories' and (inicio at time zone zona)::date = d
       group by coalesce(origen, '')) x;
    select valor into peso from public.salud_registros
     where persona = v_quien and tipo = 'weight' and (inicio at time zone zona)::date = d order by inicio desc limit 1;
    select valor into grasa from public.salud_registros
     where persona = v_quien and tipo = 'body_fat' and (inicio at time zone zona)::date = d order by inicio desc limit 1;
    select max(valor) into sueno from public.salud_registros
     where persona = v_quien and tipo = 'sleep' and (fin at time zone zona)::date = d;
    select valor into pulso from public.salud_registros
     where persona = v_quien and tipo = 'resting_heart_rate' and (inicio at time zone zona)::date = d order by inicio desc limit 1;
    select sum(valor) into ejer from public.salud_registros
     where persona = v_quien and tipo = 'exercise' and (inicio at time zone zona)::date = d;
    select coalesce(jsonb_agg(jsonb_build_object('id', 'hc-' || rid, 't', to_char(inicio at time zone zona, 'HH24:MI'),
                                                 'v', valor::int, 'ctx', 'other', 'src', 'hc') order by inicio), '[]'::jsonb)
      into glu from public.salud_registros
     where persona = v_quien and tipo = 'blood_glucose' and (inicio at time zone zona)::date = d;

    ruta := 'daily/' || v_quien || '_' || to_char(d, 'YYYY-MM-DD');
    select data into doc from public.docs where path = ruta;
    doc := coalesce(doc, jsonb_build_object('person', v_quien, 'date', to_char(d, 'YYYY-MM-DD')));

    if pasos is not null then doc := doc || jsonb_build_object('steps', round(pasos)::int, 'stepsSrc', 'hc'); end if;
    if kcal  is not null then doc := doc || jsonb_build_object('activeKcal', round(kcal)::int); end if;
    -- El peso cargado a mano en la app tiene prioridad sobre el de la balanza
    if peso  is not null and (doc->'weight' is null or doc->>'weightSrc' = 'hc') then
      doc := doc || jsonb_build_object('weight', round(peso, 1), 'weightSrc', 'hc');
    end if;
    if grasa is not null then doc := doc || jsonb_build_object('bodyFat', round(grasa, 1)); end if;
    if sueno is not null then doc := doc || jsonb_build_object('sleepMin', round(sueno / 60)::int); end if;
    if pulso is not null then doc := doc || jsonb_build_object('restingHr', round(pulso)::int); end if;
    if ejer  is not null then doc := doc || jsonb_build_object('exerciseMin', round(ejer / 60)::int); end if;
    -- Glucosa: se conservan las mediciones cargadas a mano y se reemplazan las que vinieron del teléfono
    select coalesce(jsonb_agg(e), '[]'::jsonb) into manual
      from jsonb_array_elements(coalesce(doc->'glucose', '[]'::jsonb)) e
     where coalesce(e->>'src', '') <> 'hc';
    if jsonb_array_length(glu) > 0 or jsonb_array_length(coalesce(doc->'glucose', '[]'::jsonb)) <> jsonb_array_length(manual) then
      doc := jsonb_set(doc, '{glucose}', manual || glu);
    end if;
    doc := doc || jsonb_build_object('updated', ahora);

    insert into public.docs (path, data, updated_at) values (ruta, doc, now())
    on conflict (path) do update set data = excluded.data, updated_at = now();
  end loop;

  return jsonb_build_object('ok', true, 'registros', n, 'dias', (select count(distinct x) from unnest(dias) x));
end;
$$;

revoke all on function public.recibir_salud(jsonb) from public;
grant execute on function public.recibir_salud(jsonb) to anon, authenticated;
