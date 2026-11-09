-- POS Kantin Bu Siti. Jalankan seluruh berkas ini di Supabase SQL Editor.
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default 'Pembeli',
  phone text,
  class_name text,
  address text,
  avatar_url text,
  role text not null default 'buyer' check (role in ('admin','buyer')),
  created_at timestamptz not null default now()
);

-- Tambahan profil untuk database yang sebelumnya sudah memakai skema lama.
alter table public.profiles add column if not exists phone text;
alter table public.profiles add column if not exists class_name text;
alter table public.profiles add column if not exists address text;
alter table public.profiles add column if not exists avatar_url text;

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  category text not null default 'Lainnya',
  price numeric(12,2) not null check (price >= 0),
  stock integer not null default 0 check (stock >= 0),
  image_url text,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);
alter table public.products add column if not exists image_url text;

create table if not exists public.sales (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.profiles(id),
  total numeric(12,2) not null default 0,
  status text not null default 'pending' check (status in ('pending','paid','cancelled')),
  payment_method text not null default 'cash' check (payment_method = 'cash'),
  created_at timestamptz not null default now()
);

create table if not exists public.sale_items (
  id uuid primary key default gen_random_uuid(),
  sale_id uuid not null references public.sales(id) on delete cascade,
  product_id uuid references public.products(id),
  quantity integer not null check (quantity > 0),
  unit_price numeric(12,2) not null check (unit_price >= 0)
);

create table if not exists public.expenses (
  id uuid primary key default gen_random_uuid(),
  description text not null,
  amount numeric(12,2) not null check (amount > 0),
  created_by uuid not null default auth.uid() references public.profiles(id),
  created_at timestamptz not null default now()
);

create or replace function public.is_admin() returns boolean language sql stable security definer set search_path = public as $$
  select exists(select 1 from public.profiles where id = auth.uid() and role = 'admin');
$$;

create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles(id, full_name) values(new.id, coalesce(new.raw_user_meta_data->>'full_name','Pembeli')) on conflict (id) do nothing;
  return new;
end;
$$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();

create or replace function public.checkout_cash(p_items jsonb) returns uuid language plpgsql security definer set search_path = public as $$
declare v_sale uuid; v_total numeric(12,2) := 0; v_item jsonb; v_product public.products%rowtype; v_qty integer;
begin
  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then raise exception 'Keranjang kosong'; end if;
  insert into public.sales(customer_id) values(auth.uid()) returning id into v_sale;
  for v_item in select * from jsonb_array_elements(p_items) loop
    v_qty := (v_item->>'quantity')::integer;
    if v_qty < 1 then raise exception 'Jumlah produk tidak valid'; end if;
    select * into v_product from public.products where id = (v_item->>'product_id')::uuid and is_active = true for update;
    if not found then raise exception 'Produk tidak tersedia'; end if;
    if v_product.stock < v_qty then raise exception 'Stok % tidak mencukupi', v_product.name; end if;
    update public.products set stock = stock - v_qty where id = v_product.id;
    insert into public.sale_items(sale_id, product_id, quantity, unit_price) values(v_sale, v_product.id, v_qty, v_product.price);
    v_total := v_total + v_product.price * v_qty;
  end loop;
  update public.sales set total = v_total where id = v_sale;
  return v_sale;
end;
$$;

alter table public.profiles enable row level security;
alter table public.products enable row level security;
alter table public.sales enable row level security;
alter table public.sale_items enable row level security;
alter table public.expenses enable row level security;

drop policy if exists "profiles read self or admin" on public.profiles;
create policy "profiles read self or admin" on public.profiles for select to authenticated using(id = auth.uid() or public.is_admin());
drop policy if exists "profiles update self" on public.profiles;
create policy "profiles update self" on public.profiles for update to authenticated using(id = auth.uid()) with check(id = auth.uid());
drop policy if exists "products visible" on public.products;
create policy "products visible" on public.products for select to authenticated using(is_active or public.is_admin());
drop policy if exists "admin manages products" on public.products;
create policy "admin manages products" on public.products for all to authenticated using(public.is_admin()) with check(public.is_admin());
drop policy if exists "sales buyer or admin read" on public.sales;
create policy "sales buyer or admin read" on public.sales for select to authenticated using(customer_id = auth.uid() or public.is_admin());
drop policy if exists "buyer creates own sale" on public.sales;
create policy "buyer creates own sale" on public.sales for insert to authenticated with check(customer_id = auth.uid());
drop policy if exists "admin updates sales" on public.sales;
create policy "admin updates sales" on public.sales for update to authenticated using(public.is_admin()) with check(public.is_admin());
drop policy if exists "sale item read owner or admin" on public.sale_items;
create policy "sale item read owner or admin" on public.sale_items for select to authenticated using(exists(select 1 from public.sales s where s.id = sale_id and (s.customer_id = auth.uid() or public.is_admin())));
drop policy if exists "buyer adds own sale items" on public.sale_items;
create policy "buyer adds own sale items" on public.sale_items for insert to authenticated with check(exists(select 1 from public.sales s where s.id = sale_id and s.customer_id = auth.uid()));
drop policy if exists "admin manages expenses" on public.expenses;
create policy "admin manages expenses" on public.expenses for all to authenticated using(public.is_admin()) with check(public.is_admin());

grant usage on schema public to authenticated;
grant select on public.profiles to authenticated;
revoke update on public.profiles from authenticated;
grant update (full_name, phone, class_name, address, avatar_url) on public.profiles to authenticated;
grant select, insert, update on public.products to authenticated;
grant select, update on public.sales to authenticated;
grant select on public.sale_items to authenticated;
grant select, insert, update, delete on public.expenses to authenticated;
grant execute on function public.checkout_cash(jsonb) to authenticated;
grant execute on function public.is_admin() to authenticated;

create unique index if not exists products_name_category_unique on public.products(name, category);
insert into public.products(name, category, price, stock) values
  ('Nasi kuning', 'Makanan', 8000, 20), ('Mie goreng', 'Makanan', 7000, 15),
  ('Es teh manis', 'Minuman', 3000, 30), ('Air mineral', 'Minuman', 3000, 24),
  ('Roti cokelat', 'Snack', 4000, 12)
on conflict (name, category) do nothing;

-- Foto profil disimpan di Supabase Storage; setiap pengguna hanya dapat mengganti berkas miliknya.
insert into storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
values ('avatars', 'avatars', true, 5242880, array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public = true, file_size_limit = 5242880,
  allowed_mime_types = array['image/jpeg','image/png','image/webp'];
drop policy if exists "Avatar owner upload" on storage.objects;
create policy "Avatar owner upload" on storage.objects for insert to authenticated
with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "Avatar owner update" on storage.objects;
create policy "Avatar owner update" on storage.objects for update to authenticated
using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text)
with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "Avatar owner delete" on storage.objects;
create policy "Avatar owner delete" on storage.objects for delete to authenticated
using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

insert into storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
values ('product-images', 'product-images', true, 5242880, array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public = true, file_size_limit = 5242880,
  allowed_mime_types = array['image/jpeg','image/png','image/webp'];
drop policy if exists "Admin uploads product photos" on storage.objects;
create policy "Admin uploads product photos" on storage.objects for insert to authenticated
with check (bucket_id = 'product-images' and (storage.foldername(name))[1] = auth.uid()::text
  and public.is_admin());
drop policy if exists "Admin reads own product photos" on storage.objects;
create policy "Admin reads own product photos" on storage.objects for select to authenticated
using (bucket_id = 'product-images' and (storage.foldername(name))[1] = auth.uid()::text
  and public.is_admin());
drop policy if exists "Admin updates product photos" on storage.objects;
create policy "Admin updates product photos" on storage.objects for update to authenticated
using (bucket_id = 'product-images' and (storage.foldername(name))[1] = auth.uid()::text
  and public.is_admin())
with check (bucket_id = 'product-images' and (storage.foldername(name))[1] = auth.uid()::text
  and public.is_admin());
drop policy if exists "Admin deletes product photos" on storage.objects;
create policy "Admin deletes product photos" on storage.objects for delete to authenticated
using (bucket_id = 'product-images' and (storage.foldername(name))[1] = auth.uid()::text
  and public.is_admin());

do $$
declare table_name text;
begin
  foreach table_name in array array['products', 'sales', 'expenses'] loop
    if not exists (select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = table_name) then
      execute format('alter publication supabase_realtime add table public.%I', table_name);
    end if;
  end loop;
end;
$$;

-- Setelah mendaftar akun Bu Siti melalui aplikasi, jalankan:
-- update public.profiles set role = 'admin' where id = (select id from auth.users where email = 'EMAIL_BU_SITI');
