-- Momzo schema · 07 · COPPA parental consent (Task 9)
--
-- Verifiable parental consent must be recorded BEFORE any child data is collected
-- (COPPA-first; Hard Rules #14/#15). `consents` is the auditable record; a trigger
-- on `children` HARD-BLOCKS child creation until a consent row exists for the owner.

create table public.consents (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references public.users (id) on delete cascade,
  policy_version text not null,                 -- which privacy-policy version was shown
  method         text not null,                 -- how consent was obtained (see METHOD NOTE)
  granted_at     timestamptz not null default now(),
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

create trigger consents_set_updated_at
  before update on public.consents
  for each row execute function public.set_updated_at();

create index idx_consents_user on public.consents (user_id);

-- RLS: a parent sees/creates only their own consent records. No client update or
-- delete — consents are an immutable audit trail (removed only when the user is).
alter table public.consents enable row level security;
create policy consents_self_select on public.consents
  for select to authenticated using ((select auth.uid()) = user_id);
create policy consents_self_insert on public.consents
  for insert to authenticated with check ((select auth.uid()) = user_id);

-- Hard gate: cannot create a child profile unless the owning parent has consented.
-- Enforced in the DB so it fires even for service_role and can never be bypassed by
-- a client bug. (This is a separate trigger, not an RLS policy, so the EXISTS check
-- here doesn't conflict with the "direct-comparison policies" rule, Hard Rule #3.)
create or replace function public.require_consent_for_child()
returns trigger
language plpgsql
as $$
begin
  if not exists (select 1 from public.consents c where c.user_id = new.owner_id) then
    raise exception 'parental consent required before creating a child profile'
      using errcode = 'check_violation';
  end if;
  return new;
end;
$$;

create trigger children_require_consent
  before insert on public.children
  for each row execute function public.require_consent_for_child();

-- METHOD NOTE (launch blocker): the MVP records method = 'parent_attestation' (the
-- parent affirms they are the child's parent/guardian and consents). Full COPPA
-- "verifiable parental consent" for a US launch needs a stronger method (card
-- charge, signed form, gov-ID, or knowledge-based auth). Upgrade before real-mom
-- launch — together with re-enabling email confirmation and finalizing the
-- privacy policy. This migration guarantees consent is RECORDED, not its strength.
