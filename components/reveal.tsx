'use client';
import { useEffect, useRef, ReactNode } from 'react';

export function Reveal({
  children, type = 'up', delay = 0, className = '', as: Tag = 'div',
}: {
  children: ReactNode;
  type?: 'up' | 'fade' | 'left' | 'right' | 'scale' | 'blur';
  delay?: 0 | 1 | 2 | 3 | 4 | 5 | 6;
  className?: string;
  as?: any;
}) {
  const ref = useRef<HTMLElement>(null);
  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    const io = new IntersectionObserver(
      (entries) => {
        entries.forEach((e) => {
          if (e.isIntersecting) {
            e.target.classList.add('is-visible');
            io.unobserve(e.target);
          }
        });
      },
      { threshold: 0.1, rootMargin: '0px 0px -60px 0px' }
    );
    io.observe(el);
    return () => io.disconnect();
  }, []);
  return (
    <Tag ref={ref} data-reveal={type} data-reveal-delay={delay || undefined} className={className}>
      {children}
    </Tag>
  );
}
