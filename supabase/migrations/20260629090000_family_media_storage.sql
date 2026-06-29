-- Private media bucket for activity photos + milestone keepsakes (Hard Rule #16).
-- Files are path-scoped by the OWNER's user id as the first folder segment, so RLS
-- on storage.objects keeps each family's media private; read via short-lived signed
-- URLs only. delete-child already purges this bucket on account/child deletion.
-- 10 MB size cap + image mime allowlist (Hard Rule #16 size cap).

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('family-media', 'family-media', false, 10485760,
        array['image/jpeg', 'image/png', 'image/webp', 'image/heic'])
on conflict (id) do nothing;

-- Owner-only access: the first path segment must equal the caller's uid.
create policy "family_media_insert" on storage.objects for insert to authenticated
  with check (bucket_id = 'family-media' and (storage.foldername(name))[1] = (select auth.uid())::text);

create policy "family_media_select" on storage.objects for select to authenticated
  using (bucket_id = 'family-media' and (storage.foldername(name))[1] = (select auth.uid())::text);

create policy "family_media_update" on storage.objects for update to authenticated
  using (bucket_id = 'family-media' and (storage.foldername(name))[1] = (select auth.uid())::text);

create policy "family_media_delete" on storage.objects for delete to authenticated
  using (bucket_id = 'family-media' and (storage.foldername(name))[1] = (select auth.uid())::text);
