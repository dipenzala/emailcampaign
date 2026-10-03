import { NextResponse } from 'next/server';
import type { NextRequest } from 'next/server';

const AUTH_COOKIE = 'ec_auth';

export function middleware(req: NextRequest) {
  const { pathname } = req.nextUrl;

  // Allow public routes
  if (
    pathname === '/login' ||
    pathname === '/' ||
    pathname.startsWith('/api/auth/') ||
    pathname.startsWith('/_next/') ||
    pathname.startsWith('/favicon')
  ) {
    return NextResponse.next();
  }

  // Protected page routes
  const pagePrefixes = ['/dashboard', '/senders', '/history', '/campaigns', '/anti-spam', '/settings', '/help', '/worker'];
  const isPageRoute = pagePrefixes.some(p => pathname.startsWith(p));

  if (isPageRoute) {
    const token = req.cookies.get(AUTH_COOKIE)?.value;
    if (!token) {
      const url = req.nextUrl.clone();
      url.pathname = '/login';
      url.searchParams.set('next', pathname);
      return NextResponse.redirect(url);
    }
    return NextResponse.next();
  }

  // API routes handle their own auth — do NOT redirect
  return NextResponse.next();
}

export const config = {
  matcher: [
    '/dashboard/:path*',
    '/senders/:path*',
    '/history/:path*',
    '/campaigns/:path*',
    '/anti-spam/:path*',
    '/settings/:path*',
    '/help/:path*',
    '/worker/:path*',
  ],
};
