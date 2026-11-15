-- CajaFácil · Sincronización opcional (Supabase / PostgreSQL)
--
-- Una sola tabla agnóstica al esquema: cada fila de la app viaja como JSON.
-- Ventajas: agregar columnas o tablas en la app no exige migrar el servidor,
-- y la regla de conflictos vive en un solo lugar.
--
-- Cómo aplicarla: Supabase Dashboard > SQL Editor > pegar y ejecutar,
-- o `supabase db push` con la CLI.

create table if not exists public.sync_records (
  -- Cada negocio es la cuenta del dueño en Supabase Auth.
  business_id uuid    not null default auth.uid(),
  entity      text    not null,
  id          text    not null,
  payload     jsonb   not null,
  -- Fecha del cambio en el dispositivo (ms). Base de "último cambio gana".
  updated_at  bigint  not null,
  device_id   text    not null,
  -- Orden del servidor: cursor de descarga. Se renueva en cada cambio.
  seq         bigint  not null,
  primary key (business_id, entity, id)
);

create sequence if not exists public.sync_records_seq;

create index if not exists sync_records_pull_idx
  on public.sync_records (business_id, seq);

-- "Último cambio gana": una versión más vieja no pisa una más nueva.
-- Empate exacto de fecha: gana el device_id mayor (determinista en todos
-- los equipos, igual que en el cliente).
create or replace function public.sync_records_lww()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'UPDATE' then
    if new.updated_at < old.updated_at
       or (new.updated_at = old.updated_at and new.device_id <= old.device_id)
    then
      return null;  -- se descarta el cambio entrante (no se escribe)
    end if;
  end if;
  new.seq := nextval('public.sync_records_seq');
  return new;
end;
$$;

drop trigger if exists sync_records_lww on public.sync_records;
create trigger sync_records_lww
  before insert or update on public.sync_records
  for each row execute function public.sync_records_lww();

-- Seguridad: cada negocio solo ve y escribe sus propios registros.
alter table public.sync_records enable row level security;

drop policy if exists "negocio lee lo suyo" on public.sync_records;
create policy "negocio lee lo suyo" on public.sync_records
  for select using (business_id = auth.uid());

drop policy if exists "negocio escribe lo suyo" on public.sync_records;
create policy "negocio escribe lo suyo" on public.sync_records
  for insert with check (business_id = auth.uid());

drop policy if exists "negocio actualiza lo suyo" on public.sync_records;
create policy "negocio actualiza lo suyo" on public.sync_records
  for update using (business_id = auth.uid())
  with check (business_id = auth.uid());
