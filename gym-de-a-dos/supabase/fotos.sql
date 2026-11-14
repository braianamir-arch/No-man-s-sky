-- Gym de a Dos: espacio privado para las fotos de progreso.
-- Correlo una vez en Supabase → SQL Editor → New query → Run.
-- Las fotos solo las pueden ver, subir y borrar las cuentas con sesión iniciada en la app (ustedes dos).

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('progreso', 'progreso', false, 5242880, array['image/jpeg'])
on conflict (id) do nothing;

drop policy if exists "progreso_ver" on storage.objects;
drop policy if exists "progreso_subir" on storage.objects;
drop policy if exists "progreso_borrar" on storage.objects;
create policy "progreso_ver" on storage.objects for select to authenticated using (bucket_id = 'progreso');
create policy "progreso_subir" on storage.objects for insert to authenticated with check (bucket_id = 'progreso');
create policy "progreso_borrar" on storage.objects for delete to authenticated using (bucket_id = 'progreso');
