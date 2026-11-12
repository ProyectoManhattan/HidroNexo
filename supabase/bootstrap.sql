-- Agua y Lluvia: preparación inicial de un proyecto Supabase vacío.
-- Ejecutar una sola vez en Supabase > SQL Editor.
-- Las tablas NO se crean aquí: Alembic las crea después desde FastAPI.

begin;

create schema if not exists extensions;
create extension if not exists postgis with schema extensions;

commit;

-- Comprobación: debe devolver una fila con schema = extensions.
select
    extension_name,
    extension_version,
    extension_schema
from (
    select
        e.extname as extension_name,
        e.extversion as extension_version,
        n.nspname as extension_schema
    from pg_extension e
    join pg_namespace n on n.oid = e.extnamespace
) extensiones
where extension_name = 'postgis';
