-- 심플가계부 데이터베이스 (03-data.md 3번)
-- Supabase → SQL Editor → New query 에 전체를 붙여넣고 Run 하세요.
-- 처음 한 번만 실행해요.

-- ============================================================
-- 1. 내역: 수입·지출 한 건이 한 줄
-- ============================================================
create table public.transactions (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users (id) on delete cascade,
  date        date not null,
  kind        text not null check (kind in ('income', 'expense')),
  category    text not null,
  currency    text not null default 'KRW' check (currency in ('KRW', 'USD', 'JPY')),
  amount      numeric(14, 2) not null check (amount > 0),     -- 원래 금액
  krw_amount  bigint not null check (krw_amount >= 0),        -- 원화 금액 (모든 합계 기준)
  rate        numeric(14, 6),                                 -- 외화일 때 환율
  pay_type    text not null check (pay_type in ('card', 'cash', 'transfer')),
  pay_org     text,                                           -- 카드사·은행 (선택)
  memo        text,
  source      text not null default 'manual' check (source in ('manual', 'auto', 'paste')),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index transactions_user_date_idx on public.transactions (user_id, date);

-- ============================================================
-- 2. 예산: 달 · 소항목마다 한 줄
-- ============================================================
create table public.budgets (
  user_id   uuid not null default auth.uid() references auth.users (id) on delete cascade,
  month     text not null check (month ~ '^\d{4}-\d{2}$'),    -- 예: 2026-10
  category  text not null,
  amount    bigint not null check (amount >= 0),
  primary key (user_id, month, category)
);

-- ============================================================
-- 3. 소항목 설정: 켜기/끄기, 순서 (바꾼 것만 저장)
-- ============================================================
create table public.category_settings (
  user_id     uuid not null default auth.uid() references auth.users (id) on delete cascade,
  category    text not null,
  enabled     boolean not null default true,
  sort_order  integer,
  primary key (user_id, category)
);

-- ============================================================
-- 4. 고정 항목 자동 기록 규칙
-- ============================================================
create table public.recurring_rules (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null default auth.uid() references auth.users (id) on delete cascade,
  kind         text not null check (kind in ('income', 'expense')),
  category     text not null,
  day          integer not null check (day between 1 and 31),  -- 없는 날이면 그 달 마지막 날
  amount       bigint not null check (amount > 0),
  pay_type     text not null check (pay_type in ('card', 'cash', 'transfer')),
  pay_org      text,
  active       boolean not null default true,
  start_month  text not null check (start_month ~ '^\d{4}-\d{2}$'),
  created_at   timestamptz not null default now()
);

-- ============================================================
-- 5. 자동 기록 실행 기록: 같은 규칙 · 같은 달은 한 번만
-- ============================================================
create table public.recurring_runs (
  rule_id         uuid not null references public.recurring_rules (id) on delete cascade,
  month           text not null check (month ~ '^\d{4}-\d{2}$'),
  user_id         uuid not null default auth.uid() references auth.users (id) on delete cascade,
  transaction_id  uuid references public.transactions (id) on delete set null,
  primary key (rule_id, month)
);

-- ============================================================
-- 6. 앱 설정: 사용자마다 한 줄
-- ============================================================
create table public.app_settings (
  user_id            uuid primary key default auth.uid() references auth.users (id) on delete cascade,
  last_pay_type      text check (last_pay_type in ('card', 'cash', 'transfer')),
  last_pay_org       text,
  last_report_month  text check (last_report_month ~ '^\d{4}-\d{2}$'),
  pay_org_order      jsonb,
  updated_at         timestamptz not null default now()
);

-- ============================================================
-- 고친 시간 자동 기록
-- ============================================================
create function public.set_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger transactions_updated_at before update on public.transactions
  for each row execute function public.set_updated_at();

create trigger app_settings_updated_at before update on public.app_settings
  for each row execute function public.set_updated_at();

-- ============================================================
-- 보안 잠금 (RLS): 로그인한 본인 데이터만 읽고 쓰기
-- ============================================================
do $$
declare t text;
begin
  foreach t in array array[
    'transactions', 'budgets', 'category_settings',
    'recurring_rules', 'recurring_runs', 'app_settings'
  ] loop
    execute format('alter table public.%I enable row level security', t);
    execute format(
      'create policy "own rows" on public.%I for all to authenticated
         using (user_id = (select auth.uid()))
         with check (user_id = (select auth.uid()))', t);
    execute format('grant select, insert, update, delete on public.%I to authenticated', t);
  end loop;
end;
$$;

-- ============================================================
-- 회원 탈퇴: 내 계정을 지우면 위 표의 내 데이터도 모두 함께 지워져요
-- ============================================================
create function public.delete_my_account() returns void
language plpgsql security definer set search_path = '' as $$
begin
  delete from auth.users where id = auth.uid();
end;
$$;

revoke execute on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
