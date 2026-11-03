// Mode demo (?demo) — tiruan Supabase yang jalan di browser dengan data contoh.
// Dipakai buat presentasi: semua fitur bisa dicoba tanpa login & tanpa nyentuh data asli.
// Data tersimpan di HP/laptop ini saja (localStorage) dan bisa di-reset.
(() => {
  const KEY = "loyalty-demo-v1";
  const DAY = 864e5;
  const iso = (t) => new Date(t).toISOString();

  // ---------- data contoh ----------
  function seed() {
    let r = 7;
    const rand = () => ((r = (r * 16807) % 2147483647) / 2147483647);
    const menu = ["Ayam Geprek", "Ayam Crispy", "Ayam Bakar Madu", "Nasi Putih", "Es Teh Manis", "Es Jeruk", "Kentang Goreng"]
      .map((name, i) => ({ id: i + 1, name, active: true }));
    const people = [
      ["Rina Putri", 9, 1], ["Bima Santoso", 6, 2], ["Sari Wulandari", 4, 3], ["Dimas Pratama", 2, 1],
      ["Ayu Lestari", 12, 1], ["Fajar Nugroho", 5, 2], ["Lina Marlina", 3, 7], ["Yoga Saputra", 1, 3],
      ["Nadia Rahma", 8, 3], ["Reza Firmansyah", 2, 2], ["Putri Ayu", 6, 1], ["Hendra Kusuma", 0, 2],
      ["Wulan Sari", 3, 7], ["Andi Wijaya", 7, 2],
    ];
    const now = Date.now();
    const members = [], visits = [], activity = [];
    let visitId = 1;
    people.forEach(([name, freq, fav], i) => {
      const id = "demo-" + (i + 1);
      const code = "LC-D" + String(1000 + i * 37).slice(-4);
      const joined = now - (40 + i * 9) * DAY;
      const mv = [];
      for (let d = Math.floor((now - joined) / DAY); d >= 0; d--) {
        if (rand() > freq / 30) continue;
        const at = now - d * DAY - (rand() * 9 + 1) * 3600e3;
        const items = [{ menu_id: fav, qty: rand() < 0.3 ? 2 : 1 }];
        if (rand() < 0.7) items.push({ menu_id: rand() < 0.6 ? 5 : 6, qty: 1 });
        if (rand() < 0.4) items.push({ menu_id: 4, qty: 1 });
        if (rand() < 0.2) { const x = 1 + Math.floor(rand() * 7); if (!items.some((it) => it.menu_id === x)) items.push({ menu_id: x, qty: 1 }); }
        mv.push({ id: visitId++, member_id: id, created_at: iso(at), items });
      }
      const target = 10;
      const redeemed = Math.floor(mv.length / target);
      members.push({
        id, code, name, phone: "08" + String(1200000000 + i * 7919123).slice(0, 10),
        stamps: Math.min(target, 1 + (mv.length % target)),
        redeemed, last_visit: mv.length ? mv[mv.length - 1].created_at : iso(joined), created_at: iso(joined),
      });
      visits.push(...mv);
      activity.push({ member_id: id, kind: "join", note: `${name} daftar jadi member (bonus 1 stempel)`, created_at: iso(joined) });
      mv.forEach((v, k) => activity.push({ member_id: id, kind: "stamp", note: `${name} dapat stempel`, created_at: v.created_at }));
    });
    // satu orang pas siap tukar hadiah, biar demo tukar hadiah bisa langsung dicoba
    members[1].stamps = 10;
    activity.sort((a, b) => b.created_at.localeCompare(a.created_at));
    return {
      settings: { id: 1, store: "Ayam Garing Juara", target: 10, reward: "1 Paket Ayam Geprek + Es Teh", stamp_cooldown_min: 0 },
      menu, members, visits, activity, session: null,
    };
  }

  let S;
  const load = () => { try { const j = localStorage.getItem(KEY); if (j) return JSON.parse(j); } catch {} return seed(); };
  const save = () => { try { localStorage.setItem(KEY, JSON.stringify(S)); } catch {} };
  S = load();

  // ---------- helper ----------
  const ok = (data, extra) => ({ data, error: null, ...extra });
  const err = (message) => ({ data: null, error: { message } });
  const role = () => S.session?.role || null;
  const isStaff = () => role() === "kasir" || role() === "owner";
  const isOwner = () => role() === "owner";
  const card = (m) => ({ token: m.id, code: m.code, name: m.name, stamps: m.stamps, redeemed: m.redeemed,
    store: S.settings.store, target: S.settings.target, reward: S.settings.reward });
  const log = (m, kind, note) => S.activity.unshift({ member_id: m.id, kind, note, created_at: iso(Date.now()) });
  const menuName = (id) => S.menu.find((x) => x.id === id)?.name || "?";
  // Batas bulan pakai jam lokal browser (di toko = WIB)
  const monthRange = (d) => { const a = new Date(d.getFullYear(), d.getMonth(), 1); const b = new Date(d.getFullYear(), d.getMonth() + 1, 1); return [a.getTime(), b.getTime()]; };
  const ym = (t) => { const d = new Date(t); return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-01`; };

  function favoriteOf(memberId) {
    const tally = {};
    S.visits.filter((v) => v.member_id === memberId).forEach((v) => v.items.forEach((it) => { tally[it.menu_id] = (tally[it.menu_id] || 0) + it.qty; }));
    const best = Object.entries(tally).sort((a, b) => b[1] - a[1] || menuName(+a[0]).localeCompare(menuName(+b[0])))[0];
    return best ? menuName(+best[0]) : null;
  }

  // ---------- fungsi server (meniru supabase/loyalty.sql) ----------
  const rpcs = {
    loyalty_join({ p_name, p_phone, p_consent }) {
      if (p_consent !== true) return err("consent_required");
      let ph = String(p_phone || "").replace(/\D/g, "");
      if (ph.startsWith("62")) ph = "0" + ph.slice(2);
      const name = String(p_name || "").trim();
      if (!name || name.length > 60) return err("invalid_name");
      if (!/^\d{9,15}$/.test(ph)) return err("invalid_phone");
      if (S.members.some((m) => m.phone === ph)) return err("phone_taken");
      const al = "23456789ABCDEFGHJKMNPQRSTUVWXYZ";
      let code; do { code = "LC-" + Array.from({ length: 5 }, () => al[Math.floor(Math.random() * al.length)]).join(""); } while (S.members.some((m) => m.code === code));
      const m = { id: "demo-" + Math.random().toString(36).slice(2, 10), code, name, phone: ph, stamps: 1, redeemed: 0, last_visit: iso(Date.now()), created_at: iso(Date.now()) };
      S.members.unshift(m); log(m, "join", `${name} daftar jadi member (bonus 1 stempel)`);
      return ok(card(m));
    },
    loyalty_get_card({ p_token }) { const m = S.members.find((x) => x.id === p_token); return ok(m ? card(m) : null); },
    loyalty_delete_me({ p_token }) {
      const i = S.members.findIndex((x) => x.id === p_token);
      if (i < 0) return ok(false);
      S.members.splice(i, 1);
      S.visits = S.visits.filter((v) => v.member_id !== p_token);
      S.activity = S.activity.filter((a) => a.member_id !== p_token);
      return ok(true);
    },
    loyalty_is_staff() { return ok(isStaff()); },
    loyalty_is_manager() { return ok(isOwner()); },
    loyalty_lookup({ p_code }) {
      if (!isStaff()) return err("not_staff");
      const c = String(p_code || "").replace(/^loyalty:/i, "").trim().toUpperCase();
      const m = S.members.find((x) => x.code === c);
      return ok(m ? card(m) : null);
    },
    loyalty_add_stamp({ p_member, p_items = [] }) {
      if (!isStaff()) return err("not_staff");
      if (!Array.isArray(p_items) || p_items.some((it) => !S.menu.find((x) => x.id === it.menu_id && x.active) || !(it.qty >= 1 && it.qty <= 50))) return err("invalid_items");
      const m = S.members.find((x) => x.id === p_member);
      if (!m || m.stamps >= S.settings.target) return err("card_full_or_missing");
      const last = S.visits.filter((v) => v.member_id === m.id).map((v) => Date.parse(v.created_at)).sort((a, b) => b - a)[0];
      const cd = S.settings.stamp_cooldown_min;
      if (cd > 0 && last && last > Date.now() - cd * 6e4) return err("too_soon:" + Math.ceil((last + cd * 6e4 - Date.now()) / 6e4));
      const merged = {};
      p_items.forEach((it) => { merged[it.menu_id] = (merged[it.menu_id] || 0) + it.qty; });
      S.visits.push({ id: Date.now(), member_id: m.id, created_at: iso(Date.now()), items: Object.entries(merged).map(([k, q]) => ({ menu_id: +k, qty: q })) });
      m.stamps++; m.last_visit = iso(Date.now());
      log(m, "stamp", `${m.name} dapat stempel ke-${m.stamps}`);
      return ok(card(m));
    },
    loyalty_redeem({ p_member }) {
      if (!isStaff()) return err("not_staff");
      const m = S.members.find((x) => x.id === p_member);
      if (!m || m.stamps < S.settings.target) return err("not_ready");
      m.stamps = 0; m.redeemed++; m.last_visit = iso(Date.now());
      log(m, "redeem", `${m.name} tukar hadiah: ${S.settings.reward}`);
      return ok(card(m));
    },
    loyalty_report({ p_month }) {
      if (!isOwner()) return err("not_manager");
      const [a, b] = monthRange(new Date(p_month + "T00:00:00"));
      const inM = (t) => { const x = Date.parse(t); return x >= a && x < b; };
      const v = S.visits.filter((x) => inM(x.created_at));
      const per = {};
      v.forEach((x) => { per[x.member_id] = (per[x.member_id] || 0) + 1; });
      const qty = {}, cust = {};
      v.forEach((x) => x.items.forEach((it) => { qty[it.menu_id] = (qty[it.menu_id] || 0) + it.qty; (cust[it.menu_id] ||= new Set()).add(x.member_id); }));
      const top = Object.keys(qty).map((k) => ({ name: menuName(+k), qty: qty[k], customers: cust[k].size }))
        .sort((p, q) => q.qty - p.qty || p.name.localeCompare(q.name)).slice(0, 10);
      const customers = S.members.map((m) => {
        const mine = S.visits.filter((x) => x.member_id === m.id);
        const lastAt = mine.map((x) => x.created_at).sort().pop() || null;
        return { id: m.id, code: m.code, name: m.name, phone: m.phone, stamps: m.stamps, redeemed: m.redeemed, created_at: m.created_at,
          visits_month: per[m.id] || 0, visits_total: mine.length, last_visit: lastAt, favorite: favoriteOf(m.id) };
      }).sort((p, q) => q.visits_month - p.visits_month || String(q.last_visit).localeCompare(String(p.last_visit)) || p.name.localeCompare(q.name));
      return ok({
        month: p_month, members_total: S.members.length,
        members_new: S.members.filter((m) => inM(m.created_at)).length,
        visits: v.length, active_customers: Object.keys(per).length,
        redeemed: S.activity.filter((x) => x.kind === "redeem" && inM(x.created_at)).length,
        top_menu: top, customers,
      });
    },
    loyalty_customer({ p_member }) {
      if (!isOwner()) return err("not_manager");
      const m = S.members.find((x) => x.id === p_member);
      if (!m) return ok(null);
      const mine = S.visits.filter((x) => x.member_id === m.id).sort((p, q) => q.created_at.localeCompare(p.created_at));
      const fav = {};
      mine.forEach((v) => v.items.forEach((it) => { const f = (fav[it.menu_id] ||= { qty: 0, visits: 0 }); f.qty += it.qty; f.visits++; }));
      const now = new Date();
      const monthly = [];
      for (let k = 5; k >= 0; k--) {
        const d = new Date(now.getFullYear(), now.getMonth() - k, 1);
        const [a, b] = monthRange(d);
        monthly.push({ month: ym(d), visits: mine.filter((x) => { const t = Date.parse(x.created_at); return t >= a && t < b; }).length });
      }
      return ok({
        id: m.id, code: m.code, name: m.name, phone: m.phone, stamps: m.stamps, redeemed: m.redeemed, created_at: m.created_at,
        favorites: Object.entries(fav).map(([k, f]) => ({ name: menuName(+k), qty: f.qty, visits: f.visits }))
          .sort((p, q) => q.qty - p.qty || p.name.localeCompare(q.name)).slice(0, 5),
        monthly,
        visits: mine.slice(0, 30).map((x) => ({ created_at: x.created_at, items: x.items.map((it) => ({ name: menuName(it.menu_id), qty: it.qty })).sort((p, q) => p.name.localeCompare(q.name)) })),
      });
    },
  };

  // ---------- query builder sederhana untuk tabel ----------
  const tables = {
    loyalty_settings: { rows: () => [S.settings], read: () => true, write: isOwner },
    loyalty_menu: { rows: () => S.menu, read: isStaff, write: isOwner },
    loyalty_members: { rows: () => S.members, read: isOwner, write: () => false },
    loyalty_activity: { rows: () => S.activity, read: isOwner, write: () => false },
  };
  function from(name) {
    const t = tables[name];
    const st = { filters: [], order: null, limit: null, single: false, head: false, update: null, insert: null, select: false };
    const q = {
      select(_c, o) { st.select = true; st.head = !!o?.head; return q; },
      eq(k, v) { st.filters.push((r) => r[k] === v); return q; },
      gte(k, v) { st.filters.push((r) => r[k] >= v); return q; },
      order(k, o) { st.order = [k, o?.ascending !== false]; return q; },
      limit(n) { st.limit = n; return q; },
      single() { st.single = true; return q; },
      update(v) { st.update = v; return q; },
      insert(v) { st.insert = v; return q; },
      then(res, rej) {
        return Promise.resolve().then(() => {
          if (st.insert) {
            if (!t.write()) return err("new row violates row-level security policy");
            const nm = String(st.insert.name || "").trim();
            if (!nm) return err("invalid");
            if (S.menu.some((x) => x.name.toLowerCase() === nm.toLowerCase())) return err("duplicate key value violates unique constraint");
            S.menu.push({ id: Math.max(0, ...S.menu.map((x) => x.id)) + 1, name: nm, active: true }); save();
            return ok(null);
          }
          let rows = t.read() ? t.rows().filter((r) => st.filters.every((f) => f(r))) : [];
          if (st.update) {
            if (!t.write()) return ok([]);
            if ("stamp_cooldown_min" in st.update && !(st.update.stamp_cooldown_min >= 0 && st.update.stamp_cooldown_min <= 240)) return err("check constraint");
            rows.forEach((r) => Object.assign(r, st.update)); save();
          }
          if (st.order) { const [k, asc] = st.order; rows = [...rows].sort((a, b) => (a[k] > b[k] ? 1 : a[k] < b[k] ? -1 : 0) * (asc ? 1 : -1)); }
          if (st.limit) rows = rows.slice(0, st.limit);
          if (st.head) return ok(null, { count: rows.length });
          const out = rows.map((r) => ({ ...r }));
          return ok(st.single ? out[0] ?? null : out);
        }).then(res, rej);
      },
    };
    return q;
  }

  const listeners = [];
  const emit = () => listeners.forEach((f) => f("SIGNED", S.session ? { user: { id: S.session.role } } : null));
  const delay = (v) => new Promise((r) => setTimeout(() => r(v), 120)); // berasa kayak server

  window.createDemoClient = () => ({
    rpc: (fn, args = {}) => delay().then(() => { const out = rpcs[fn] ? rpcs[fn](args) : err("Could not find the function " + fn); save(); return out; }),
    from,
    auth: {
      // email "kasir@demo" atau "owner@demo"
      signInWithPassword: async ({ email }) => { S.session = { role: String(email).startsWith("owner") ? "owner" : "kasir" }; save(); emit(); return { error: null }; },
      signOut: async () => { S.session = null; save(); emit(); return { error: null }; },
      onAuthStateChange: (f) => { listeners.push(f); setTimeout(() => f("INITIAL", S.session ? { user: { id: S.session.role } } : null), 0); },
    },
  });
  window.resetDemo = () => { try { localStorage.removeItem(KEY); localStorage.removeItem("loyalty-card-token-demo"); } catch {} S = seed(); save(); };
})();
