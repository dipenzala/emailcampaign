#!/usr/bin/env bash
set -e

echo "==============================================="
echo " 🎨 PREMIUM 3D LANDING PAGE"
echo "==============================================="

cd "$(dirname "$0")" 2>/dev/null || true
[ -f "package.json" ] || { echo "❌ project root me chalao"; exit 1; }
echo "📁 $(pwd)"
echo ""

# ==========================================
# 1. ADD LANDING CSS
# ==========================================
echo "🎨 [1/3] Adding landing animations CSS..."

cat >> app/globals.css <<'CSSEOF'

/* ══════════════════════════════════════════════ */
/*           PREMIUM LANDING PAGE                  */
/* ══════════════════════════════════════════════ */

.landing-root {
  position: relative;
  overflow-x: hidden;
  background: #f8fafc;
  min-height: 100vh;
}

/* -------- MESH GRADIENT BACKGROUND -------- */
.landing-mesh {
  position: fixed;
  inset: 0;
  z-index: 0;
  pointer-events: none;
  overflow: hidden;
}
.landing-mesh::before,
.landing-mesh::after {
  content: '';
  position: absolute;
  border-radius: 50%;
  filter: blur(100px);
  opacity: 0.5;
  will-change: transform;
}
.landing-mesh::before {
  width: 700px;
  height: 700px;
  top: -300px;
  left: -200px;
  background: radial-gradient(circle, #8b5cf6 0%, transparent 70%);
  animation: orbFloat1 20s ease-in-out infinite;
}
.landing-mesh::after {
  width: 600px;
  height: 600px;
  bottom: -200px;
  right: -200px;
  background: radial-gradient(circle, #ec4899 0%, transparent 70%);
  animation: orbFloat2 24s ease-in-out infinite;
}
@keyframes orbFloat1 {
  0%, 100% { transform: translate(0, 0) scale(1); }
  33% { transform: translate(80px, 60px) scale(1.15); }
  66% { transform: translate(-40px, 100px) scale(0.95); }
}
@keyframes orbFloat2 {
  0%, 100% { transform: translate(0, 0) scale(1.1); }
  50% { transform: translate(-100px, -80px) scale(0.9); }
}

.landing-orb-3 {
  position: absolute;
  width: 400px;
  height: 400px;
  top: 40%;
  left: 50%;
  background: radial-gradient(circle, #3b82f6 0%, transparent 70%);
  border-radius: 50%;
  filter: blur(100px);
  opacity: 0.35;
  animation: orbFloat3 28s ease-in-out infinite;
}
@keyframes orbFloat3 {
  0%, 100% { transform: translate(-50%, -50%) scale(1); }
  50% { transform: translate(-30%, -70%) scale(1.2); }
}

/* -------- NOISE / GRAIN -------- */
.landing-grain {
  position: fixed;
  inset: 0;
  z-index: 1;
  pointer-events: none;
  opacity: 0.35;
  mix-blend-mode: overlay;
  background-image: url("data:image/svg+xml,%3Csvg viewBox='0 0 200 200' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='n'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.85' numOctaves='4' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23n)'/%3E%3C/svg%3E");
}

/* -------- NAVIGATION -------- */
.landing-nav {
  position: fixed;
  top: 16px;
  left: 50%;
  transform: translateX(-50%);
  z-index: 100;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  padding: 10px 12px 10px 20px;
  border-radius: 999px;
  background: rgba(255, 255, 255, 0.72);
  backdrop-filter: blur(24px) saturate(180%);
  -webkit-backdrop-filter: blur(24px) saturate(180%);
  border: 1px solid rgba(15, 23, 42, 0.06);
  box-shadow:
    0 8px 32px -8px rgba(15, 23, 42, 0.08),
    inset 0 1px 0 rgba(255, 255, 255, 0.9);
  max-width: calc(100% - 32px);
  width: 720px;
  animation: navSlideDown 0.8s cubic-bezier(.22, 1, .36, 1) both;
}
@keyframes navSlideDown {
  from { opacity: 0; transform: translate(-50%, -30px); }
  to { opacity: 1; transform: translate(-50%, 0); }
}

.landing-nav-brand {
  display: flex;
  align-items: center;
  gap: 10px;
  text-decoration: none;
  color: inherit;
}
.landing-nav-mark {
  width: 32px;
  height: 32px;
  border-radius: 10px;
  background: linear-gradient(135deg, #8b5cf6 0%, #ec4899 100%);
  position: relative;
  overflow: hidden;
  box-shadow: 0 4px 12px rgba(139, 92, 246, 0.35);
}
.landing-nav-mark::after {
  content: '';
  position: absolute;
  inset: 0;
  background: linear-gradient(135deg, transparent 40%, rgba(255, 255, 255, 0.5) 50%, transparent 60%);
  transform: translateX(-100%);
  animation: navShine 3.5s ease-in-out infinite;
}
@keyframes navShine {
  0%, 100% { transform: translateX(-100%); }
  50% { transform: translateX(100%); }
}
.landing-nav-name {
  font-weight: 700;
  font-size: 14px;
  letter-spacing: -0.02em;
  color: #0f172a;
}
.landing-nav-links {
  display: flex;
  align-items: center;
  gap: 4px;
}
.landing-nav-link {
  font-size: 13px;
  font-weight: 500;
  color: #64748b;
  text-decoration: none;
  padding: 8px 14px;
  border-radius: 999px;
  transition: all .2s;
}
.landing-nav-link:hover {
  color: #0f172a;
  background: rgba(15, 23, 42, 0.04);
}
.landing-nav-cta {
  font-size: 13px;
  font-weight: 600;
  padding: 9px 18px;
  border-radius: 999px;
  background: linear-gradient(135deg, #0f172a 0%, #1e293b 100%);
  color: #fff;
  text-decoration: none;
  transition: all .25s;
  box-shadow: 0 4px 12px rgba(15, 23, 42, 0.15);
}
.landing-nav-cta:hover {
  transform: translateY(-1px);
  box-shadow: 0 8px 20px rgba(15, 23, 42, 0.25);
}

@media (max-width: 640px) {
  .landing-nav {
    width: calc(100% - 24px);
    padding: 8px 8px 8px 16px;
  }
  .landing-nav-links { display: none; }
  .landing-nav-name { font-size: 13px; }
}

/* -------- HERO SECTION -------- */
.landing-hero {
  position: relative;
  z-index: 2;
  padding: 160px 24px 100px;
  text-align: center;
  max-width: 1080px;
  margin: 0 auto;
}

.landing-badge {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  padding: 6px 14px;
  border-radius: 999px;
  background: rgba(255, 255, 255, 0.9);
  border: 1px solid rgba(139, 92, 246, 0.2);
  font-size: 12px;
  font-weight: 500;
  color: #475569;
  margin-bottom: 28px;
  box-shadow: 0 4px 16px -4px rgba(139, 92, 246, 0.15);
  animation: heroFadeUp 0.7s cubic-bezier(.22, 1, .36, 1) 0.1s both;
}
.landing-badge-dot {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: #10b981;
  box-shadow: 0 0 8px #10b981;
  animation: pulseDot 2s ease-in-out infinite;
}
@keyframes pulseDot {
  0%, 100% { opacity: 1; transform: scale(1); }
  50% { opacity: 0.55; transform: scale(1.3); }
}

.landing-title {
  font-size: clamp(2.5rem, 8vw, 5.5rem);
  font-weight: 800;
  line-height: 1.02;
  letter-spacing: -0.045em;
  margin: 0 0 24px;
  color: #0f172a;
  animation: heroFadeUp 0.8s cubic-bezier(.22, 1, .36, 1) 0.2s both;
}
.landing-title-gradient {
  background: linear-gradient(120deg, #8b5cf6 0%, #ec4899 40%, #3b82f6 70%, #10b981 100%);
  background-size: 300% 300%;
  -webkit-background-clip: text;
  background-clip: text;
  color: transparent;
  animation: gradientFlow 8s ease infinite;
  display: inline-block;
}
@keyframes gradientFlow {
  0%, 100% { background-position: 0% 50%; }
  50% { background-position: 100% 50%; }
}

.landing-subtitle {
  font-size: clamp(0.95rem, 2vw, 1.2rem);
  color: #64748b;
  max-width: 620px;
  margin: 0 auto 40px;
  line-height: 1.6;
  animation: heroFadeUp 0.8s cubic-bezier(.22, 1, .36, 1) 0.3s both;
}

.landing-cta-row {
  display: flex;
  gap: 12px;
  justify-content: center;
  flex-wrap: wrap;
  animation: heroFadeUp 0.8s cubic-bezier(.22, 1, .36, 1) 0.4s both;
}

.landing-cta-primary {
  display: inline-flex;
  align-items: center;
  gap: 10px;
  padding: 14px 28px;
  border-radius: 999px;
  background: linear-gradient(135deg, #8b5cf6 0%, #6366f1 100%);
  color: #fff;
  text-decoration: none;
  font-size: 15px;
  font-weight: 600;
  letter-spacing: -0.01em;
  transition: all .3s cubic-bezier(.22, 1, .36, 1);
  box-shadow:
    0 12px 32px -8px rgba(139, 92, 246, 0.5),
    inset 0 1px 0 rgba(255, 255, 255, 0.25);
  position: relative;
  overflow: hidden;
}
.landing-cta-primary::before {
  content: '';
  position: absolute;
  inset: 0;
  background: linear-gradient(135deg, transparent 40%, rgba(255, 255, 255, 0.3) 50%, transparent 60%);
  transform: translateX(-100%);
  transition: transform .6s;
}
.landing-cta-primary:hover {
  transform: translateY(-2px);
  box-shadow:
    0 20px 48px -8px rgba(139, 92, 246, 0.6),
    inset 0 1px 0 rgba(255, 255, 255, 0.35);
}
.landing-cta-primary:hover::before {
  transform: translateX(100%);
}
.landing-cta-primary svg {
  transition: transform .3s;
}
.landing-cta-primary:hover svg {
  transform: translateX(4px);
}

.landing-cta-secondary {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  padding: 14px 28px;
  border-radius: 999px;
  background: rgba(255, 255, 255, 0.9);
  border: 1px solid rgba(15, 23, 42, 0.1);
  color: #0f172a;
  text-decoration: none;
  font-size: 15px;
  font-weight: 600;
  transition: all .25s;
  box-shadow: 0 4px 16px -4px rgba(15, 23, 42, 0.08);
}
.landing-cta-secondary:hover {
  transform: translateY(-2px);
  border-color: rgba(139, 92, 246, 0.4);
  box-shadow: 0 12px 32px -8px rgba(139, 92, 246, 0.25);
}

@keyframes heroFadeUp {
  from { opacity: 0; transform: translateY(30px); }
  to { opacity: 1; transform: translateY(0); }
}

/* -------- FLOATING PREVIEW (3D) -------- */
.landing-preview-wrap {
  position: relative;
  max-width: 1000px;
  margin: 80px auto 0;
  padding: 0 24px;
  perspective: 2000px;
  animation: heroFadeUp 1s cubic-bezier(.22, 1, .36, 1) 0.6s both;
}

.landing-preview {
  position: relative;
  border-radius: 20px;
  background: rgba(255, 255, 255, 0.85);
  backdrop-filter: blur(20px);
  border: 1px solid rgba(15, 23, 42, 0.08);
  overflow: hidden;
  box-shadow:
    0 40px 100px -20px rgba(139, 92, 246, 0.35),
    0 20px 60px -20px rgba(15, 23, 42, 0.25),
    inset 0 1px 0 rgba(255, 255, 255, 0.9);
  transform: rotateX(6deg) rotateY(-2deg);
  transition: transform 0.8s cubic-bezier(.22, 1, .36, 1);
}
.landing-preview:hover {
  transform: rotateX(0deg) rotateY(0deg) translateY(-4px);
}

.landing-preview-top {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 12px 16px;
  background: rgba(248, 250, 252, 0.9);
  border-bottom: 1px solid rgba(15, 23, 42, 0.06);
}
.landing-dot {
  width: 10px;
  height: 10px;
  border-radius: 50%;
}
.landing-preview-url {
  flex: 1;
  text-align: center;
  font-size: 11px;
  color: #94a3b8;
  background: rgba(15, 23, 42, 0.04);
  padding: 4px 12px;
  border-radius: 6px;
  max-width: 280px;
  margin: 0 auto;
  font-family: ui-monospace, monospace;
}

.landing-preview-body {
  padding: 32px;
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(140px, 1fr));
  gap: 16px;
}

.landing-preview-kpi {
  background: linear-gradient(135deg, rgba(139, 92, 246, 0.06), rgba(236, 72, 153, 0.03));
  border: 1px solid rgba(15, 23, 42, 0.05);
  border-radius: 14px;
  padding: 16px;
  text-align: left;
  transition: all .3s;
}
.landing-preview-kpi:hover {
  transform: translateY(-2px);
  border-color: rgba(139, 92, 246, 0.25);
}
.landing-preview-kpi-label {
  font-size: 10px;
  text-transform: uppercase;
  letter-spacing: 0.1em;
  color: #94a3b8;
  font-weight: 700;
  margin-bottom: 6px;
}
.landing-preview-kpi-value {
  font-size: 26px;
  font-weight: 800;
  letter-spacing: -0.02em;
  line-height: 1;
}

@media (max-width: 640px) {
  .landing-preview-body { padding: 20px; gap: 10px; }
  .landing-preview-kpi-value { font-size: 20px; }
  .landing-preview-kpi { padding: 12px; }
}

/* -------- FLOATING BADGES -------- */
.landing-float {
  position: absolute;
  padding: 10px 16px;
  border-radius: 14px;
  background: rgba(255, 255, 255, 0.95);
  border: 1px solid rgba(15, 23, 42, 0.08);
  font-size: 12px;
  font-weight: 600;
  color: #0f172a;
  box-shadow: 0 12px 32px -8px rgba(15, 23, 42, 0.15);
  display: flex;
  align-items: center;
  gap: 8px;
  backdrop-filter: blur(12px);
  z-index: 10;
}
.landing-float-1 {
  top: -20px;
  left: 0;
  animation: floatY 5s ease-in-out infinite;
}
.landing-float-2 {
  top: 40%;
  right: -10px;
  animation: floatY 6s ease-in-out infinite 1s;
}
.landing-float-3 {
  bottom: -20px;
  left: 30%;
  animation: floatY 7s ease-in-out infinite 2s;
}
@keyframes floatY {
  0%, 100% { transform: translateY(0); }
  50% { transform: translateY(-14px); }
}

@media (max-width: 900px) {
  .landing-float { display: none; }
}

/* -------- TRUSTED BY -------- */
.landing-trusted {
  position: relative;
  z-index: 2;
  padding: 40px 24px 60px;
  text-align: center;
  max-width: 1080px;
  margin: 0 auto;
}
.landing-trusted-label {
  font-size: 11px;
  text-transform: uppercase;
  letter-spacing: 0.2em;
  color: #94a3b8;
  font-weight: 700;
  margin-bottom: 24px;
}
.landing-trusted-marks {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 32px;
  flex-wrap: wrap;
  opacity: 0.7;
}
.landing-trusted-mark {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 15px;
  font-weight: 700;
  color: #94a3b8;
  letter-spacing: -0.02em;
  transition: color .25s;
}
.landing-trusted-mark:hover { color: #0f172a; }
.landing-trusted-mark-icon {
  font-size: 20px;
}

/* -------- BENTO FEATURES -------- */
.landing-section {
  position: relative;
  z-index: 2;
  padding: 80px 24px;
  max-width: 1200px;
  margin: 0 auto;
}

.landing-section-head {
  text-align: center;
  margin-bottom: 56px;
}
.landing-section-eyebrow {
  display: inline-block;
  font-size: 11px;
  text-transform: uppercase;
  letter-spacing: 0.15em;
  color: #8b5cf6;
  font-weight: 800;
  margin-bottom: 12px;
}
.landing-section-title {
  font-size: clamp(1.8rem, 4vw, 3rem);
  font-weight: 800;
  letter-spacing: -0.035em;
  line-height: 1.1;
  margin: 0 0 16px;
  color: #0f172a;
}
.landing-section-desc {
  font-size: 16px;
  color: #64748b;
  max-width: 560px;
  margin: 0 auto;
  line-height: 1.6;
}

/* -------- BENTO GRID -------- */
.bento-grid {
  display: grid;
  grid-template-columns: repeat(6, 1fr);
  gap: 16px;
}
.bento-card {
  position: relative;
  border-radius: 24px;
  background: rgba(255, 255, 255, 0.72);
  backdrop-filter: blur(20px);
  border: 1px solid rgba(15, 23, 42, 0.06);
  padding: 28px;
  overflow: hidden;
  transition: all .4s cubic-bezier(.22, 1, .36, 1);
  box-shadow: 0 4px 24px -8px rgba(15, 23, 42, 0.06);
}
.bento-card:hover {
  transform: translateY(-4px);
  border-color: rgba(139, 92, 246, 0.3);
  box-shadow: 0 24px 60px -20px rgba(139, 92, 246, 0.3);
}
.bento-card::before {
  content: '';
  position: absolute;
  inset: 0;
  background: radial-gradient(circle at var(--mx, 50%) var(--my, 50%), rgba(139, 92, 246, 0.08), transparent 60%);
  opacity: 0;
  transition: opacity .4s;
  pointer-events: none;
}
.bento-card:hover::before { opacity: 1; }

.bento-1 { grid-column: span 3; grid-row: span 2; }
.bento-2 { grid-column: span 3; }
.bento-3 { grid-column: span 3; }
.bento-4 { grid-column: span 2; }
.bento-5 { grid-column: span 2; }
.bento-6 { grid-column: span 2; }

@media (max-width: 900px) {
  .bento-grid { grid-template-columns: repeat(2, 1fr); }
  .bento-1, .bento-2, .bento-3, .bento-4, .bento-5, .bento-6 { grid-column: span 2; grid-row: auto; }
}

.bento-icon {
  width: 48px;
  height: 48px;
  border-radius: 14px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 24px;
  margin-bottom: 20px;
  background: linear-gradient(135deg, rgba(139, 92, 246, 0.12), rgba(236, 72, 153, 0.08));
  box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.6);
}
.bento-title {
  font-size: 18px;
  font-weight: 700;
  letter-spacing: -0.02em;
  color: #0f172a;
  margin: 0 0 8px;
}
.bento-desc {
  font-size: 14px;
  color: #64748b;
  line-height: 1.6;
  margin: 0;
}

.bento-visual {
  margin-top: 24px;
  border-radius: 16px;
  background: linear-gradient(135deg, rgba(139, 92, 246, 0.06), rgba(236, 72, 153, 0.03));
  border: 1px solid rgba(15, 23, 42, 0.04);
  padding: 20px;
  overflow: hidden;
}

/* Fake live chart */
.bento-chart {
  display: flex;
  align-items: flex-end;
  gap: 6px;
  height: 100px;
}
.bento-chart-bar {
  flex: 1;
  border-radius: 4px 4px 0 0;
  background: linear-gradient(180deg, #8b5cf6, #ec4899);
  animation: barPulse 3s ease-in-out infinite;
  transform-origin: bottom;
}
@keyframes barPulse {
  0%, 100% { transform: scaleY(1); opacity: 1; }
  50% { transform: scaleY(0.85); opacity: 0.85; }
}

/* Fake sender row */
.bento-sender {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 10px 12px;
  border-radius: 10px;
  background: rgba(255, 255, 255, 0.6);
  margin-bottom: 8px;
}
.bento-sender:last-child { margin-bottom: 0; }
.bento-sender-avatar {
  width: 28px;
  height: 28px;
  border-radius: 8px;
  background: linear-gradient(135deg, #8b5cf6, #ec4899);
  flex-shrink: 0;
}
.bento-sender-info {
  flex: 1;
  min-width: 0;
}
.bento-sender-name {
  font-size: 12px;
  font-weight: 600;
  color: #0f172a;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.bento-sender-status {
  font-size: 10px;
  color: #10b981;
  font-weight: 700;
}
.bento-sender-badge {
  font-size: 10px;
  padding: 3px 8px;
  border-radius: 999px;
  background: rgba(16, 185, 129, 0.12);
  color: #047857;
  font-weight: 700;
}

/* -------- STATS -------- */
.landing-stats {
  position: relative;
  z-index: 2;
  padding: 60px 24px;
  max-width: 1080px;
  margin: 0 auto;
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
  gap: 24px;
  text-align: center;
}
.landing-stat {
  padding: 24px;
}
.landing-stat-value {
  font-size: clamp(2rem, 5vw, 3.5rem);
  font-weight: 800;
  letter-spacing: -0.04em;
  background: linear-gradient(135deg, #8b5cf6 0%, #ec4899 100%);
  -webkit-background-clip: text;
  background-clip: text;
  color: transparent;
  line-height: 1;
  margin-bottom: 8px;
}
.landing-stat-label {
  font-size: 12px;
  color: #64748b;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.1em;
}

/* -------- FINAL CTA -------- */
.landing-final-cta {
  position: relative;
  z-index: 2;
  margin: 80px 24px;
  padding: 80px 24px;
  border-radius: 40px;
  background: linear-gradient(135deg, #0f172a 0%, #1e293b 100%);
  text-align: center;
  overflow: hidden;
  max-width: 1200px;
  margin-left: auto;
  margin-right: auto;
  box-shadow: 0 40px 100px -30px rgba(15, 23, 42, 0.4);
}
.landing-final-cta::before {
  content: '';
  position: absolute;
  inset: -50%;
  background:
    radial-gradient(circle at 20% 30%, rgba(139, 92, 246, 0.35), transparent 40%),
    radial-gradient(circle at 80% 70%, rgba(236, 72, 153, 0.25), transparent 40%);
  animation: ctaGlow 15s ease-in-out infinite;
}
@keyframes ctaGlow {
  0%, 100% { transform: rotate(0deg); }
  50% { transform: rotate(180deg); }
}
.landing-final-cta-inner {
  position: relative;
  z-index: 1;
}
.landing-final-cta-title {
  font-size: clamp(1.8rem, 4vw, 3rem);
  font-weight: 800;
  letter-spacing: -0.04em;
  color: #fff;
  margin: 0 0 16px;
  line-height: 1.1;
}
.landing-final-cta-desc {
  font-size: 16px;
  color: rgba(255, 255, 255, 0.7);
  margin: 0 0 32px;
  max-width: 500px;
  margin-left: auto;
  margin-right: auto;
  line-height: 1.6;
}
.landing-final-cta-btn {
  display: inline-flex;
  align-items: center;
  gap: 10px;
  padding: 16px 32px;
  border-radius: 999px;
  background: #fff;
  color: #0f172a;
  text-decoration: none;
  font-size: 15px;
  font-weight: 700;
  transition: all .3s;
  box-shadow: 0 12px 32px -8px rgba(255, 255, 255, 0.3);
}
.landing-final-cta-btn:hover {
  transform: translateY(-2px);
  box-shadow: 0 20px 48px -8px rgba(255, 255, 255, 0.4);
}

/* -------- FOOTER -------- */
.landing-footer {
  position: relative;
  z-index: 2;
  padding: 40px 24px 60px;
  text-align: center;
  border-top: 1px solid rgba(15, 23, 42, 0.06);
  max-width: 1200px;
  margin: 40px auto 0;
}
.landing-footer-brand {
  display: inline-flex;
  align-items: center;
  gap: 10px;
  margin-bottom: 16px;
}
.landing-footer-text {
  font-size: 12px;
  color: #94a3b8;
}

/* -------- SCROLL REVEAL -------- */
.reveal {
  opacity: 0;
  transform: translateY(40px);
  transition: opacity 0.9s cubic-bezier(.22, 1, .36, 1), transform 0.9s cubic-bezier(.22, 1, .36, 1);
}
.reveal.visible {
  opacity: 1;
  transform: translateY(0);
}
CSSEOF
sed -i 's/\r$//' app/globals.css
echo "   ✅ Landing CSS added"

# ==========================================
# 2. REWRITE LANDING PAGE
# ==========================================
echo ""
echo "🎨 [2/3] Rewriting landing page..."

cat > app/page.tsx <<'EOF'
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
EOF
sed -i 's/\r$//' app/page.tsx
echo "   ✅ Landing page rewritten"

# ==========================================
# 3. Git push
# ==========================================
echo ""
echo "🌿 [3/3] Git push..."
git config --local user.email "63999328+dipenzala@users.noreply.github.com"
git config --local user.name "Dipen Zala"

git add -A
git diff --cached --quiet || git commit -m "Feat: premium 3D landing page with animations + bento features"

git push -u origin main 2>&1 | tail -5

echo ""
echo "==============================================="
echo " ✅ PREMIUM LANDING DEPLOYED"
echo "==============================================="
echo ""
echo "🎨 Features:"
echo "   ✓ Floating mesh gradient background"
echo "   ✓ Animated orbs with parallax"
echo "   ✓ 3D rotating preview card"
echo "   ✓ Floating notification badges"
echo "   ✓ Live counter animations"
echo "   ✓ Bento grid features (6 cards)"
echo "   ✓ Fake live chart + sender list"
echo "   ✓ Final CTA with rotating glow"
echo "   ✓ Scroll reveal animations"
echo "   ✓ Mouse-follow glow on cards"
echo "   ✓ Nav with shine animation"
echo ""
echo "⏱️  2-3 min me Vercel deploy hoga"
echo "URL: https://emailcampaign-ten.vercel.app/"
echo "==============================================="