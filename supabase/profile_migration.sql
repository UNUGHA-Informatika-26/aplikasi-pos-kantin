-- Jalankan sekali di Supabase Dashboard > SQL Editor untuk memperbaiki profil.
-- Aman dijalankan berulang kali.

alter table public.profiles add column if not exists phone text;
alter table public.profiles add column if not exists class_name text;
alter table public.profiles add column if not exists address text;
alter table public.profiles add column if not exists avatar_url text;

-- Pengguna dapat memperbarui detail profil dan foto miliknya sendiri, tetapi tidak role.
drop policy if exists "profiles update self" on public.profiles;
create policy "profiles update self" on public.profiles
  for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

grant usage on schema public to authenticated;
grant select on public.profiles to authenticated;
revoke update on public.profiles from authenticated;
grant update (full_name, phone, class_name, address, avatar_url)
  on public.profiles to authenticated;

-- Foto dipublikasikan untuk ditampilkan, tetapi hanya pemilik folder yang dapat mengunggah/mengganti/menghapus.
insert into storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
values ('avatars', 'avatars', true, 5242880, array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set
  public = true,
  file_size_limit = 5242880,
  allowed_mime_types = array['image/jpeg','image/png','image/webp'];

drop policy if exists "Avatar owner upload" on storage.objects;
create policy "Avatar owner upload" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "Avatar owner update" on storage.objects;
create policy "Avatar owner update" on storage.objects
  for update to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "Avatar owner delete" on storage.objects;
create policy "Avatar owner delete" on storage.objects
  for delete to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

-- Akun admin tampil konsisten sebagai Bu Siti.
update public.profiles set full_name = 'Bu Siti' where role = 'admin';

notify pgrst, 'reload schema';
