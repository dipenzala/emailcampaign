'use client';
import { useEffect, useState } from 'react';
import Link from 'next/link';

export default function Landing() {
  const [counts, setCounts] = useState({ emails: 0, users: 0, campaigns: 0, uptime: 0 });

  useEffect(() => {
    // Animate stat counters
    const targets = { emails: 12_847_392, users: 4_218, campaigns: 68_540, uptime: 99 };
    const start = Date.now();
    const duration = 2000;
    const tick = () => {
      const p = Math.min(1, (Date.now() - start) / duration);
      const ease = 1 - Math.pow(1 - p, 3);
      setCounts({
        emails: Math.floor(targets.emails * ease),
        users: Math.floor(targets.users * ease),
        campaigns: Math.floor(targets.campaigns * ease),
        uptime: Math.floor(targets.uptime * ease),
      });
      if (p < 1) requestAnimationFrame(tick);
    };
    tick();
  }, []);

  useEffect(() => {
    // Scroll reveal
    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach(e => {
          if (e.isIntersecting) {
            e.target.classList.add('visible');
          }
        });
      },
      { threshold: 0.1, rootMargin: '0px 0px -50px 0px' }
    );
    document.querySelectorAll('.reveal').forEach(el => observer.observe(el));
    return () => observer.disconnect();
  }, []);

  useEffect(() => {
    // Bento card mouse follow glow
    const cards = document.querySelectorAll('.bento-card');
    const handler = (e: Event) => {
      const card = e.currentTarget as HTMLElement;
      const rect = card.getBoundingClientRect();
      const mx = ((e as MouseEvent).clientX - rect.left) / rect.width * 100;
      const my = ((e as MouseEvent).clientY - rect.top) / rect.height * 100;
      card.style.setProperty('--mx', mx + '%');
      card.style.setProperty('--my', my + '%');
    };
    cards.forEach(c => c.addEventListener('mousemove', handler));
    return () => cards.forEach(c => c.removeEventListener('mousemove', handler));
  }, []);

  const formatNum = (n: number) => n.toLocaleString('en-IN');

  return (
    <div className="landing-root">
      {/* Background layers */}
      <div className="landing-mesh">
        <div className="landing-orb-3" />
      </div>
      <div className="landing-grain" />

      {/* NAV */}
      <nav className="landing-nav">
        <Link href="/" className="landing-nav-brand">
          <div className="landing-nav-mark" />
          <span className="landing-nav-name">EmailCampaign</span>
        </Link>
        <div className="landing-nav-links">
          <a href="#features" className="landing-nav-link">Features</a>
          <a href="#stats" className="landing-nav-link">Stats</a>
          <a href="#cta" className="landing-nav-link">Pricing</a>
        </div>
        <Link href="/login" className="landing-nav-cta">Get started</Link>
      </nav>

      {/* HERO */}
      <section className="landing-hero">
        <div className="landing-badge">
          <span className="landing-badge-dot" />
          <span>Now with AI spam protection · v2.0</span>
        </div>

        <h1 className="landing-title">
          Send email that<br />
          <span className="landing-title-gradient">feels personal.</span>
        </h1>

        <p className="landing-subtitle">
          Production-ready campaign platform with real Gmail OAuth, sender rotation,
          7-layer anti-spam protection, and beautiful live analytics.
        </p>

        <div className="landing-cta-row">
          <Link href="/login" className="landing-cta-primary">
            Start free
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
              <line x1="5" y1="12" x2="19" y2="12" />
              <polyline points="12 5 19 12 12 19" />
            </svg>
          </Link>
          <a href="#features" className="landing-cta-secondary">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
              <polygon points="5 3 19 12 5 21 5 3" />
            </svg>
            See how it works
          </a>
        </div>

        {/* Floating preview with 3D */}
        <div className="landing-preview-wrap">
          <div className="landing-float landing-float-1">
            <span style={{ fontSize: 16 }}>⚡</span>
            <span>3,214 sent today</span>
          </div>
          <div className="landing-float landing-float-2">
            <span style={{ fontSize: 16 }}>🛡️</span>
            <span>0 spam flags</span>
          </div>
          <div className="landing-float landing-float-3">
            <span style={{ fontSize: 16 }}>📬</span>
            <span>98.7% delivered</span>
          </div>

          <div className="landing-preview">
            <div className="landing-preview-top">
              <span className="landing-dot" style={{ background: '#ef4444' }} />
              <span className="landing-dot" style={{ background: '#f59e0b' }} />
              <span className="landing-dot" style={{ background: '#10b981' }} />
              <div className="landing-preview-url">emailcampaign-ten.vercel.app/dashboard/live</div>
            </div>
            <div className="landing-preview-body">
              <div className="landing-preview-kpi">
                <div className="landing-preview-kpi-label">Sent</div>
                <div className="landing-preview-kpi-value" style={{ color: '#3b82f6' }}>12,847</div>
              </div>
              <div className="landing-preview-kpi">
                <div className="landing-preview-kpi-label">Delivered</div>
                <div className="landing-preview-kpi-value" style={{ color: '#10b981' }}>12,412</div>
              </div>
              <div className="landing-preview-kpi">
                <div className="landing-preview-kpi-label">Opened</div>
                <div className="landing-preview-kpi-value" style={{ color: '#ec4899' }}>4,921</div>
              </div>
              <div className="landing-preview-kpi">
                <div className="landing-preview-kpi-label">Pending</div>
                <div className="landing-preview-kpi-value" style={{ color: '#f59e0b' }}>435</div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* TRUSTED BY */}
      <section className="landing-trusted reveal">
        <div className="landing-trusted-label">Built for modern teams</div>
        <div className="landing-trusted-marks">
          {[
            { icon: '🚀', name: 'Startups' },
            { icon: '💼', name: 'Agencies' },
            { icon: '📈', name: 'Growth Teams' },
            { icon: '🎯', name: 'Sales' },
            { icon: '📧', name: 'Marketers' },
          ].map(t => (
            <div key={t.name} className="landing-trusted-mark">
              <span className="landing-trusted-mark-icon">{t.icon}</span>
              {t.name}
            </div>
          ))}
        </div>
      </section>

      {/* STATS */}
      <section id="stats" className="landing-stats reveal">
        <div className="landing-stat">
          <div className="landing-stat-value">{formatNum(counts.emails)}</div>
          <div className="landing-stat-label">Emails Sent</div>
        </div>
        <div className="landing-stat">
          <div className="landing-stat-value">{formatNum(counts.users)}</div>
          <div className="landing-stat-label">Active Users</div>
        </div>
        <div className="landing-stat">
          <div className="landing-stat-value">{formatNum(counts.campaigns)}</div>
          <div className="landing-stat-label">Campaigns</div>
        </div>
        <div className="landing-stat">
          <div className="landing-stat-value">{counts.uptime}%</div>
          <div className="landing-stat-label">Uptime</div>
        </div>
      </section>

      {/* FEATURES — BENTO */}
      <section id="features" className="landing-section">
        <div className="landing-section-head reveal">
          <div className="landing-section-eyebrow">Features</div>
          <h2 className="landing-section-title">
            Everything you need.<br />
            <span style={{ background: 'linear-gradient(120deg, #8b5cf6, #ec4899)', WebkitBackgroundClip: 'text', backgroundClip: 'text', color: 'transparent' }}>
              Nothing you don't.
            </span>
          </h2>
          <p className="landing-section-desc">
            Built on real infrastructure — Gmail API, Postgres, BullMQ, and 7-layer anti-spam.
          </p>
        </div>

        <div className="bento-grid">
          {/* Big card — Live Analytics */}
          <div className="bento-card bento-1 reveal">
            <div className="bento-icon">📊</div>
            <h3 className="bento-title">Real-time Analytics</h3>
            <p className="bento-desc">
              Watch emails fly out live. Every sent, delivered, opened, and bounced
              email tracked in real time with beautiful visualizations.
            </p>
            <div className="bento-visual">
              <div className="bento-chart">
                {[40, 65, 45, 80, 55, 90, 70, 95, 60, 85, 75, 100].map((h, i) => (
                  <div
                    key={i}
                    className="bento-chart-bar"
                    style={{ height: h + '%', animationDelay: (i * 0.15) + 's' }}
                  />
                ))}
              </div>
            </div>
          </div>

          {/* Sender rotation */}
          <div className="bento-card bento-2 reveal">
            <div className="bento-icon">🔄</div>
            <h3 className="bento-title">Sender Rotation</h3>
            <p className="bento-desc">
              Connect 25+ Gmail accounts. Emails auto-rotate one-by-one, max 350/day each.
            </p>
            <div className="bento-visual">
              {['sales01@company.com', 'sales02@company.com', 'sales03@company.com'].map((e, i) => (
                <div key={i} className="bento-sender">
                  <div className="bento-sender-avatar" />
                  <div className="bento-sender-info">
                    <div className="bento-sender-name">{e}</div>
                    <div className="bento-sender-status">● CONNECTED</div>
                  </div>
                  <div className="bento-sender-badge">{350 - i * 10} left</div>
                </div>
              ))}
            </div>
          </div>

          {/* Anti-spam */}
          <div className="bento-card bento-3 reveal">
            <div className="bento-icon">🛡️</div>
            <h3 className="bento-title">7-Layer Anti-Spam</h3>
            <p className="bento-desc">
              Spam scoring, warm-up mode, list hygiene, bounce handling, and
              auto-suppression keep your sender reputation pristine.
            </p>
            <div className="bento-visual">
              <div style={{ display: 'flex', gap: 8, alignItems: 'center', marginBottom: 12 }}>
                <div style={{ fontSize: 32, fontWeight: 800, color: '#10b981', letterSpacing: '-0.03em' }}>12</div>
                <div>
                  <div style={{ fontSize: 11, color: '#64748b', fontWeight: 600 }}>SPAM SCORE</div>
                  <div style={{ fontSize: 12, color: '#10b981', fontWeight: 700 }}>✓ Safe to send</div>
                </div>
              </div>
              <div style={{ height: 6, background: 'rgba(15,23,42,0.06)', borderRadius: 999, overflow: 'hidden' }}>
                <div style={{ height: '100%', width: '12%', background: 'linear-gradient(90deg, #10b981, #8b5cf6)' }} />
              </div>
            </div>
          </div>

          {/* Excel import */}
          <div className="bento-card bento-4 reveal">
            <div className="bento-icon">📥</div>
            <h3 className="bento-title">Excel / CSV Import</h3>
            <p className="bento-desc">
              Upload contacts, auto-validate, remove duplicates, filter disposables.
            </p>
          </div>

          {/* HTML editor */}
          <div className="bento-card bento-5 reveal">
            <div className="bento-icon">✏️</div>
            <h3 className="bento-title">HTML Editor</h3>
            <p className="bento-desc">
              Paste your HTML. Live desktop + mobile preview. Test email before launch.
            </p>
          </div>

          {/* Inbox viewer */}
          <div className="bento-card bento-6 reveal">
            <div className="bento-icon">📬</div>
            <h3 className="bento-title">Inbox Viewer</h3>
            <p className="bento-desc">
              Read client replies directly. Track who opened your emails.
            </p>
          </div>
        </div>
      </section>

      {/* FINAL CTA */}
      <section id="cta" className="landing-final-cta reveal">
        <div className="landing-final-cta-inner">
          <h2 className="landing-final-cta-title">
            Ready to send at scale?
          </h2>
          <p className="landing-final-cta-desc">
            Connect your Gmail. Import contacts. Hit send. Watch it fly.
          </p>
          <Link href="/login" className="landing-final-cta-btn">
            Get started free
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
              <line x1="5" y1="12" x2="19" y2="12" />
              <polyline points="12 5 19 12 12 19" />
            </svg>
          </Link>
        </div>
      </section>

      {/* FOOTER */}
      <footer className="landing-footer">
        <div className="landing-footer-brand">
          <div className="landing-nav-mark" />
          <span className="landing-nav-name">EmailCampaign</span>
        </div>
        <div className="landing-footer-text">
          © {new Date().getFullYear()} EmailCampaign · Made with care by Dipen Zala
        </div>
      </footer>
    </div>
  );
}
