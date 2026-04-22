-- ─────────────────────────────────────────────────────────────────────────────
-- HappyMaps: Public preview RPCs for web link previews
-- Paste into Supabase SQL Editor and run as-is.
--
-- Each function is SECURITY DEFINER so it bypasses RLS and can be called
-- by the anon role from the public web preview pages. Visibility gating is
-- enforced inside the function, not by RLS, so a private crawl never leaks
-- full details — it returns only {id, name, color, visibility, is_private:true}.
--
-- get_user_preview intentionally returns only display_name / username /
-- school / avatar_url — never email, phone, or anything sensitive.
-- ─────────────────────────────────────────────────────────────────────────────


-- ── 1. Crawl preview ─────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_crawl_preview(crawl_id UUID)
RETURNS JSON
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  result       JSON;
  v_visibility TEXT;
BEGIN
  SELECT visibility INTO v_visibility
  FROM public.crawls
  WHERE id = crawl_id;

  IF v_visibility IS NULL THEN
    RETURN NULL; -- crawl not found
  END IF;

  IF v_visibility = 'friends' THEN
    -- Minimal preview — do not expose date, stops, or organizer
    SELECT json_build_object(
      'id',         c.id,
      'name',       c.name,
      'color',      c.color,
      'visibility', c.visibility,
      'is_private', true
    ) INTO result
    FROM public.crawls c
    WHERE c.id = crawl_id;

  ELSE
    -- Full preview for 'public' and 'school' crawls
    SELECT json_build_object(
      'id',         c.id,
      'name',       c.name,
      'color',      c.color,
      'visibility', c.visibility,
      'date',       c.date,
      'organizer',  json_build_object(
        'display_name', u.display_name,
        'username',     u.username,
        'avatar_url',   u.avatar_url
      ),
      'stops', (
        SELECT json_agg(
          json_build_object(
            'order',        cs.stop_order,
            'arrival_time', cs.arrival_time,
            'bar_name',     b.name,
            'neighborhood', b.neighborhood
          )
          ORDER BY cs.stop_order
        )
        FROM public.crawl_stops cs
        JOIN public.bars b ON b.id = cs.bar_id
        WHERE cs.crawl_id = c.id
      ),
      'member_count', (
        SELECT COUNT(*)
        FROM public.crawl_members
        WHERE crawl_id = c.id
          AND status = 'accepted'
      ),
      'is_private', false
    ) INTO result
    FROM public.crawls c
    JOIN public.users u ON u.id = c.organizer_id
    WHERE c.id = crawl_id;
  END IF;

  RETURN result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_crawl_preview(UUID) TO anon;


-- ── 2. Group preview ─────────────────────────────────────────────────────────
-- Groups have visibility 'friends' | 'school' (no 'public').
-- 'school'  → full preview (same gating logic as crawls)
-- 'friends' → minimal preview

CREATE OR REPLACE FUNCTION public.get_group_preview(group_id UUID)
RETURNS JSON
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  result       JSON;
  v_visibility TEXT;
BEGIN
  SELECT visibility INTO v_visibility
  FROM public.groups
  WHERE id = group_id;

  IF v_visibility IS NULL THEN
    RETURN NULL; -- group not found
  END IF;

  IF v_visibility = 'friends' THEN
    SELECT json_build_object(
      'id',         g.id,
      'name',       g.name,
      'color',      g.color,
      'visibility', g.visibility,
      'is_private', true
    ) INTO result
    FROM public.groups g
    WHERE g.id = group_id;

  ELSE
    -- 'school': full preview
    SELECT json_build_object(
      'id',         g.id,
      'name',       g.name,
      'color',      g.color,
      'visibility', g.visibility,
      'school',     g.school,
      'organizer',  json_build_object(
        'display_name', u.display_name,
        'username',     u.username,
        'avatar_url',   u.avatar_url
      ),
      'member_count', (
        SELECT COUNT(*)
        FROM public.group_members
        WHERE group_id = g.id
          AND status IN ('organizer', 'accepted')
      ),
      'is_private', false
    ) INTO result
    FROM public.groups g
    JOIN public.users u ON u.id = g.organizer_id
    WHERE g.id = group_id;
  END IF;

  RETURN result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_group_preview(UUID) TO anon;


-- ── 3. Bar preview (always public — no gating) ───────────────────────────────
CREATE OR REPLACE FUNCTION public.get_bar_preview(bar_id UUID)
RETURNS JSON
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  result JSON;
BEGIN
  SELECT json_build_object(
    'id',          b.id,
    'name',        b.name,
    'bar_type',    b.bar_type,
    'neighborhood', b.neighborhood,
    'address',     b.address,
    'price_range', b.price_range
  ) INTO result
  FROM public.bars b
  WHERE b.id = bar_id;

  RETURN result; -- NULL if bar not found
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_bar_preview(UUID) TO anon;


-- ── 4. User profile preview (always minimal) ─────────────────────────────────
-- /u/:username uses the username slug, not a UUID, so the param is TEXT.
-- Returns only what's safe for public display. Never returns email,
-- phone, age, or any other PII.

CREATE OR REPLACE FUNCTION public.get_user_preview(p_username TEXT)
RETURNS JSON
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  result JSON;
BEGIN
  SELECT json_build_object(
    'display_name', u.display_name,
    'username',     u.username,
    'school',       u.school,
    'avatar_url',   u.avatar_url
  ) INTO result
  FROM public.users u
  WHERE u.username = p_username;

  RETURN result; -- NULL if user not found
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_user_preview(TEXT) TO anon;


-- ── Verification query (run after applying above) ────────────────────────────
SELECT
  proname                                          AS function_name,
  prosecdef                                        AS security_definer,
  has_function_privilege('anon', oid, 'EXECUTE')  AS anon_can_execute
FROM pg_proc
WHERE pronamespace = 'public'::regnamespace
  AND proname IN (
    'get_crawl_preview',
    'get_group_preview',
    'get_bar_preview',
    'get_user_preview'
  )
ORDER BY proname;
