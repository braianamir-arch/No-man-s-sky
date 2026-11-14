-- Gym de a Dos: una tabla con todos los registros (sesiones, días, rutinas, perfiles).
-- Correlo una vez en Supabase → SQL Editor → New query → Run.

create table if not exists public.docs (
  path text primary key,
  data jsonb not null,
  updated_at timestamptz not null default now()
);

alter table public.docs enable row level security;

-- Solo las cuentas que inician sesión en la app pueden leer y escribir.
drop policy if exists "docs_select" on public.docs;
drop policy if exists "docs_insert" on public.docs;
drop policy if exists "docs_update" on public.docs;
drop policy if exists "docs_delete" on public.docs;
create policy "docs_select" on public.docs for select to authenticated using (true);
create policy "docs_insert" on public.docs for insert to authenticated with check (true);
create policy "docs_update" on public.docs for update to authenticated using (true) with check (true);
create policy "docs_delete" on public.docs for delete to authenticated using (true);

-- Avisa a los dos teléfonos al instante cuando el otro carga algo.
alter table public.docs replica identity full;
do $$ begin
  alter publication supabase_realtime add table public.docs;
exception when duplicate_object then null;
end $$;
