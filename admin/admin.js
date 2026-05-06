// Shared admin-panel utilities. Imported by every page as a module.
// The anon key is intentionally bundled here — RLS on the database does the
// actual gating. This same key ships in the iOS App Store build (see
// SECURITY_AUDIT.md in the app repo).

import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm';

const SUPABASE_URL = 'https://pobbjxrhnqufkhxcornw.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBvYmJqeHJobnF1ZmtoeGNvcm53Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzMyMDE5NTksImV4cCI6MjA4ODc3Nzk1OX0.2fuEPVX9dzBfnDoHk-Y57sIo7pnYuT879NGRakkZof0';

export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: {
    persistSession: true,
    storageKey: 'happymaps-admin-auth',
    autoRefreshToken: true,
    detectSessionInUrl: false,
  },
});

// Verify session + admin role. Redirects to /admin/login.html if missing
// either; returns the admin's user row on success.
export async function requireAdmin() {
  const { data: { session } } = await supabase.auth.getSession();
  if (!session) {
    window.location.href = '/admin/login.html';
    return null;
  }

  const { data: user, error } = await supabase
    .from('users')
    .select('id, email, role')
    .eq('id', session.user.id)
    .single();

  if (error || !user || user.role !== 'admin') {
    await supabase.auth.signOut();
    window.location.href = '/admin/login.html?error=not_admin';
    return null;
  }

  return user;
}

export async function signOut() {
  await supabase.auth.signOut();
  window.location.href = '/admin/login.html';
}

// Wires the shared admin-nav: marks active page, binds sign-out button.
// Pages call this after requireAdmin() resolves.
export function initAdminNav() {
  const path = window.location.pathname;
  document.querySelectorAll('.admin-nav-links a').forEach((a) => {
    if (a.getAttribute('href') === path) a.setAttribute('aria-current', 'page');
  });

  const btn = document.getElementById('sign-out-btn');
  if (btn) btn.addEventListener('click', signOut);
}

export function escapeHtml(unsafe) {
  if (unsafe == null) return '';
  return String(unsafe)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}

export function formatRelativeTime(timestamp) {
  if (!timestamp) return '—';
  const now = new Date();
  const then = new Date(timestamp);
  const diffMs = now - then;
  const diffMin = Math.floor(diffMs / 60000);
  const diffHr = Math.floor(diffMs / 3600000);
  const diffDay = Math.floor(diffMs / 86400000);

  if (diffMin < 1) return 'just now';
  if (diffMin < 60) return `${diffMin}m ago`;
  if (diffHr < 24) return `${diffHr}h ago`;
  if (diffDay < 7) return `${diffDay}d ago`;
  return then.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
}

export function formatAbsoluteTime(timestamp) {
  if (!timestamp) return '';
  return new Date(timestamp).toLocaleString('en-US', {
    weekday: 'short', month: 'short', day: 'numeric',
    year: 'numeric', hour: 'numeric', minute: '2-digit',
  });
}

export function formatEventDate(eventDate, startTime, endTime) {
  // event_date is "YYYY-MM-DD"; parse manually so the locale doesn't shift it
  // by a day for users in negative-UTC timezones.
  const [y, m, d] = (eventDate || '').split('-').map(Number);
  if (!y) return '—';
  const date = new Date(y, m - 1, d);
  const dateStr = date.toLocaleDateString('en-US', {
    weekday: 'short', month: 'short', day: 'numeric',
  });
  return `${dateStr} • ${formatTime(startTime)} – ${formatTime(endTime)}`;
}

function formatTime(timeStr) {
  if (!timeStr) return '';
  const [h, m] = timeStr.split(':').map(Number);
  const hour12 = h === 0 ? 12 : h > 12 ? h - 12 : h;
  const period = h < 12 ? 'AM' : 'PM';
  return m === 0 ? `${hour12} ${period}` : `${hour12}:${String(m).padStart(2, '0')} ${period}`;
}

export function formatDateOnly(dateStr) {
  if (!dateStr) return '—';
  const [y, m, d] = dateStr.split('-').map(Number);
  if (!y) return '—';
  return new Date(y, m - 1, d).toLocaleDateString('en-US', {
    month: 'short', day: 'numeric', year: 'numeric',
  });
}

// Lightweight toast. Pass kind = 'success' | 'error' | undefined.
let toastTimer = null;
export function showToast(message, kind) {
  let el = document.getElementById('toast');
  if (!el) {
    el = document.createElement('div');
    el.id = 'toast';
    el.className = 'toast';
    document.body.appendChild(el);
  }
  el.className = 'toast' + (kind ? ` toast-${kind}` : '');
  el.textContent = message;
  // Force reflow so the transition runs even on rapid back-to-back calls.
  void el.offsetWidth;
  el.classList.add('is-shown');
  if (toastTimer) clearTimeout(toastTimer);
  toastTimer = setTimeout(() => el.classList.remove('is-shown'), 3000);
}

// Show or hide a top-of-page error banner. Pages provide a #banner element.
export function showBanner(message) {
  const el = document.getElementById('banner');
  if (!el) return;
  el.textContent = message;
  el.classList.add('is-shown');
}

export function clearBanner() {
  const el = document.getElementById('banner');
  if (el) el.classList.remove('is-shown');
}
