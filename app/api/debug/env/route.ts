import { NextResponse } from 'next/server';

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function GET() {
  const info = (name: string) => {
    const v = process.env[name] || '';
    return {
      present: !!v, length: v.length,
      valid: name === 'TOKEN_ENCRYPTION_KEY' ? /^[0-9a-fA-F]{64}$/.test(v)
        : name === 'REDIS_URL' ? /^rediss?:\/\/[^\s]+$/.test(v)
        : name === 'DATABASE_URL' ? /^postgres(ql)?:\/\//.test(v)
        : name === 'GOOGLE_CLIENT_ID' ? /\.apps\.googleusercontent\.com$/.test(v)
        : name === 'GOOGLE_REDIRECT_URI' ? /^https?:\/\//.test(v) : undefined,
      preview: ['APP_URL','GOOGLE_REDIRECT_URI'].includes(name) ? v : undefined,
    };
  };
  return NextResponse.json({
    DATABASE_URL: info('DATABASE_URL'), REDIS_URL: info('REDIS_URL'),
    GOOGLE_CLIENT_ID: info('GOOGLE_CLIENT_ID'), GOOGLE_CLIENT_SECRET: info('GOOGLE_CLIENT_SECRET'),
    GOOGLE_REDIRECT_URI: info('GOOGLE_REDIRECT_URI'), TOKEN_ENCRYPTION_KEY: info('TOKEN_ENCRYPTION_KEY'),
    SESSION_SECRET: info('SESSION_SECRET'), APP_URL: info('APP_URL'),
    NODE_ENV: process.env.NODE_ENV,
  });
}
