import { NextResponse } from 'next/server';
import type { NextRequest } from 'next/server';

const AUTH_COOKIE = 'ec_auth';

export function middleware(req: NextRequest) {
  const { pathname } = req.nextUrl;

  // Public routes
  if (pathname === '/login' || pathname === '/') {
    return NextResponse.next();
  }

  // Protected routes
  const protectedPrefixes = ['/dashboard', '/senders', '/history', '/campaigns', '/anti-spam', '/worker'];
  const isProtected = protectedPrefixes.some(p => pathname.startsWith(p));

  if (!isProtected) return NextResponse.next();

  const token = req.cookies.get(AUTH_COOKIE)?.value;
  if (!token) {
    const url = req.nextUrl.clone();
    url.pathname = '/login';
    url.searchParams.set('next', pathname);
    return NextResponse.redirect(url);
  }

  return NextResponse.next();
}

export const config = {
  matcher: [
    '/dashboard/:path*',
    '/senders/:path*',
    '/history/:path*',
    '/campaigns/:path*',
    '/anti-spam/:path*',
    '/worker/:path*',
    '/login',
  ],
};
