-- Foto produk, izin unggah admin, dan pembaruan dashboard/katalog secara langsung.
-- Aman dijalankan berulang kali.

alter table public.products add column if not exists image_url text;

insert into storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
values ('product-images', 'product-images', true, 5242880, array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set
  public = true,
  file_size_limit = 5242880,
  allowed_mime_types = array['image/jpeg','image/png','image/webp'];

drop policy if exists "Admin uploads product photos" on storage.objects;
create policy "Admin uploads product photos" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'product-images'
    and (storage.foldername(name))[1] = auth.uid()::text
    and public.is_admin());

drop policy if exists "Admin reads own product photos" on storage.objects;
create policy "Admin reads own product photos" on storage.objects
  for select to authenticated
  using (bucket_id = 'product-images'
    and (storage.foldername(name))[1] = auth.uid()::text
    and public.is_admin());

drop policy if exists "Admin updates product photos" on storage.objects;
create policy "Admin updates product photos" on storage.objects
  for update to authenticated
  using (bucket_id = 'product-images'
    and (storage.foldername(name))[1] = auth.uid()::text
    and public.is_admin())
  with check (bucket_id = 'product-images'
    and (storage.foldername(name))[1] = auth.uid()::text
    and public.is_admin());

drop policy if exists "Admin deletes product photos" on storage.objects;
create policy "Admin deletes product photos" on storage.objects
  for delete to authenticated
  using (bucket_id = 'product-images'
    and (storage.foldername(name))[1] = auth.uid()::text
    and public.is_admin());

do $$
declare table_name text;
begin
  foreach table_name in array array['products', 'sales', 'expenses'] loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = table_name
    ) then
      execute format('alter publication supabase_realtime add table public.%I', table_name);
    end if;
  end loop;
end;
$$;

notify pgrst, 'reload schema';
