'use client';
import { useState } from 'react';

const PHONE = '8128931029';
const NAME = 'DIPEN ZALA';

export default function HelpContact() {
  const [open, setOpen] = useState(false);

  return (
    <>
      <button
        onClick={() => setOpen(!open)}
        className="fixed bottom-6 right-6 z-50 w-14 h-14 rounded-full flex items-center justify-center transition-all duration-500 hover:scale-110 active:scale-95 group"
        style={{
          background: 'linear-gradient(135deg, #0071e3 0%, #0077ed 100%)',
          boxShadow: '0 10px 30px -6px rgba(0, 113, 227, 0.5), 0 0 0 1px rgba(255, 255, 255, 0.2) inset',
        }}
        aria-label="Help & Contact"
      >
        <div className="absolute inset-0 rounded-full bg-gradient-to-br from-white/30 to-transparent opacity-0 group-hover:opacity-100 transition-opacity" />
        {open ? (
          <svg className="relative w-6 h-6 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5}>
            <path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" />
          </svg>
        ) : (
          <svg className="relative w-6 h-6 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
            <path strokeLinecap="round" strokeLinejoin="round" d="M8.228 9c.549-1.165 2.03-2 3.772-2 2.21 0 4 1.343 4 3 0 1.4-1.278 2.575-3.006 2.907-.542.104-.994.54-.994 1.093m0 3h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
        )}
      </button>

      {open && (
        <div
          className="fixed bottom-24 right-6 z-50 w-[340px] rounded-2xl overflow-hidden"
          style={{
            background: 'rgba(255, 255, 255, 0.95)',
            backdropFilter: 'blur(30px) saturate(180%)',
            border: '1px solid rgba(0, 0, 0, 0.08)',
            boxShadow: '0 40px 80px -20px rgba(0, 0, 0, 0.2), 0 0 0 1px rgba(0, 113, 227, 0.08)',
            animation: 'fadeUp 0.4s cubic-bezier(0.16, 1, 0.3, 1) both',
          }}
        >
          <div className="relative px-5 py-4 overflow-hidden">
            <div className="absolute inset-0 bg-gradient-to-br from-[#0071e3]/10 to-[#5e5ce6]/5" />
            <div className="relative flex items-center gap-3">
              <div className="w-11 h-11 rounded-full bg-gradient-to-br from-[#0071e3] to-[#0077ed] flex items-center justify-center text-white text-sm font-bold shadow-md">
                {NAME.split(' ').map(n => n[0]).join('')}
              </div>
              <div>
                <div className="text-[#1d1d1f] font-semibold text-sm">{NAME}</div>
                <div className="text-[#6e6e73] text-xs flex items-center gap-1.5">
                  <span className="w-1.5 h-1.5 rounded-full bg-[#30d158] animate-pulse" />
                  Online
                </div>
              </div>
            </div>
          </div>

          <div className="p-5 space-y-2.5">
            <p className="text-xs text-[#6e6e73] leading-relaxed pb-2">
              Koi bhi help, query, ya issue ke liye direct contact karein:
            </p>

            <a
              href={`tel:+91${PHONE}`}
              className="flex items-center gap-3 p-3 rounded-xl bg-black/[0.02] hover:bg-black/[0.05] border border-black/[0.06] hover:border-[#30d158]/30 transition-all duration-300 group"
            >
              <div className="w-9 h-9 rounded-lg bg-[#30d158]/10 flex items-center justify-center text-[#30d158] flex-shrink-0 group-hover:scale-110 transition-transform">
                <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                  <path strokeLinecap="round" strokeLinejoin="round" d="M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.949V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z" />
                </svg>
              </div>
              <div className="min-w-0 flex-1">
                <div className="text-[10px] uppercase tracking-wider text-[#86868b]">Call</div>
                <div className="text-sm font-semibold text-[#1d1d1f]">+91 {PHONE}</div>
              </div>
              <svg className="w-4 h-4 text-[#86868b] group-hover:text-[#30d158] group-hover:translate-x-0.5 transition-all flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M9 5l7 7-7 7" />
              </svg>
            </a>

            <a
              href={`https://wa.me/91${PHONE}?text=${encodeURIComponent('Hi, mujhe EmailCampaign ke baare me help chahiye.')}`}
              target="_blank"
              rel="noopener noreferrer"
              className="flex items-center gap-3 p-3 rounded-xl bg-black/[0.02] hover:bg-black/[0.05] border border-black/[0.06] hover:border-[#25D366]/30 transition-all duration-300 group"
            >
              <div className="w-9 h-9 rounded-lg bg-[#25D366]/10 flex items-center justify-center text-[#25D366] flex-shrink-0 group-hover:scale-110 transition-transform">
                <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 24 24">
                  <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 00-3.48-8.413z"/>
                </svg>
              </div>
              <div className="min-w-0 flex-1">
                <div className="text-[10px] uppercase tracking-wider text-[#86868b]">WhatsApp</div>
                <div className="text-sm font-semibold text-[#1d1d1f]">Chat now</div>
              </div>
              <svg className="w-4 h-4 text-[#86868b] group-hover:text-[#25D366] group-hover:translate-x-0.5 transition-all flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M9 5l7 7-7 7" />
              </svg>
            </a>
          </div>
        </div>
      )}
    </>
  );
}
