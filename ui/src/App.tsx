/* LXR-MARKET — the stalls | © 2026 iBoss21 / LXRCore
   open { payload: { broker, listings[], satchel[], shelf, me, cash, rules }, images } · close
   callbacks: list { slot, amount, price } · buy { id } · cancel { id } · collect · close */
import { useEffect, useMemo, useState } from 'react';
import { onMessage, applyChrome, makeT, post, money, pad, type Msg } from './nui';

type Listing = { id: number; seller: string; sellerName: string; name: string; label: string; description?: string; category: string; rarity?: string; amount: number; price: number; each: number; ledger: number; verdict: 'bargain' | 'fair' | 'dear'; quality?: number; expiresIn: number };
type Carried = { slot: number; name: string; label: string; amount: number; ledger: number; quality?: number; category: string };
type Book = { broker: { id: string; label: string }; listings: Listing[]; satchel: Carried[]; shelf: { money: number; items: { id: number; name: string; label: string; amount: number; note?: string }[] }; me: string; cash: number; rules: { cut: number; fee: number; days: number; max: number; minPrice: number; maxPrice: number } };

export function App() {
  const [B, setB] = useState<Book | null>(null);
  const [L, setL] = useState<Record<string, string>>({});
  const [images, setImages] = useState('');
  const [tab, setTab] = useState<'stalls' | 'mine' | 'sell' | 'shelf'>('stalls');
  const [q, setQ] = useState('');
  const [cat, setCat] = useState('all');
  const [sel, setSel] = useState<number | null>(null);
  const [amount, setAmount] = useState(1);
  const [price, setPrice] = useState('');
  const [busy, setBusy] = useState(false);
  const t = makeT(L);

  useEffect(() => onMessage((m: Msg) => {
    applyChrome(m);
    if (m.locale) setL(m.locale);
    if (m.images) setImages(m.images);
    if (m.action === 'open') { setB(m.payload); setTab('stalls'); setQ(''); setCat('all'); setSel(null); setPrice(''); }
    if (m.action === 'close') setB(null);
  }), []);
  useEffect(() => { const k = (e: KeyboardEvent) => { if (e.key === 'Escape' || (e.key === 'Backspace' && (e.target as HTMLElement).tagName !== 'INPUT')) post('close'); }; document.addEventListener('keydown', k); return () => document.removeEventListener('keydown', k); }, []);

  const img = (name: string) => images + name + '.png';
  const cats = useMemo(() => { const s = new Set<string>(); B?.listings.forEach((l) => { if (l.seller !== B.me) s.add(l.category); }); return [...s].sort(); }, [B]);
  const shown = useMemo(() => { if (!B) return []; const n = q.trim().toLowerCase(); return B.listings.filter((l) => l.seller !== B.me && (cat === 'all' || l.category === cat) && (!n || l.label.toLowerCase().includes(n) || l.sellerName.toLowerCase().includes(n))); }, [B, q, cat]);
  const mine = useMemo(() => B ? B.listings.filter((l) => l.seller === B.me) : [], [B]);
  const picked = useMemo(() => B && sel != null ? B.satchel.find((c) => c.slot === sel) || null : null, [B, sel]);
  const call = async (name: string, body?: any) => { if (busy) return; setBusy(true); const r = await post<{ ok: boolean; data?: Book }>(name, body); setBusy(false); if (r.ok && r.data) { setB(r.data); setSel(null); setPrice(''); } };
  const expires = (s: number) => t('ui.expires', { d: Math.floor(s / 86400), h: Math.floor((s % 86400) / 3600) });

  if (!B) return null;
  const suggested = picked ? Math.round(picked.ledger * amount * 100) / 100 : 0;
  const priceNum = Number(price) || 0;
  const priceOk = priceNum >= B.rules.minPrice && priceNum <= B.rules.maxPrice;

  return (
    <div id="app">
      <header className="mk-top lxr-hit">
        <div className="mk-brand"><img className="mk-logo" src="img/lxrcore-logo.png" alt="" /><div><span className="lxr-mono lxr-t-ash">{t('ui.kicker')}</span><h1 className="lxr-cut mk-title">{B.broker.label}</h1></div></div>
        <span className="lxr-grow" />
        <div className="mk-cash"><span className="lxr-mono lxr-t-smoke">{t('ui.cash')}</span><span className="lxr-num">{money(B.cash)}</span></div>
        <span className="mk-hint lxr-mono lxr-t-smoke"><span className="lxr-key">Esc</span> {t('ui.hint_close')}</span>
      </header>

      <nav className="mk-tabs lxr-hit">
        {(['stalls', 'mine', 'sell', 'shelf'] as const).map((k) => <button key={k} className={'mk-tab' + (tab === k ? ' is-on' : '')} onClick={() => setTab(k)}>{t('ui.' + k)}{k === 'mine' ? <span className="mk-tab__n">{pad(mine.length)}</span> : k === 'shelf' && (B.shelf.money > 0 || B.shelf.items.length > 0) ? <span className="mk-tab__n">•</span> : null}</button>)}
        <span className="lxr-grow" />
        {tab === 'stalls' && <input className="lxr-input mk-search" placeholder={t('ui.search')} value={q} onChange={(e) => setQ(e.target.value)} />}
      </nav>

      {tab === 'stalls' && (
        <>
          <aside className="mk-side lxr-hit">
            <button className={'mk-cat' + (cat === 'all' ? ' is-on' : '')} onClick={() => setCat('all')}><span>{t('ui.all')}</span><span className="mk-cat__n lxr-mono">{B.listings.filter((l) => l.seller !== B.me).length}</span></button>
            {cats.map((c) => <button key={c} className={'mk-cat' + (cat === c ? ' is-on' : '')} onClick={() => setCat(c)}><span>{t('cat.' + c)}</span><span className="mk-cat__n lxr-mono">{B.listings.filter((l) => l.seller !== B.me && l.category === c).length}</span></button>)}
          </aside>
          <section className="mk-grid lxr-hit">
            {shown.length === 0 && <div className="mk-empty lxr-t-smoke">{t('ui.nothing')}</div>}
            {shown.map((l) => (
              <article key={l.id} className={'mk-card is-' + l.verdict + (l.rarity && l.rarity !== 'common' ? ' is-' + l.rarity : '')}>
                <div className="mk-card__pic"><img src={img(l.name)} alt="" onError={(e) => { (e.target as HTMLImageElement).style.visibility = 'hidden'; }} /><span className="mk-badge lxr-mono">{t('ui.' + l.verdict)}</span><span className="mk-amount lxr-mono">×{l.amount}</span></div>
                <div className="mk-card__name">{l.label}</div>
                <div className="mk-card__meta lxr-mono">{t('ui.by')} {l.sellerName}{l.quality != null ? ' · ' + t('ui.quality') + ' ' + l.quality : ''}</div>
                <div className="mk-card__foot">
                  <div><div className="lxr-mono lxr-t-smoke mk-k">{t('ui.ask')}</div><div className="mk-price lxr-num">{money(l.price)}</div><div className="lxr-mono lxr-t-smoke mk-k">{money(l.each)} {t('ui.each')} · {t('ui.ledger')} {money(l.ledger)}</div></div>
                  <span className="lxr-grow" />
                  <button className="lxr-btn lxr-btn-sm" disabled={busy || l.price > B.cash} onClick={() => call('buy', { id: l.id })}>{t('ui.buy')}</button>
                </div>
                <div className="mk-card__exp lxr-mono lxr-t-smoke">{expires(l.expiresIn)}</div>
              </article>
            ))}
          </section>
        </>
      )}

      {tab === 'mine' && (
        <section className="mk-list lxr-hit">
          {mine.length === 0 && <div className="mk-empty lxr-t-smoke">{t('ui.nothing_mine')}</div>}
          {mine.map((l, i) => (
            <div key={l.id} className="lxr-row mk-row">
              <span className="lxr-row-index">{pad(i + 1)}</span>
              <img className="mk-row__img" src={img(l.name)} alt="" onError={(e) => { (e.target as HTMLImageElement).style.visibility = 'hidden'; }} />
              <span className="lxr-row-name">{l.label}</span>
              <span className="lxr-row-sub lxr-mono">×{l.amount} · {money(l.price)} · {expires(l.expiresIn)}</span>
              <span className="lxr-grow" />
              <button className="lxr-btn lxr-btn-ghost lxr-btn-sm" disabled={busy} onClick={() => call('cancel', { id: l.id })}>{t('ui.cancel')}</button>
            </div>
          ))}
        </section>
      )}

      {tab === 'sell' && (
        <>
          <section className="mk-list mk-list--half lxr-hit">
            {B.satchel.length === 0 && <div className="mk-empty lxr-t-smoke">{t('ui.nothing_to_sell')}</div>}
            {B.satchel.map((c, i) => (
              <div key={c.slot} className={'lxr-row mk-row is-pick' + (sel === c.slot ? ' is-on' : '')} onClick={() => { setSel(c.slot); setAmount(1); setPrice(String(Math.max(B.rules.minPrice, Math.round(c.ledger * 100) / 100).toFixed(2))); }}>
                <span className="lxr-row-index">{pad(i + 1)}</span>
                <img className="mk-row__img" src={img(c.name)} alt="" onError={(e) => { (e.target as HTMLImageElement).style.visibility = 'hidden'; }} />
                <span className="lxr-row-name">{c.label}</span>
                <span className="lxr-row-sub lxr-mono">×{c.amount} · {t('ui.ledger')} {money(c.ledger)} {t('ui.each')}</span>
              </div>
            ))}
          </section>
          <aside className="mk-form lxr-hit">
            {!picked && <div className="mk-empty lxr-t-smoke">{t('ui.sell')} —</div>}
            {picked && (
              <>
                <div className="mk-form__name lxr-cut">{picked.label}</div>
                <label className="mk-field"><span className="lxr-mono lxr-t-smoke">{t('ui.amount')}</span><input className="lxr-input" type="number" min={1} max={picked.amount} value={amount} onChange={(e) => { const a = Math.max(1, Math.min(picked.amount, Number(e.target.value) || 1)); setAmount(a); setPrice((Math.round(picked.ledger * a * 100) / 100).toFixed(2)); }} /></label>
                <label className="mk-field"><span className="lxr-mono lxr-t-smoke">{t('ui.price')}</span><input className="lxr-input" inputMode="decimal" value={price} onChange={(e) => setPrice(e.target.value.replace(/[^0-9.]/g, ''))} /></label>
                <div className="lxr-mono lxr-t-smoke mk-note">{t('ui.ledger')} {money(suggested)} · {t('ui.fee')} {money(B.rules.fee)} · {t('ui.cut')} {Math.round(B.rules.cut * 100)}% · {t('ui.days', { n: B.rules.days })}</div>
                {priceNum > 0 && <div className={'mk-verdict lxr-mono is-' + (priceNum / amount <= picked.ledger * 0.8 ? 'bargain' : priceNum / amount >= picked.ledger * 1.6 ? 'dear' : 'fair')}>{t('ui.' + (priceNum / amount <= picked.ledger * 0.8 ? 'bargain' : priceNum / amount >= picked.ledger * 1.6 ? 'dear' : 'fair'))}</div>}
                <button className="lxr-btn" disabled={busy || !priceOk || mine.length >= B.rules.max} onClick={() => call('list', { slot: picked.slot, amount, price: priceNum })}>{t('ui.list_it')}</button>
              </>
            )}
          </aside>
        </>
      )}

      {tab === 'shelf' && (
        <section className="mk-list lxr-hit">
          <div className="mk-shelf__money"><span className="lxr-mono lxr-t-ash">{t('ui.earnings')}</span><span className="lxr-num mk-shelf__n">{money(B.shelf.money)}</span><span className="lxr-grow" /><button className="lxr-btn" disabled={busy || (B.shelf.money <= 0 && B.shelf.items.length === 0)} onClick={() => call('collect')}>{t('ui.collect')}</button></div>
          <div className="lxr-mono lxr-t-ash mk-shelf__head">{t('ui.returned')}</div>
          {B.shelf.items.length === 0 && <div className="mk-empty lxr-t-smoke">—</div>}
          {B.shelf.items.map((it, i) => <div key={it.id} className="lxr-row mk-row"><span className="lxr-row-index">{pad(i + 1)}</span><img className="mk-row__img" src={img(it.name)} alt="" onError={(e) => { (e.target as HTMLImageElement).style.visibility = 'hidden'; }} /><span className="lxr-row-name">{it.label}</span><span className="lxr-row-sub lxr-mono">×{it.amount}{it.note ? ' · ' + it.note : ''}</span></div>)}
        </section>
      )}
    </div>
  );
}
